use crate::core::{MinerError, MinerStats, Result};
use serde::{Deserialize, Serialize};
use std::time::Duration;
use tokio::io::{AsyncReadExt, AsyncWriteExt};
use tokio::net::TcpStream;
use tokio::time::timeout;

/// Default CGMiner API port
pub const DEFAULT_PORT: u16 = 4028;

/// Default connection timeout
pub const DEFAULT_TIMEOUT_MS: u64 = 1500;

/// CGMiner JSON-RPC request format
#[derive(Debug, Serialize)]
struct CgMinerRequest {
    command: String,
    parameter: String,
}

/// CGMiner JSON-RPC response wrapper
#[derive(Debug, Deserialize)]
struct CgMinerResponse {
    #[serde(rename = "STATUS")]
    status: Vec<StatusInfo>,
    #[serde(rename = "SUMMARY")]
    summary: Option<Vec<SummaryData>>,
}

#[derive(Debug, Deserialize)]
struct StatusInfo {
    #[serde(rename = "STATUS")]
    status: String,
    #[serde(rename = "Msg")]
    _msg: String,
}

/// Summary data from CGMiner (supports both Antminer and Whatsminer formats)
#[derive(Debug, Deserialize)]
struct SummaryData {
    #[serde(rename = "Elapsed")]
    elapsed: Option<u64>,
    
    // Antminer format
    #[serde(rename = "MHS av")]
    mhs_av: Option<f64>,
    
    // Whatsminer format
    #[serde(rename = "HS 5s")]
    hs_5s: Option<String>,
    
    #[serde(rename = "GHS 5s")]
    ghs_5s: Option<f64>,

    #[serde(rename = "GHS av")]
    ghs_av: Option<f64>,
}

#[derive(Debug, Deserialize)]
struct CgMinerStatsResponse {
    #[serde(rename = "STATS")]
    stats: Option<Vec<serde_json::Value>>,
}

#[derive(Debug, Deserialize)]
struct CgMinerPoolsResponse {
    #[serde(rename = "POOLS")]
    pools: Option<Vec<PoolData>>,
}

#[derive(Debug, Deserialize)]
struct PoolData {
    #[serde(rename = "URL")]
    url: String,
    #[serde(rename = "User")]
    user: String,
    #[serde(rename = "Status")]
    _status: String,
    #[serde(rename = "Priority")]
    priority: u64,
}

#[derive(Debug, Deserialize)]
struct CgMinerVersionResponse {
    #[serde(rename = "VERSION")]
    version: Option<Vec<VersionData>>,
}

#[derive(Debug, Deserialize)]
struct VersionData {
    #[serde(rename = "Type")]
    _type: Option<String>,
    #[serde(rename = "Miner")]
    miner: Option<String>,
    #[serde(rename = "BMMiner")]
    bm_miner: Option<String>,
    #[serde(rename = "CompileTime")]
    compile_time: Option<String>,
}

/// Send a command to a miner and return the raw JSON response
pub async fn send_command(
    ip: &str,
    port: u16,
    command: &str,
    timeout_ms: u64,
) -> Result<String> {
    let address = format!("{}:{}", ip, port);
    let timeout_duration = Duration::from_millis(timeout_ms);
    
    // Create the request
    let request = CgMinerRequest {
        command: command.to_string(),
        parameter: String::new(),
    };
    
    let request_json = serde_json::to_string(&request)?;
    
    // Connect with timeout
    let stream = timeout(timeout_duration, TcpStream::connect(&address))
        .await
        .map_err(|_| MinerError::Timeout(ip.to_string()))?
        .map_err(|e| MinerError::NetworkError(e))?;
    
    let mut stream = stream;
    
    // Send the request
    stream.write_all(request_json.as_bytes()).await?;
    
    // Read the response with timeout
    let mut buffer = Vec::new();
    let read_result = timeout(timeout_duration, stream.read_to_end(&mut buffer))
        .await
        .map_err(|_| MinerError::Timeout(ip.to_string()))?;
    
    read_result?;
    
    // Convert to string, handling potential trailing null bytes or other garbage
    let response = String::from_utf8_lossy(&buffer).to_string();
    
    Ok(response)
}

