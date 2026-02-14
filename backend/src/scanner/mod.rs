use crate::core::{Miner, MinerError, MinerStatus, Result};
use crate::client::{get_summary, send_command};
use ipnetwork::IpNetwork;
use std::net::IpAddr;
use std::sync::Arc;
use std::time::SystemTime;
use tokio::sync::{mpsc, Semaphore};

/// Events emitted during network scanning
#[derive(Debug, Clone)]
pub enum ScanEvent {
    /// Scan has started
    Started { total_ips: usize },
    /// Found a miner
    Found(Miner),
    /// Progress update
    Progress { scanned: usize, total: usize },
    /// Scan completed
    Complete { found: usize, failed: usize },
}

/// Configuration for network scanning
#[derive(Debug, Clone)]
pub struct ScanConfig {
    pub timeout_ms: u64,
    pub max_concurrent: usize,
    pub ports: Vec<u16>,
}

impl Default for ScanConfig {
    fn default() -> Self {
        Self {
            timeout_ms: 500,  
            max_concurrent: 100,
            ports: vec![4028], //4028, 4029, 4030 when need to scan more ports
        }
    }
}

/// Parse an IP range string into a list of IP addresses
/// Supports two formats:
/// - CIDR notation: "192.168.1.0/24"
/// - Range notation: "192.168.1.1-192.168.1.254"
pub fn parse_ip_range(range: &str) -> Result<Vec<IpAddr>> {
    // Try CIDR notation first
    if range.contains('/') {
        let network: IpNetwork = range
            .parse()
            .map_err(|_| MinerError::InvalidResponse)?;
        
        Ok(network.iter().collect())
    }
    // Try range notation (e.g., "192.168.1.1-192.168.1.254")
    else if range.contains('-') {
        let parts: Vec<&str> = range.split('-').collect();
        if parts.len() != 2 {
            return Err(MinerError::InvalidResponse);
        }
        
        let start: IpAddr = parts[0]
            .trim()
            .parse()
            .map_err(|_| MinerError::InvalidResponse)?;
        let end: IpAddr = parts[1]
            .trim()
            .parse()
            .map_err(|_| MinerError::InvalidResponse)?;
        
        // Generate range (only works for IPv4)
        match (start, end) {
            (IpAddr::V4(start_v4), IpAddr::V4(end_v4)) => {
                let start_num = u32::from(start_v4);
                let end_num = u32::from(end_v4);
                
                if start_num > end_num {
                    return Err(MinerError::InvalidResponse);
                }
                
                let ips: Vec<IpAddr> = (start_num..=end_num)
                    .map(|n| IpAddr::V4(n.into()))
                    .collect();
                
                Ok(ips)
            }
            _ => Err(MinerError::InvalidResponse),
        }
    }
    // Single IP
    else {
        let ip: IpAddr = range
            .parse()
            .map_err(|_| MinerError::InvalidResponse)?;
        Ok(vec![ip])
    }
}

/// Scan a network range for miners
/// Returns a channel receiver that emits ScanEvent updates
pub async fn scan_range(
    range: &str,
    config: ScanConfig,
) -> Result<mpsc::Receiver<ScanEvent>> {
    let ips = parse_ip_range(range)?;
    let _total_ips = ips.len();
    
    let (tx, rx) = mpsc::channel(100);
    
    // Spawn the scanning task
    tokio::spawn(async move {
        scan_ips(ips, config, tx).await;
    });
    
    Ok(rx)
}

