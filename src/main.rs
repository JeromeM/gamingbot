mod commands;

use std::process;
use dotenv;

use poise::serenity_prelude as serenity;
use serenity::GatewayIntents;

use crate::commands::general::help;

const S_DISCORD_TOKEN: &str = "DISCORD_TOKEN";
const S_DISCORD_PREFIX: &str = "!";

// struct Handler;
struct Data {} // User data, which is stored and accessible in all command invocations
type Error = Box<dyn std::error::Error + Send + Sync>;
type Context<'a> = poise::Context<'a, Data, Error>;

// This is our custom error handler
// They are many errors that can occur, so we only handle the ones we want to customize
// and forward the rest to the default handler
async fn on_error(error: poise::FrameworkError<'_, Data, Error>) {

    match error {
        poise::FrameworkError::Setup {
            error, ..
        } => panic!("Failed to start bot: {:?}", error),
        poise::FrameworkError::Command {
            error, ctx, ..
        } => {
            println!("Error in command `{}`: {:?}", ctx.command().name, error,);
        }
        error => {
            if let Err(e) = poise::builtins::on_error(error).await {
                println!("Error while handling error: {}", e)
            }
        }
    }
}

#[tokio::main]
async fn main() {
    let token: String;

    // No .env file found
    if let Err(err) = dotenv::dotenv() {
        eprintln!("Error while loading .env file : {:?}", err);
        process::exit(1);
    }

    // Get Discord Token
    match dotenv::var(S_DISCORD_TOKEN) {
        Ok(val) => token = val,
        Err(err) => {
            eprintln!("Discord Token needed in .env file : {:?}", err);
            process::exit(1);
        }
    }

    // Set gateway intents, which decides what events the bot will be notified about
    let intents = GatewayIntents::GUILD_MESSAGES
        | GatewayIntents::DIRECT_MESSAGES
        | GatewayIntents::MESSAGE_CONTENT;

    // Build Framework
    let options = poise::FrameworkOptions {
        commands: vec![help()],
        prefix_options: poise::PrefixFrameworkOptions {
            prefix: Some(S_DISCORD_PREFIX.into()),
            ..Default::default()
        },
        on_error: |error| Box::pin(on_error(error)),
        event_handler: |_ctx, event, _framework, _data| {
            Box::pin(async move {
                println!(
                    "Got an event in event handler: {:?}",
                    event.snake_case_name()
                );
                Ok(())
            })
        },
        ..Default::default()
    };
    let framework = poise::Framework::builder()
        .setup(move |ctx, _ready, framework| {
            Box::pin(async move {
                poise::builtins::register_globally(ctx, &framework.options().commands).await?;
                Ok(Data {})
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