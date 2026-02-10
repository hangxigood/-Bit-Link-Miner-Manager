use crate::scanner::{self, ScanConfig};
use crate::core::Miner;

/// Start scanning a network range for miners
/// Returns all discovered miners after scan completes
pub async fn start_scan(ip_range: String) -> anyhow::Result<Vec<Miner>> {
    // Validate IP range first
    let _ips = scanner::parse_ip_range(&ip_range)
        .map_err(|e| anyhow::anyhow!("Invalid IP range: {}", e))?;
    
    // Use default scan configuration
    let config = ScanConfig::default();
    
    // Start the scan
    let mut rx = scanner::scan_range(&ip_range, config).await?;

    
    // Collect all found miners
    let mut miners = Vec::new();
    
    while let Some(event) = rx.recv().await {
        if let scanner::ScanEvent::Found(miner) = event {
            miners.push(miner);
        }
    }
    
    Ok(miners)
}

/// Validate an IP range string without starting a scan
pub fn validate_ip_range(range: String) -> Result<String, String> {
    match scanner::parse_ip_range(&range) {
        Ok(ips) => Ok(format!("Valid range: {} IPs", ips.len())),
        Err(e) => Err(format!("Invalid range: {}", e)),
    }
}