/// Get summary statistics from a miner
pub async fn get_summary(
    ip: &str,
    port: u16,
    timeout_ms: u64,
) -> Result<MinerStats> {
    // 1. Get Summary (Main health check)
    let response_str = send_command(ip, port, "summary", timeout_ms).await?;
    
    // Real miners often send trailing null bytes or extra characters
    // Find the actual JSON bounds and parse only that portion
    let json_str = extract_json(&response_str)?;
    
    // Parse the response
    let response: CgMinerResponse = serde_json::from_str(&json_str)?;
    
    // Check status
    if let Some(status) = response.status.first() {
        if status.status != "S" {
            return Err(MinerError::InvalidResponse);
        }
    }
    
    // Extract summary data
    let summary = response
        .summary
        .and_then(|s| s.into_iter().next())
        .ok_or(MinerError::InvalidResponse)?;
    
    // Convert to MinerStats (base)
    let mut stats = parse_summary_to_stats(summary)?;

    // 2. Get Detailed Stats (Temps, Fans)
    if let Ok(stats_json) = send_command(ip, port, "stats", timeout_ms).await {
        if let Ok(clean_json) = extract_json(&stats_json) {
            let (chip, pcb, fans) = parse_stats_data(&clean_json);
            stats.temperature_chip = chip;
            stats.temperature_pcb = pcb;
            stats.fan_speeds = fans;
        }
    }

    // 3. Get Pools (Active Pool/Worker)
    if let Ok(pools_json) = send_command(ip, port, "pools", timeout_ms).await {
        if let Ok(clean_json) = extract_json(&pools_json) {
            let (p1, w1, p2, w2, p3, w3) = parse_pools_data(&clean_json);
            stats.pool1 = p1;
            stats.worker1 = w1;
            stats.pool2 = p2;
            stats.worker2 = w2;
            stats.pool3 = p3;
            stats.worker3 = w3;
        }
    }

    // 4. Get Version (Hardware/Firmware)
    if let Ok(version_json) = send_command(ip, port, "version", timeout_ms).await {
        if let Ok(clean_json) = extract_json(&version_json) {
            let (hw, fw, sw, _mac) = parse_version_data(&clean_json);
            stats.hardware = hw;
            stats.firmware = fw;
            stats.software = sw;
        }
    }

    // 5. Get MAC Address (via ARP table lookup)
    stats.mac_address = lookup_mac_address(ip).await;
    
    Ok(stats)
}

/// Look up a device's MAC address from the OS ARP table.
/// After a successful TCP connection, the ARP cache should have an entry for this IP.
async fn lookup_mac_address(ip: &str) -> Option<String> {
    let output = if cfg!(target_os = "macos") {
        match tokio::process::Command::new("arp")
            .arg("-n")
            .arg(ip)
            .output()
            .await {
            Ok(o) => o,
            Err(e) => {
                eprintln!("[MAC] Failed to execute 'arp' command for {}: {}", ip, e);
                return None;
            }
        }
    } else {
        // Linux
        match tokio::process::Command::new("ip")
            .args(["neigh", "show", ip])
            .output()
            .await {
            Ok(o) => o,
            Err(e) => {
                eprintln!("[MAC] Failed to execute 'ip neigh' command for {}: {}", ip, e);
                return None;
            }
        }
    };

    if !output.status.success() {
        eprintln!("[MAC] ARP command failed for {} with status: {}", ip, output.status);
        return None;
    }

    let stdout = String::from_utf8_lossy(&output.stdout);
    
    // If output is empty, it just means no ARP entry (common), so no need to log
    if stdout.trim().is_empty() {
        return None;
    }

    match parse_mac_from_arp_output(&stdout) {
        Some(mac) => Some(mac),
        None => {
            // Only log if we have output but failed to parse it (indicates unexpected format)
            eprintln!("[MAC] Failed to parse MAC from ARP output for {}: '{}'", ip, stdout.trim());
            None
        }
    }
}

/// Parse MAC address from ARP command output.
/// macOS format: "? (192.168.1.1) at aa:bb:cc:dd:ee:ff on en0 ..."
/// Linux format: "192.168.1.1 dev eth0 lladdr aa:bb:cc:dd:ee:ff REACHABLE"
/// Note: macOS sometimes shortens segments (e.g., "72:3c:e:95:5d:83" instead of "72:3c:0e:95:5d:83")
fn parse_mac_from_arp_output(output: &str) -> Option<String> {
    // Look for a MAC address pattern: xx:xx:xx:xx:xx:xx (with possible single-digit segments)
    for word in output.split_whitespace() {
        let parts: Vec<&str> = word.split(':').collect();
        
        // Must have exactly 6 segments
        if parts.len() != 6 {
            continue;
        }
        
        // Each segment must be 1-2 hex digits
        if !parts.iter().all(|p| {
            (p.len() == 1 || p.len() == 2) && p.chars().all(|c| c.is_ascii_hexdigit())
        }) {
            continue;
        }
        
        // Normalize: pad single-digit segments with leading zero and uppercase
        let normalized = parts
            .iter()
            .map(|p| {
                if p.len() == 1 {
                    format!("0{}", p.to_uppercase())
                } else {
                    p.to_uppercase()
                }
            })
            .collect::<Vec<String>>()
            .join(":");
        
        return Some(normalized);
    }
    None
}

