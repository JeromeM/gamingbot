use std::process;

use dotenv;
use serenity::async_trait;
use serenity::model::gateway::Ready;
use serenity::prelude::*;

struct Handler;

const S_DISCORD_TOKEN: &str = "DISCORD_TOKEN";

#[async_trait]
impl EventHandler for Handler {
    async fn ready(&self, _: Context, ready: Ready) {
        println!("{} connected.", ready.user.name);
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

    // Create client and add Event Handler
    let mut client = Client::builder(&token, intents)
        .event_handler(Handler)
        .await
        .expect("Error while creating new client");

    // Start the client
    if let Err(why) = client.start().await {
        println!("An error occured while running client : {why:?}");
    }

}