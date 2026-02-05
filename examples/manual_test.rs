use bitlink_miner_manager::{get_summary, send_command, DEFAULT_PORT, DEFAULT_TIMEOUT_MS};

#[tokio::main]
async fn main() {
    println!("=== Bit-Link Miner Manager - Manual Test ===\n");
    
    // TODO: Replace with your actual miner IP
    let miner_ip = "192.168.56.31"; // <-- CHANGE THIS
    let port = DEFAULT_PORT;
    
    println!("Attempting to connect to miner at {}:{}...", miner_ip, port);
    
    // Test basic connection with version command
    match send_command(miner_ip, port, "version", DEFAULT_TIMEOUT_MS).await {
        Ok(response) => {
            println!("✓ Connection successful!");
            println!("Version response: {}\n", response);
        }
        Err(e) => {
            eprintln!("✗ Failed to connect: {}", e);
            eprintln!("Please check:");
            eprintln!("  1. Miner IP address is correct");
            eprintln!("  2. Miner is powered on and connected to network");
            eprintln!("  3. API port {} is accessible", port);
            std::process::exit(1);
        }
    }
    
    // Test summary command
    println!("Fetching miner summary...");
    match get_summary(miner_ip, port, DEFAULT_TIMEOUT_MS).await {
        Ok(stats) => {
            println!("✓ Summary retrieved successfully!\n");
            println!("Miner Statistics:");
            println!("  Hashrate (avg): {:.2} TH/s", stats.hashrate_avg);
            println!("  Hashrate (rt):  {:.2} TH/s", stats.hashrate_rt);
            println!("  Uptime:         {} seconds ({:.1} hours)", 
                     stats.uptime, stats.uptime as f64 / 3600.0);
            println!("  Chip temps:     {:?}", stats.temperature_chip);
            println!("  PCB temps:      {:?}", stats.temperature_pcb);
            println!("  Fan speeds:     {:?}", stats.fan_speeds);
        }
        Err(e) => {
            eprintln!("✗ Failed to get summary: {}", e);
            std::process::exit(1);
        }
    }
    
    println!("\n=== Test completed successfully! ===");
}
