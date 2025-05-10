mod commands;

#[allow(unused_imports)]
use log::{info, warn, error, debug};

use chrono::Local;
use std::process;
use std::env;
use std::io::Write;

use poise::serenity_prelude as serenity;
use serenity::GatewayIntents;

use prometheus::{Counter, TextEncoder, Encoder, Registry};
use warp::Filter;

use crate::commands::general::*;

const S_DISCORD_TOKEN: &str = "DISCORD_TOKEN";
const S_DISCORD_PREFIX: &str = "!";
const S_CRATE_NAME: &str = env!("CARGO_PKG_NAME");

// User data, which is stored and accessible in all command invocations
struct Data {
    command_counter: Counter,
}
type Error = Box<dyn std::error::Error + Send + Sync>;
type Context<'a> = poise::Context<'a, Data, Error>;

// Prometheus metrics
lazy_static::lazy_static! {
    static ref REGISTRY: Registry = Registry::new();
    static ref COMMAND_COUNTER: Counter = Counter::new(
        "discord_commands_total",
        "Total number of Discord commands executed"
    ).unwrap();
}

// Metrics endpoint
async fn metrics_handler() -> Result<impl warp::Reply, warp::Rejection> {
    let encoder = TextEncoder::new();
    let metric_families = REGISTRY.gather();
    let mut buffer = vec![];
    encoder.encode(&metric_families, &mut buffer).unwrap();
    Ok(warp::reply::with_header(buffer, "Content-Type", "text/plain; version=0.0.4"))
}

// Custom error handler
async fn on_error(error: poise::FrameworkError<'_, Data, Error>) {
    match error {
        poise::FrameworkError::Setup {
            error, ..
        } => panic!("Failed to start bot: {:?}", error),
        poise::FrameworkError::Command {
            error, ctx, ..
        } => {
            error!("Error in command `{}`: {:?}", ctx.command().name, error);
        }
        error => {
            if let Err(e) = poise::builtins::on_error(error).await {
                error!("Error while handling error: {}", e)
            }
        }
    }
}

#[tokio::main]
async fn main() {
    let token: String;

    // Configure Logger
    env_logger::Builder::from_default_env()
        .filter_module(S_CRATE_NAME, log::LevelFilter::Info)
        .format(|buf, record| {
            writeln!(
                buf,
                "{} [{}] - {}",
                Local::now().format("%Y-%m-%d %H:%M:%S"),
                record.level(),
                record.args()
            )
        })
        .init();

    // Get Discord Token
    match env::var(S_DISCORD_TOKEN) {
        Ok(val) => token = val,
        Err(err) => {
            error!("Discord Token needed : {:?}", err);
            process::exit(1);
        }
    }
    info!("Using Discord token: {} (length: {})", token, token.len());

    // Register Prometheus metrics
    REGISTRY.register(Box::new(COMMAND_COUNTER.clone())).unwrap();

    // Start metrics server
    let metrics_route = warp::path("metrics").and_then(metrics_handler);
    tokio::spawn(warp::serve(metrics_route).run(([0, 0, 0, 0], 8091)));

    // Set gateway intents, which decides what events the bot will be notified about
    let intents = GatewayIntents::non_privileged() | GatewayIntents::MESSAGE_CONTENT;
    info!("Configuring client with intents: {:?}", intents);

    // Build Framework
    let options = poise::FrameworkOptions {
        commands: vec![
            help(),
            ping(),
        ],
        prefix_options: poise::PrefixFrameworkOptions {
            prefix: Some(S_DISCORD_PREFIX.into()),
            ..Default::default()
        },
        on_error: |error| Box::pin(on_error(error)),
        event_handler: |_ctx, event, _framework, _data| {
            Box::pin(async move {
                match event.snake_case_name() {
                    "ready" => info!("Bot connected"),
                    _ => (),
                }
                Ok(())
            })
        },
        command_check: Some(|ctx| {
            Box::pin(async move {
                // Increment command counter for each command executed
                ctx.data().command_counter.inc();
                Ok(true)
            })
        }),
        ..Default::default()
    };
    let framework = poise::Framework::builder()
        .setup(move |ctx, _ready, framework| {
            Box::pin(async move {
                poise::builtins::register_globally(ctx, &framework.options().commands).await?;
                Ok(Data {
                    command_counter: COMMAND_COUNTER.clone(),
                })
            })
        })
        .options(options)
        .build();

    // Create client and add Event Handler
    let client = serenity::ClientBuilder::new(&token, intents)
        .framework(framework)
        .await;

    // Start the client
    client.unwrap().start().await.unwrap();
}