use rust_lib_frontend::api::commands::execute_batch_command;
use rust_lib_frontend::api::models::MinerCommand;
use rust_lib_frontend::core::MinerCredentials;
use std::env;

#[tokio::main]
async fn main() {
    let args: Vec<String> = env::args().collect();
    // Default to the IP provided in the chat context if not specified
    let ip = if args.len() > 1 {
        args[1].clone()
    } else {
        "192.168.56.31".to_string()
    };

    println!("Testing BlinkLed command on {}...", ip);

    let auth = MinerCredentials {
        username: "root".to_string(),
        password: "root".to_string(),
    };

    let results = execute_batch_command(
        vec![ip.clone()],
        MinerCommand::BlinkLed,
        Some(auth),
    ).await;

    for result in results {
        if result.success {
            println!("✅ Successfully sent Blink command to {}", result.ip);
            println!("Check the miner LEDs now. They should be blinking.");
        } else {
            println!("❌ Failed to send Blink command to {}: {:?}", result.ip, result.error);
        }
    }
}
