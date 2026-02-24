/// Test the Antminer HTTP API — reads pool config from a real miner.
/// Pass `--write` as a second argument to also configure test pools.
///
/// Usage:
///   cargo run --example test_set_pools -- <ip>
///   cargo run --example test_set_pools -- <ip> --write
use rust_lib_frontend::client::antminer_web::{AntminerWebClient, AntminerPool};
use std::env;

#[tokio::main]
async fn main() {
    let args: Vec<String> = env::args().collect();
    let ip = if args.len() > 1 {
        args[1].clone()
    } else {
        "192.168.56.32".to_string()
    };
    let do_write = args.iter().any(|a| a == "--write");

    let user = "root";
    let pass = "root";

    println!("=== Antminer HTTP API Test ===");
    println!("Target: {}  (write={}", ip, do_write);
    println!();

    // ---- LED status ----
    println!("📡 Reading LED status...");
    match AntminerWebClient::get_led(&ip, user, pass).await {
        Ok(state) => println!("  blink = {}", state),
        Err(e)    => println!("  ⚠️  {}", e),
    }

    // ---- Current pools ----
    println!();
    println!("📡 Reading current pool config...");
    match AntminerWebClient::get_pools(&ip, user, pass).await {
        Ok(pools) => {
            for (i, p) in pools.iter().enumerate() {
                println!("  Pool {}: {} | worker: {}", i + 1, p.url, p.user);
            }
        }
        Err(e) => println!("  ⚠️  {}", e),
    }

    if do_write {
        // ---- Write test pools ----
        println!();
        println!("✏️  Writing test pools (will trigger automatic reboot)...");
        let test_pools = vec![
            AntminerPool {
                url: "stratum+tcp://pool1.example.com:3333".to_string(),
                user: "test_wallet.worker1".to_string(),
                pass: "x".to_string(),
            },
            AntminerPool {
                url: "stratum+tcp://pool2.example.com:3333".to_string(),
                user: "test_wallet.worker2".to_string(),
                pass: "x".to_string(),
            },
        ];
        match AntminerWebClient::set_pools(&ip, user, pass, test_pools).await {
            Ok(_)  => println!("  ✅ set_pools success — miner will reboot in ~2 min"),
            Err(e) => println!("  ❌ set_pools failed: {}", e),
        }
    } else {
        println!();
        println!("ℹ️  Run with --write to test pool configuration (triggers reboot).");
    }
}