/// Extract clean JSON from a response that may have trailing characters
/// Miners often append null bytes, newlines, or other garbage after the JSON
fn extract_json(response: &str) -> Result<String> {
    // Remove leading/trailing whitespace and null bytes
    let trimmed = response.trim_matches(|c: char| c.is_whitespace() || c == '\0');
    
    // Find the last closing brace - that's where the JSON should end
    if let Some(last_brace) = trimmed.rfind('}') {
        let json_str = &trimmed[..=last_brace];
        
        // Basic validation: should start with '{'
        if json_str.starts_with('{') {
            return Ok(json_str.to_string());
        }
    }
    
    // If we can't find valid JSON boundaries, return the trimmed string
    // and let serde_json give us a more specific error
    Ok(trimmed.to_string())
}

/// Parse summary data into MinerStats, handling different miner models
fn parse_summary_to_stats(summary: SummaryData) -> Result<MinerStats> {
    // Determine hashrate based on available fields
    let hashrate_avg = if let Some(mhs) = summary.mhs_av {
        // Antminer format: MHS (MH/s) -> convert to TH/s
        mhs / 1_000_000.0
    } else if let Some(ghs) = summary.ghs_av {
        // GHS (GH/s) -> convert to TH/s
        ghs / 1000.0
    } else if let Some(hs_5s) = &summary.hs_5s {
         // Whatsminer format often puts avg in 5s? No, typically avg is elsewhere
         // For now fallback to parsing 5s as avg if nothing else
        parse_hashrate_string(hs_5s)?
    } else {
        0.0
    };

    // Determine Real-Time Hashrate
    let hashrate_rt = if let Some(ghs_5s) = summary.ghs_5s {
        ghs_5s / 1000.0
    } else if let Some(hs_5s) = &summary.hs_5s {
        parse_hashrate_string(hs_5s)?
    } else {
        hashrate_avg // Fallback
    };
    
    Ok(MinerStats {
        hashrate_rt, 
        hashrate_avg,
        temperature_chip: Vec::new(), // Will be populated from detailed stats
        temperature_pcb: Vec::new(),
        fan_speeds: Vec::new(),
        uptime: summary.elapsed.unwrap_or(0),
        pool1: None,
        worker1: None,
        pool2: None,
        worker2: None,
        pool3: None,
        worker3: None,
        firmware: None,
        software: None,
        hardware: None,
        mac_address: None,
    })
}

/// Parse hashrate strings like "13.5T" or "13500G" to TH/s
fn parse_hashrate_string(s: &str) -> Result<f64> {
    let s = s.trim();
    
    if s.ends_with('T') {
        let num = s.trim_end_matches('T').parse::<f64>()
            .map_err(|_| MinerError::InvalidResponse)?;
        Ok(num)
    } else if s.ends_with('G') {
        let num = s.trim_end_matches('G').parse::<f64>()
            .map_err(|_| MinerError::InvalidResponse)?;
        Ok(num / 1000.0)
    } else {
        Err(MinerError::InvalidResponse)
    }
}

