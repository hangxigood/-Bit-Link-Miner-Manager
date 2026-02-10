use rust_lib_frontend::client::{send_command, DEFAULT_PORT, DEFAULT_TIMEOUT_MS};
use std::env;

#[tokio::main]
async fn main() {
    let args: Vec<String> = env::args().collect();
    let ip = if args.len() > 1 {
        args[1].clone()
    } else {
        "192.168.56.32".to_string()
    };
    
    let command_name = "restart";

    println!("Attempting to REBOOT miner at {} using command '{}'...", ip, command_name);

    match send_command(&ip, DEFAULT_PORT, command_name, DEFAULT_TIMEOUT_MS).await {
        Ok(response) => {
            println!("✅ Network Request Successful");
            let trimmed = response.trim();
            
            // Typical success: {"STATUS":[{"STATUS":"S", "Msg":"Command OK"}]}
            // Typical error: {"STATUS":[{"STATUS":"E", "Msg":"Invalid command"}]}
            
            if trimmed.contains("\"STATUS\": \"E\"") || trimmed.contains("\"Msg\": \"Invalid command\"") {
                println!("❌ FAILED: Miner rejected the command as INVALID.");
                println!("Possible reasons:");
                println!("1. Privileged commands are disabled (check standard API access config: --api-allow W:0/0).");
                println!("2. This model requires a different command (e.g., 'reboot', 'system-restart').");
                println!("3. Authentication is required.");
                println!("--------------------------------");
                println!("Raw Response: {}", trimmed);
            } else if trimmed.contains("\"STATUS\": \"S\"") { // Status Success
                 println!("✅ SUCCESS: Reboot command accepted!");
                 println!("--------------------------------");
                 println!("Raw Response: {}", trimmed);
            } else {
                 println!("⚠️ UNKNOWN: Command sent, but response is unclear.");
                 println!("--------------------------------");
                 println!("Raw Response: {}", trimmed);
            }
        }
        Err(e) => {
            println!("❌ Network Request Failed: {}", e);
        }
    }
}
