use crate::monitor::{self, MonitorConfig as BackendMonitorConfig};
use crate::core::Miner;
use std::sync::Arc;
use tokio::sync::Mutex;

// Global monitor state
lazy_static::lazy_static! {
    static ref MONITOR_RX: Arc<Mutex<Option<tokio::sync::mpsc::Receiver<monitor::MonitorEvent>>>> = 
        Arc::new(Mutex::new(None));
    static ref CURRENT_MINERS: Arc<Mutex<Vec<Miner>>> = Arc::new(Mutex::new(Vec::new()));
}

/// Start monitoring a list of miner IPs
/// This initializes the background polling loop
pub async fn start_monitoring(ips: Vec<String>) -> anyhow::Result<()> {
    let config = BackendMonitorConfig::default();
    
    let rx = monitor::start_monitor(ips, config).await;
    
    // Store the receiver globally
    let mut guard = MONITOR_RX.lock().await;
    *guard = Some(rx);
    
    // Spawn a task to update the current miners state
    tokio::spawn(async {
        update_miners_loop().await;
    });
    
    Ok(())
}

/// Background task to update miners state
async fn update_miners_loop() {
    loop {
        let mut guard = MONITOR_RX.lock().await;
        
        if let Some(rx) = guard.as_mut() {
            if let Some(event) = rx.recv().await {
                match event {
                    monitor::MonitorEvent::MinerUpdated(miner) => {
                        let mut miners = CURRENT_MINERS.lock().await;
                        if let Some(existing) = miners.iter_mut().find(|m| m.ip == miner.ip) {
                            *existing = miner;
                        } else {
                            miners.push(miner);
                        }
                    }
                    monitor::MonitorEvent::MinerAdded(miner) => {
                        let mut miners = CURRENT_MINERS.lock().await;
                        miners.push(miner);
                    }
                    monitor::MonitorEvent::MinerRemoved(ip) => {
                        let mut miners = CURRENT_MINERS.lock().await;
                        miners.retain(|m| m.ip != ip);
                    }
                    monitor::MonitorEvent::FullSnapshot(miners) => {
                        let mut current = CURRENT_MINERS.lock().await;
                        *current = miners;
                    }
                }
            } else {
                // Channel closed
                break;
            }
        } else {
            // No monitor running
            tokio::time::sleep(std::time::Duration::from_millis(100)).await;
        }
    }
}

/// Get current snapshot of all monitored miners
pub async fn get_current_miners() -> Vec<Miner> {
    let miners = CURRENT_MINERS.lock().await;
    miners.clone()
}

/// Stop the monitor
pub async fn stop_monitoring() {
    let mut guard = MONITOR_RX.lock().await;
    *guard = None;
}
