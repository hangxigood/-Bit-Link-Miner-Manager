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

/// Detect local network interfaces and return their /24 subnet ranges.
/// Filters out loopback (127.x.x.x) and link-local (169.254.x.x) addresses.
pub fn detect_local_ranges() -> Vec<String> {
    use network_interface::{NetworkInterface, NetworkInterfaceConfig};
    use std::collections::HashSet;

    let mut ranges = HashSet::new();

    if let Ok(interfaces) = NetworkInterface::show() {
        for iface in interfaces {
            for addr in &iface.addr {
                if let network_interface::Addr::V4(v4) = addr {
                    let ip = v4.ip;
                    let octets = ip.octets();

                    // Skip loopback
                    if octets[0] == 127 {
                        continue;
                    }
                    // Skip link-local
                    if octets[0] == 169 && octets[1] == 254 {
                        continue;
                    }

                    let range = format!(
                        "{}.{}.{}.1-{}.{}.{}.254",
                        octets[0], octets[1], octets[2],
                        octets[0], octets[1], octets[2]
                    );
                    ranges.insert(range);
                }
            }
        }
    }

    let mut result: Vec<String> = ranges.into_iter().collect();
    result.sort();
    result
}
