use crate::{Context, Error};

/// This help
#[poise::command(prefix_command)]
pub async fn help(
    ctx: Context<'_>,
    #[description = "Help command"] command: Option<String>,
) -> Result<(), Error> {
    let config = poise::builtins::HelpConfiguration {
        include_description: true,
        ephemeral: true,
        ..Default::default()
    };
    poise::builtins::help(
        ctx,
        command.as_deref(),
        config,
    ).await?;
    Ok(())
}

/// Ping me
#[poise::command(prefix_command)]
pub async fn ping(
    ctx: Context<'_>,
    #[description = "Ping me !"] _command: Option<String>
) -> Result<(), Error> {
    ctx.say("Pong !").await?;
    Ok(())
}