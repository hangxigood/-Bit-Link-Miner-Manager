use rust_lib_frontend::{scan_range, ScanConfig, ScanEvent};
use std::time::Instant;

#[tokio::main]
async fn main() {
    println!("=== Bit-Link Miner Manager - Network Scanner ===\n");
    
    // TODO: Replace with your network range
    let ip_range = "192.168.56.0/24"; // <-- CHANGE THIS
    
    
    let config = ScanConfig::default(); // Uses optimized defaults: 1000ms timeout, 100 concurrent
    
    
    println!("Scanning range: {}", ip_range);
    println!("Max concurrent: {}, Timeout: {}ms", config.max_concurrent, config.timeout_ms);
    println!("Ports: {:?}\n", config.ports);
    
    let start = Instant::now();
    let mut rx = scan_range(ip_range, config)
        .await
        .expect("Failed to start scan");
    
    let mut found_miners = Vec::new();
    
    // Process scan events
    while let Some(event) = rx.recv().await {
        match event {
            ScanEvent::Started { total_ips } => {
                println!("Starting scan of {} IPs...\n", total_ips);
            }
            ScanEvent::Found(miner) => {
                println!("✓ Found miner at {}", miner.ip);
                println!("  Model: {}", miner.model.as_deref().unwrap_or("Unknown"));
                println!("  Hashrate: {:.2} TH/s", miner.stats.hashrate_avg);
                println!("  Uptime: {} seconds ({:.1} hours)", 
                         miner.stats.uptime, 
                         miner.stats.uptime as f64 / 3600.0);
                println!();
                found_miners.push(miner);
            }
            ScanEvent::Progress { scanned, total } => {
                let percent = (scanned as f64 / total as f64) * 100.0;
                print!("\r[Progress: {}/{} ({:.1}%)]", scanned, total, percent);
                use std::io::Write;
                std::io::stdout().flush().unwrap();
            }
            ScanEvent::Complete { found, failed } => {
                println!("\n\n=== Scan Complete ===");
                println!("Found: {} miner(s)", found);
                println!("Failed: {} IP(s)", failed);
                println!("Duration: {:.2}s", start.elapsed().as_secs_f64());
                
                if !found_miners.is_empty() {
                    println!("\nDiscovered Miners:");
                    for miner in &found_miners {
                        println!("  • {} - {} ({:.2} TH/s)", 
                                 miner.ip,
                                 miner.model.as_deref().unwrap_or("Unknown"),
                                 miner.stats.hashrate_avg);
                    }
                }
            }
        }
    }
}
