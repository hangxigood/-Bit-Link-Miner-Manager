use rust_lib_frontend::api::commands::execute_batch_command;
use rust_lib_frontend::api::models::MinerCommand;
use rust_lib_frontend::core::MinerCredentials;
use std::env;
use std::time::Duration;
use tokio::time::sleep;

#[tokio::main]
async fn main() {
    let args: Vec<String> = env::args().collect();
    // Default to the IP provided in the chat context if not specified
    let ip = if args.len() > 1 {
        args[1].clone()
    } else {
        "192.168.56.31".to_string()
    };

    let auth = MinerCredentials {
        username: "root".to_string(),
        password: "root".to_string(),
    };

    println!("1. sending BlinkLed ... {}", ip);
    let results = execute_batch_command(
        vec![ip.clone()],
        MinerCommand::BlinkLed,
        Some(auth.clone()),
    ).await;

    for result in results {
        if result.success {
            println!("✅ Successfully started blinking {}", result.ip);
        } else {
            println!("❌ Failed to start blink {}: {:?}", result.ip, result.error);
        }
    }

    println!("2. Waiting 10 seconds...");
    sleep(Duration::from_secs(10)).await;

    println!("3. sending StopBlink ... {}", ip);
    let results = execute_batch_command(
        vec![ip.clone()],
        MinerCommand::StopBlink,
        Some(auth),
    ).await;

    for result in results {
        if result.success {
            println!("✅ Successfully stopped blinking {}", result.ip);
        } else {
            println!("❌ Failed to stop blink {}: {:?}", result.ip, result.error);
        }
    }
}
