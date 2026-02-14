use crate::client::{get_summary, DEFAULT_TIMEOUT_MS};
use crate::core::{Miner, MinerStatus};
use dashmap::DashMap;
use std::sync::Arc;
use std::time::{Duration, SystemTime};
use tokio::sync::mpsc;

/// Events emitted by the monitor
#[derive(Debug, Clone)]
pub enum MonitorEvent {
    /// A new miner was added to monitoring
    MinerAdded(Miner),
    /// A miner's status or stats changed
    MinerUpdated(Miner),
    /// A miner was removed from monitoring
    MinerRemoved(String),
    /// Full snapshot of all miners
    FullSnapshot(Vec<Miner>),
}

/// Configuration for the monitor
#[derive(Debug, Clone)]
pub struct MonitorConfig {
    pub poll_interval_ms: u64,
    pub retry_attempts: u8,
    pub warning_temp_threshold: f64,
    pub warning_hashrate_ratio: f64,
    pub timeout_ms: u64,
    pub port: u16,
}

impl Default for MonitorConfig {
    fn default() -> Self {
        Self {
            poll_interval_ms: 10000, // 10 seconds
            retry_attempts: 2,
            warning_temp_threshold: 85.0,
            warning_hashrate_ratio: 0.90,
            timeout_ms: DEFAULT_TIMEOUT_MS,
            port: 4028,
        }
    }
}

/// Start monitoring a list of miners
/// Returns a channel receiver that emits MonitorEvent updates
pub async fn start_monitor(
    miners: Vec<Miner>,
    config: MonitorConfig,
) -> mpsc::Receiver<MonitorEvent> {
    let (tx, rx) = mpsc::channel(100);
    
    // Create shared state
    let state: Arc<DashMap<String, Miner>> = Arc::new(DashMap::new());
    
    // Initialize state with miners
    for miner in miners {
        // Use existing miner state
        state.insert(miner.ip.clone(), miner);
    }
    
    // Spawn the polling loop
    tokio::spawn(polling_loop(state, config, tx));
    
    rx
}

/// Internal polling loop that continuously updates miner states
async fn polling_loop(
    state: Arc<DashMap<String, Miner>>,
    config: MonitorConfig,
    tx: mpsc::Sender<MonitorEvent>,
) {
    // Send initial snapshot
    let snapshot: Vec<Miner> = state.iter().map(|entry| entry.value().clone()).collect();
    let _ = tx.send(MonitorEvent::FullSnapshot(snapshot)).await;
    
    loop {
        // Wait for poll interval
        tokio::time::sleep(Duration::from_millis(config.poll_interval_ms)).await;
        
        // Poll each miner concurrently
        let mut tasks = Vec::new();
        
        for entry in state.iter() {
            let ip = entry.key().clone();
            let state = state.clone();
            let config = config.clone();
            let tx = tx.clone();
            
            let task = tokio::spawn(async move {
                poll_single_miner(ip, state, config, tx).await;
            });
            
            tasks.push(task);
        }
        
        // Wait for all polls to complete
        for task in tasks {
            let _ = task.await;
        }
        
        // Send periodic full snapshot (every poll cycle)
        let snapshot: Vec<Miner> = state.iter().map(|entry| entry.value().clone()).collect();
        let _ = tx.send(MonitorEvent::FullSnapshot(snapshot)).await;
    }
}

/// Poll a single miner and update its state
async fn poll_single_miner(
    ip: String,
    state: Arc<DashMap<String, Miner>>,
    config: MonitorConfig,
    tx: mpsc::Sender<MonitorEvent>,
) {
    // Try to get stats with retries
    let mut stats_result = None;
    
    for attempt in 0..=config.retry_attempts {
        match get_summary(&ip, config.port, config.timeout_ms).await {
            Ok(stats) => {
                stats_result = Some(stats);
                break;
            }
            Err(_) if attempt < config.retry_attempts => {
                // Retry after a short delay
                tokio::time::sleep(Duration::from_millis(500)).await;
            }
            Err(_) => {
                // All retries failed
                break;
            }
        }
    }
    
    // Update the miner state
    if let Some(mut entry) = state.get_mut(&ip) {
        let old_status = entry.status.clone();
        
        match stats_result {
            Some(stats) => {
                // Update stats and model
                entry.model = stats.model.clone();
                entry.stats = stats;
                entry.last_updated = current_timestamp();
                
                // Determine new status
                entry.status = determine_status(&entry.stats, &config);
            }
            None => {
                // Failed to get stats - mark as dead
                entry.status = MinerStatus::Dead;
                entry.last_updated = current_timestamp();
            }
        }
        
        // If status changed, send update event
        if entry.status != old_status {
            let _ = tx.send(MonitorEvent::MinerUpdated(entry.clone())).await;
        }
    }
}

/// Determine miner status based on stats and thresholds
fn determine_status(stats: &crate::core::MinerStats, config: &MonitorConfig) -> MinerStatus {
    // Check temperature - find max from all max values
    let max_temp = stats.temp_outlet_max.iter()
        .chain(stats.temp_inlet_max.iter())
        .filter_map(|&t| t)
        .fold(0.0_f64, |max, temp| max.max(temp));
    
    if max_temp >= config.warning_temp_threshold {
        return MinerStatus::Warning;
    }
    
    // Check hashrate (if we have an expected value)
    // For now, we'll consider any positive hashrate as active
    // In a real implementation, you'd compare against expected hashrate
    if stats.hashrate_avg > 0.0 {
        // Could add: if stats.hashrate_avg < expected * config.warning_hashrate_ratio
        MinerStatus::Active
    } else {
        MinerStatus::Warning
    }
}

/// Get current Unix timestamp
fn current_timestamp() -> u64 {
    SystemTime::now()
        .duration_since(SystemTime::UNIX_EPOCH)
        .unwrap()
        .as_secs()
}

/// Get a snapshot of all currently monitored miners
pub fn get_all_miners(state: &Arc<DashMap<String, Miner>>) -> Vec<Miner> {
    state.iter().map(|entry| entry.value().clone()).collect()
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::core::MinerStats;
    
    #[test]
    fn test_status_determination_active() {
        let stats = MinerStats {
            hashrate_avg: 100.0,
            temp_outlet_max: vec![Some(70.0), Some(72.0), Some(71.0)],
            temp_inlet_max: vec![Some(65.0), Some(66.0)],
            ..Default::default()
        };
        
        let config = MonitorConfig::default();
        let status = determine_status(&stats, &config);
        
        assert_eq!(status, MinerStatus::Active);
    }
    
    #[test]
    fn test_status_determination_warning_temp() {
        let stats = MinerStats {
            hashrate_avg: 100.0,
            temp_outlet_max: vec![Some(87.0), Some(88.0), Some(86.0)],
            temp_inlet_max: vec![Some(65.0), Some(66.0)],
            ..Default::default()
        };
        
        let config = MonitorConfig::default();
        let status = determine_status(&stats, &config);
        
        assert_eq!(status, MinerStatus::Warning);
    }
    
    #[test]
    fn test_status_determination_warning_no_hashrate() {
        let stats = MinerStats {
            hashrate_avg: 0.0,
            temp_outlet_max: vec![Some(70.0), Some(72.0)],
            ..Default::default()
        };
        
        let config = MonitorConfig::default();
        let status = determine_status(&stats, &config);
        
        assert_eq!(status, MinerStatus::Warning);
    }
}
