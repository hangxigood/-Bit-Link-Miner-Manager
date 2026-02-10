use crate::client::{send_command, DEFAULT_PORT, DEFAULT_TIMEOUT_MS};
use crate::api::models::{MinerCommand, CommandResult};

/// Execute a command on multiple miners
/// Returns results for each IP (success/failure)
pub async fn execute_batch_command(
    target_ips: Vec<String>,
    command: MinerCommand,
) -> Vec<CommandResult> {
    let mut results = Vec::new();
    
    // Execute commands concurrently
    let tasks: Vec<_> = target_ips
        .into_iter()
        .map(|ip| {
            let cmd = command.clone();
            tokio::spawn(async move {
                execute_single_command(ip, cmd).await
            })
        })
        .collect();
    
    // Wait for all tasks to complete
    for task in tasks {
        if let Ok(result) = task.await {
            results.push(result);
        }
    }
    
    results
}

/// Execute a command on a single miner
async fn execute_single_command(ip: String, command: MinerCommand) -> CommandResult {
    let command_str = match command {
        MinerCommand::Reboot => "restart",
        MinerCommand::BlinkLed => "locatedevice",
    };
    
    match send_command(&ip, DEFAULT_PORT, command_str, DEFAULT_TIMEOUT_MS).await {
        Ok(_response) => CommandResult {
            ip,
            success: true,
            error: None,
        },
        Err(e) => CommandResult {
            ip,
            success: false,
            error: Some(e.to_string()),
        },
    }
}

/// Test connection to a single miner
pub fn test_connection(ip: String) -> String {
    format!("Testing connection to {}", ip)
}
