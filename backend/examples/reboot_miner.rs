use rust_lib_frontend::api::commands::execute_batch_command;
use rust_lib_frontend::api::models::MinerCommand;
use rust_lib_frontend::client::{get_summary, DEFAULT_PORT, DEFAULT_TIMEOUT_MS};
use std::env;

#[tokio::main]
async fn main() {
    let args: Vec<String> = env::args().collect();
    let ip = if args.len() > 1 {
        args[1].clone()
    } else {
        println!("Usage: cargo run --example reboot_miner <IP>");
        println!("Defaulting to 192.168.56.32");
        "192.168.56.32".to_string()
    };

    // Step 1: Check uptime BEFORE reboot
    println!("📊 Checking miner status BEFORE reboot...");
    match get_summary(&ip, DEFAULT_PORT, DEFAULT_TIMEOUT_MS).await {
        Ok(stats) => {
            println!("   Uptime: {} seconds ({:.1} hours)", stats.uptime, stats.uptime as f64 / 3600.0);
            println!("   Hashrate: {:.2} TH/s", stats.hashrate_rt);
        }
        Err(e) => println!("   ⚠️  Could not get status: {}", e),
    }

    // Step 2: Send reboot command (now uses HTTP Digest Auth)
    println!("\n🔄 Sending Reboot command to {} (via HTTP Digest Auth)...", ip);
    let results = execute_batch_command(vec![ip.clone()], MinerCommand::Reboot, None).await;

    for result in &results {
        if result.success {
            println!("   ✅ Reboot command accepted!");
        } else {
            println!("   ❌ Reboot failed: {:?}", result.error);
            return;
        }
    }

    // Step 3: Wait and verify
    println!("\n⏳ Waiting 30 seconds for miner to reboot...");
    tokio::time::sleep(std::time::Duration::from_secs(30)).await;

    println!("📊 Checking miner status AFTER reboot...");
    for attempt in 1..=6 {
        match get_summary(&ip, DEFAULT_PORT, DEFAULT_TIMEOUT_MS).await {
            Ok(stats) => {
                println!("   Uptime: {} seconds ({:.1} minutes)", stats.uptime, stats.uptime as f64 / 60.0);
                if stats.uptime < 300 {
                    println!("   🚀 REBOOT CONFIRMED! Uptime is under 5 minutes.");
                } else {
                    println!("   ⚠️  Uptime is high — reboot may not have taken effect.");
                }
                return;
            }
            Err(_) => {
                if attempt < 6 {
                    println!("   Attempt {}/6: Miner still offline, retrying in 10s...", attempt);
                    tokio::time::sleep(std::time::Duration::from_secs(10)).await;
                } else {
                    println!("   ❌ Miner did not come back online after 6 attempts.");
                }
            }
        }
    }
}