fn parse_stats_data(json: &str) -> (Vec<f64>, Vec<f64>, Vec<u32>) {
    let mut chip_temps = Vec::new();
    let mut pcb_temps = Vec::new();
    let mut fans = Vec::new();

    if let Ok(resp) = serde_json::from_str::<CgMinerStatsResponse>(json) {
        if let Some(stats_vec) = resp.stats {
            for stat in stats_vec {
                if let Some(obj) = stat.as_object() {
                    // Fans
                    for (k, v) in obj {
                        if k.starts_with("fan") && !k.contains("num") {
                            if let Some(speed) = v.as_u64() {
                                if speed > 0 {
                                    fans.push(speed as u32);
                                }
                            }
                        }
                        
                        // Temps (chip)
                        if k.starts_with("temp_chip") {
                            if let Some(s) = v.as_str() {
                                // Parse "45-45-62-62" -> max 62
                                if let Some(max_t) = parse_temp_string(s) {
                                    if max_t > 0.0 {
                                        chip_temps.push(max_t);
                                    }
                                }
                            } else if let Some(n) = v.as_f64() {
                                if n > 0.0 {
                                    chip_temps.push(n);
                                }
                            }
                        }
                        // Also try generic temp{N} if temp_chip not found
                         else if k.starts_with("temp") && !k.contains("pcb") && !k.contains("num") && !k.contains("_") {
                            if let Some(n) = v.as_f64() {
                                if n > 0.0 {
                                    chip_temps.push(n);
                                }
                            }
                        }

                        // Temps (pcb)
                        if k.starts_with("temp_pcb") {
                            if let Some(s) = v.as_str() {
                                if let Some(max_t) = parse_temp_string(s) {
                                    if max_t > 0.0 {
                                        pcb_temps.push(max_t);
                                    }
                                }
                            } else if let Some(n) = v.as_f64() {
                                if n > 0.0 {
                                    pcb_temps.push(n);
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    
    // De-duplicate and sort
    fans.sort();
    fans.dedup(); // Sometimes multiple stats report same fans?
    
    // Sort logic isn't strictly necessary but clean
    
    (chip_temps, pcb_temps, fans)
}

fn parse_temp_string(s: &str) -> Option<f64> {
    // Format: "min-min-max-max" or just "temp"
    // We want the max temperature to be safe
    s.split('-')
     .filter_map(|part| part.parse::<f64>().ok())
     .max_by(|a, b| a.partial_cmp(b).unwrap_or(std::cmp::Ordering::Equal)) // Use max for safety monitoring
}

fn parse_pools_data(json: &str) -> (Option<String>, Option<String>, Option<String>, Option<String>, Option<String>, Option<String>) {
    if let Ok(resp) = serde_json::from_str::<CgMinerPoolsResponse>(json) {
        if let Some(pools) = resp.pools {
             let mut sorted_pools: Vec<&PoolData> = pools.iter().collect();
             sorted_pools.sort_by_key(|p| p.priority);
             
             let p1 = sorted_pools.get(0).map(|p| p.url.clone());
             let w1 = sorted_pools.get(0).map(|p| p.user.clone());
             
             let p2 = sorted_pools.get(1).map(|p| p.url.clone());
             let w2 = sorted_pools.get(1).map(|p| p.user.clone());
             
             let p3 = sorted_pools.get(2).map(|p| p.url.clone());
             let w3 = sorted_pools.get(2).map(|p| p.user.clone());
             
             return (p1, w1, p2, w2, p3, w3);
        }
    }
    (None, None, None, None, None, None)
}

fn parse_version_data(json: &str) -> (Option<String>, Option<String>, Option<String>, Option<String>) {
    if let Ok(resp) = serde_json::from_str::<CgMinerVersionResponse>(json) {
        if let Some(versions) = resp.version {
            if let Some(v) = versions.first() {
                // Hardware: "Miner" field (e.g. "uart_trans.1.3")
                let hardware = v.miner.clone();
                
                // Firmware: "CompileTime" formatted as YYYYMMDD
                let firmware = v.compile_time.as_deref().map(parse_compile_time).flatten();
                
                // Software: "Bmminer " + "BMMiner" field
                let software = v.bm_miner.as_ref().map(|s| format!("Bmminer {}", s));
                
                return (hardware, firmware, software, None); 
            }
        }
    }
    (None, None, None, None)
}

/// Parses "Fri Feb  7 18:12:53 CST 2025" to "20250207"
fn parse_compile_time(s: &str) -> Option<String> {
    // Split by whitespace. 
    // Example: ["Fri", "Feb", "7", "18:12:53", "CST", "2025"]
    // Note: there might be double spaces, split_whitespace handles that.
    let parts: Vec<&str> = s.split_whitespace().collect();
    
    if parts.len() < 6 {
        return None;
    }
    
    let month_str = parts[1];
    let day_str = parts[2];
    let year_str = parts[5]; // checking index 5 for year
    
    let month_num = match month_str {
        "Jan" => "01", "Feb" => "02", "Mar" => "03", "Apr" => "04",
        "May" => "05", "Jun" => "06", "Jul" => "07", "Aug" => "08",
        "Sep" => "09", "Oct" => "10", "Nov" => "11", "Dec" => "12",
        _ => return None,
    };
    
    // Pad day with 0 if needed
    let day_padded = if day_str.len() == 1 {
        format!("0{}", day_str)
    } else {
        day_str.to_string()
    };
    
    Some(format!("{}{}{}", year_str, month_num, day_padded))
}


#[cfg(test)]
mod tests {
    use super::*;
    
    #[test]
    fn test_parse_hashrate_string() {
        assert_eq!(parse_hashrate_string("13.5T").unwrap(), 13.5);
        assert_eq!(parse_hashrate_string("100G").unwrap(), 0.1);
        assert_eq!(parse_hashrate_string("1000G").unwrap(), 1.0);
    }
    
    #[test]
    fn test_parse_temp_string() {
        assert_eq!(parse_temp_string("40-40-60-60"), Some(60.0));
        assert_eq!(parse_temp_string("50"), Some(50.0));
    }
}
