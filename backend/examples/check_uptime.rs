use rust_lib_frontend::client::{get_summary, DEFAULT_PORT, DEFAULT_TIMEOUT_MS};
use std::env;

#[tokio::main]
async fn main() {
    let args: Vec<String> = env::args().collect();
    let ip = if args.len() > 1 {
        args[1].clone()
    } else {
        println!("Usage: cargo run --example check_uptime <IP>");
        println!("Defaulting to 192.168.56.32");
        "192.168.56.32".to_string()
    };

    println!("Checking status for {}...", ip);

    match get_summary(&ip, DEFAULT_PORT, DEFAULT_TIMEOUT_MS).await {
        Ok(stats) => {
            println!("✅ Miner is ONLINE");
            println!("--------------------------------");
            println!("Uptime:      {} seconds ({} minutes)", stats.uptime, stats.uptime / 60);
            println!("Hashrate:    {:.2} TH/s (RT)", stats.hashrate_rt);
            println!("Temps (Inlet Max): {:?}", stats.temp_inlet_max);
            println!("Fans:        {:?}", stats.fan_speeds);
            println!("--------------------------------");

            if stats.uptime < 300 {
                println!("🚀 STATUS: REBOOT CONFIRMED (Uptime is < 5 minutes)");
            } else {
                println!("ℹ️ STATUS: Miner has been running for a while.");
            }
        }
        Err(e) => {
            println!("❌ Miner is OFFLINE or UNREACHABLE");
            println!("Error: {}", e);
            println!("(This is expected if the miner is currently rebooting)");
        }
    }
}
