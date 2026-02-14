use rust_lib_frontend::{
    scan_range, start_monitor, MonitorConfig, MonitorEvent, ScanConfig, ScanEvent, Miner,
};
use std::time::Instant;

#[tokio::main]
async fn main() {
    println!("=== Bit-Link Miner Manager - Monitor Demo ===\n");

    // Step 1: Discover miners
    println!("Step 1: Scanning network for miners...");
    let ip_range = "192.168.56.0/24"; // <-- CHANGE THIS

    let scan_config = ScanConfig::default();
    let mut scan_rx = scan_range(ip_range, scan_config)
        .await
        .expect("Failed to start scan");

    let mut discovered_miners: Vec<Miner> = Vec::new();

    while let Some(event) = scan_rx.recv().await {
        match event {
            ScanEvent::Found(miner) => {
                println!("  ✓ Found: {} ({})", miner.ip, miner.model.as_deref().unwrap_or("Unknown"));
                discovered_miners.push(miner);
            }
            ScanEvent::Complete { found, .. } => {
                println!("\nScan complete! Found {} miner(s)\n", found);
                break;
            }
            _ => {}
        }
    }

    if discovered_miners.is_empty() {
        println!("No miners found. Exiting.");
        return;
    }

    // Step 2: Start monitoring
    println!("Step 2: Starting continuous monitoring...");
    println!("Monitoring {} miner(s) with 10-second poll interval", discovered_miners.len());
    println!("Press Ctrl+C to stop\n");

    let monitor_config = MonitorConfig::default();
    let mut monitor_rx = start_monitor(discovered_miners, monitor_config).await;

    let start_time = Instant::now();
    let mut update_count = 0;

    // Step 3: Display real-time updates
    while let Some(event) = monitor_rx.recv().await {
        match event {
            MonitorEvent::MinerAdded(miner) => {
                println!("[{:>6.1}s] ➕ Added: {}", 
                         start_time.elapsed().as_secs_f64(), 
                         miner.ip);
            }
            MonitorEvent::MinerUpdated(miner) => {
                update_count += 1;
                println!("[{:>6.1}s] 🔄 Updated: {} - Status: {:?}", 
                         start_time.elapsed().as_secs_f64(),
                         miner.ip, 
                         miner.status);
            }
            MonitorEvent::MinerRemoved(ip) => {
                println!("[{:>6.1}s] ➖ Removed: {}", 
                         start_time.elapsed().as_secs_f64(), 
                         ip);
            }
            MonitorEvent::FullSnapshot(miners) => {
                println!("\n[{:>6.1}s] 📊 Status Snapshot ({} updates so far):", 
                         start_time.elapsed().as_secs_f64(),
                         update_count);
                println!("  ┌────────────────────┬──────────┬────────────┬──────────┐");
                println!("  │ IP Address         │ Status   │ Hashrate   │ Max Temp │");
                println!("  ├────────────────────┼──────────┼────────────┼──────────┤");
                
                for miner in &miners {
                    let status_icon = match miner.status {
                        rust_lib_frontend::MinerStatus::Active => "✅",
                        rust_lib_frontend::MinerStatus::Warning => "⚠️ ",
                        rust_lib_frontend::MinerStatus::Dead => "❌",
                        rust_lib_frontend::MinerStatus::Scanning => "🔍",
                    };
                    
                    let max_temp = miner.stats.temp_outlet_max.iter()
                        .chain(miner.stats.temp_inlet_max.iter())
                        .filter_map(|&t| t)
                        .fold(0.0_f64, |max, temp| max.max(temp));
                    
                    println!("  │ {:<18} │ {} {:6} │ {:>7.2} TH │ {:>6.1}°C │",
                             miner.ip,
                             status_icon,
                             format!("{:?}", miner.status),
                             miner.stats.hashrate_avg,
                             max_temp);
                }
                
                println!("  └────────────────────┴──────────┴────────────┴──────────┘\n");
            }
        }
    }
}