/// Internal function to scan a list of IPs
async fn scan_ips(
    ips: Vec<IpAddr>,
    config: ScanConfig,
    tx: mpsc::Sender<ScanEvent>,
) {
    let total_ips = ips.len();
    
    // Send started event
    let _ = tx.send(ScanEvent::Started { total_ips }).await;
    
    // Create semaphore to limit concurrent connections
    let semaphore = Arc::new(Semaphore::new(config.max_concurrent));
    let tx = Arc::new(tx);
    
    // Counters
    let scanned = Arc::new(tokio::sync::Mutex::new(0usize));
    let found = Arc::new(tokio::sync::Mutex::new(0usize));
    
    // Spawn tasks for each IP
    let mut tasks = Vec::new();
    
    for ip in ips {
        let semaphore = semaphore.clone();
        let tx = tx.clone();
        let config = config.clone();
        let scanned = scanned.clone();
        let found = found.clone();
        
        let task = tokio::spawn(async move {
            // Acquire semaphore permit
            let _permit = semaphore.acquire().await.unwrap();
            
            // Try to connect to the miner
            if let Some(miner) = scan_single_ip(ip, &config).await {
                // Found a miner!
                *found.lock().await += 1;
                let _ = tx.send(ScanEvent::Found(miner)).await;
            }
            
            // Update progress
            let mut s = scanned.lock().await;
            *s += 1;
            let current = *s;
            drop(s);
            
            // Send progress update every 10 IPs or at completion
            if current % 10 == 0 || current == total_ips {
                let _ = tx.send(ScanEvent::Progress {
                    scanned: current,
                    total: total_ips,
                }).await;
            }
        });
        
        tasks.push(task);
    }
    
    // Wait for all tasks to complete
    for task in tasks {
        let _ = task.await;
    }
    
    // Send completion event
    let found_count = *found.lock().await;
    let failed_count = total_ips - found_count;
    
    let _ = tx.send(ScanEvent::Complete {
        found: found_count,
        failed: failed_count,
    }).await;
}

/// Scan a single IP address for a miner
/// Returns Some(Miner) if found, None otherwise
async fn scan_single_ip(ip: IpAddr, config: &ScanConfig) -> Option<Miner> {
    // Try each port
    for &port in &config.ports {
        // Try to get version first (lightweight check)
        if let Ok(version_response) = send_command(
            &ip.to_string(),
            port,
            "version",
            config.timeout_ms,
        ).await {
            // Successfully connected! Now get detailed stats
            let stats = get_summary(&ip.to_string(), port, config.timeout_ms)
                .await
                .unwrap_or_default();
            
            // Try to extract model from version response
            let model = extract_model_from_version(&version_response);
            
            // Determine status based on stats
            let status = determine_status_from_stats(&stats);
            
            return Some(Miner {
                ip: ip.to_string(),
                model,
                status,
                stats,
                last_updated: SystemTime::now()
                    .duration_since(SystemTime::UNIX_EPOCH)
                    .unwrap()
                    .as_secs(),
            });
        }
    }
    
    None
}

/// Extract miner model from version response
fn extract_model_from_version(response: &str) -> Option<String> {
    // Clean the response first (miners send trailing characters)
    let cleaned = crate::utils::extract_clean_json(response)?;
    
    // Try to parse JSON and extract Type field
    if let Ok(json) = serde_json::from_str::<serde_json::Value>(&cleaned) {
        if let Some(version) = json.get("VERSION") {
            if let Some(version_array) = version.as_array() {
                if let Some(first) = version_array.first() {
                    if let Some(model_type) = first.get("Type") {
                        return model_type.as_str().map(String::from);
                    }
                }
            }
        }
    }
    None
}


/// Determine miner status based on stats
fn determine_status_from_stats(stats: &crate::core::MinerStats) -> MinerStatus {
    // Check temperature - find max from all max values
    let max_temp = stats.temp_outlet_max.iter()
        .chain(stats.temp_inlet_max.iter())
        .filter_map(|&t| t)
        .fold(0.0_f64, |max, temp| max.max(temp));
    
    if max_temp >= 85.0 {
        return MinerStatus::Warning;
    }
    
    // Check hashrate - if positive, it's Active
    if stats.hashrate_avg > 0.0 {
        MinerStatus::Active
    } else {
        MinerStatus::Warning
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    
    #[test]
    fn test_parse_cidr_notation() {
        let ips = parse_ip_range("192.168.1.0/30").unwrap();
        assert_eq!(ips.len(), 4); // .0, .1, .2, .3
        
        let ips = parse_ip_range("10.0.0.0/24").unwrap();
        assert_eq!(ips.len(), 256);
    }
    
    #[test]
    fn test_parse_range_notation() {
        let ips = parse_ip_range("192.168.1.1-192.168.1.5").unwrap();
        assert_eq!(ips.len(), 5);
        assert_eq!(ips[0].to_string(), "192.168.1.1");
        assert_eq!(ips[4].to_string(), "192.168.1.5");
    }
    
    #[test]
    fn test_parse_single_ip() {
        let ips = parse_ip_range("192.168.1.100").unwrap();
        assert_eq!(ips.len(), 1);
        assert_eq!(ips[0].to_string(), "192.168.1.100");
    }
    
    #[test]
    fn test_invalid_range() {
        // End before start
        let result = parse_ip_range("192.168.1.100-192.168.1.50");
        assert!(result.is_err());
    }
}
