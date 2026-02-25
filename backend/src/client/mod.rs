use crate::core::{MinerError, MinerStats, Result};
use serde::{Deserialize, Serialize};
use std::time::Duration;
use tokio::io::{AsyncReadExt, AsyncWriteExt};
use tokio::net::TcpStream;
use tokio::time::{timeout, timeout_at};

pub mod parsers;
pub mod whatsminer_web;
pub mod antminer_web;
use parsers::{MinerParser, AntminerParser, WhatsminerParser};

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
    #[serde(rename = "Description")]
    description: Option<String>,
}

/// Summary data from CGMiner (supports both Antminer and Whatsminer formats)
#[derive(Debug, Deserialize)]
pub struct SummaryData {
    #[serde(rename = "Elapsed")]
    pub elapsed: Option<u64>,
    
    // Antminer format
    #[serde(rename = "MHS av")]
    pub mhs_av: Option<f64>,
    
    // Whatsminer format
    #[serde(rename = "MHS 5s")]
    pub mhs_5s: Option<f64>,

    #[serde(rename = "HS 5s")]
    pub hs_5s: Option<String>,
    
    #[serde(rename = "GHS 5s")]
    pub ghs_5s: Option<f64>,

    #[serde(rename = "GHS av")]
    pub ghs_av: Option<f64>,

    // Whatsminer Specifics
    #[serde(rename = "Chip Temp Min")]
    pub chip_temp_min: Option<f64>,
    #[serde(rename = "Chip Temp Max")]
    pub chip_temp_max: Option<f64>,
    
    #[serde(rename = "Fan Speed In")]
    pub fan_speed_in: Option<u64>,
    #[serde(rename = "Fan Speed Out")]
    pub fan_speed_out: Option<u64>,

    #[serde(rename = "Temperature")]
    pub temperature: Option<f64>,

    #[serde(rename = "Firmware Version")]
    pub firmware_version: Option<String>,
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
    // 1. Get Summary (Main health check & Type detection)
    let response_str = send_command(ip, port, "summary", timeout_ms).await?;
    
    // Clean response
    let json_str = crate::utils::extract_clean_json(&response_str)
        .unwrap_or_else(|| response_str.trim_matches(|c: char| c.is_whitespace() || c == '\0').to_string());
    
    // Parse the response
    let response: CgMinerResponse = serde_json::from_str(&json_str)?;
    
    // Check status
    let status_desc_raw = response.status.first().and_then(|s| s.description.clone());
    let status_desc = status_desc_raw.as_deref().unwrap_or_default().to_lowercase();
    
    // Extract summary data
    let summary = response
        .summary
        .and_then(|s| s.into_iter().next())
        .ok_or(MinerError::InvalidResponse)?;

    // 2. Detect Miner Type
    let is_whatsminer = summary.firmware_version.is_some() || status_desc.contains("whatsminer");
    
    let parser = if is_whatsminer {
        MinerParser::Whatsminer(WhatsminerParser)
    } else {
        MinerParser::Antminer(AntminerParser)
    };

    // 3. Parse Base Stats
    let mut stats = parser.parse_summary(&summary)?;

    // If Whatsminer, update software field from Status Description if available
    if is_whatsminer {
        if let Some(desc) = status_desc_raw {
            if !desc.is_empty() {
                stats.software = Some(desc);
            }
        }
    }

    // 4. Fetch Details (Model, Temps, Fans, Pools, etc.)
    parser.fetch_details(ip, port, timeout_ms, &mut stats).await?;
    
    Ok(stats)
}

/// Look up a device's MAC address from the OS ARP table.
pub(crate) async fn lookup_mac_address(ip: &str) -> Option<String> {
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
    } else if cfg!(target_os = "windows") {
        // Windows: `arp -a <ip>` ships with every Windows installation
        match tokio::process::Command::new("arp")
            .arg("-a")
            .arg(ip)
            .output()
            .await {
            Ok(o) => o,
            Err(e) => {
                eprintln!("[MAC] Failed to execute 'arp -a' command for {}: {}", ip, e);
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

    parse_mac_from_arp_output(&stdout)
}

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

/// Parse hashrate strings like "13.5T" or "13500G" to TH/s
pub(crate) fn parse_hashrate_string(s: &str) -> Result<f64> {
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
        // Try parsing as number directly? Some send raw number
         if let Ok(num) = s.parse::<f64>() {
             return Ok(num);
         }
        // If it's something like "13.5 TH/s", we might need more robust parsing
        // But for now sticking to existing behavior
        Err(MinerError::InvalidResponse)
    }
}

pub(crate) fn parse_stats_data(json: &str) -> (Vec<Option<f64>>, Vec<Option<f64>>, Vec<Option<f64>>, Vec<Option<f64>>, Vec<Option<u32>>) {
    let mut temp_outlet_min = vec![None, None, None]; // Chip temps min (outlet)
    let mut temp_outlet_max = vec![None, None, None]; // Chip temps max (outlet)
    let mut temp_inlet_min = vec![None, None, None];  // PCB temps min (inlet)
    let mut temp_inlet_max = vec![None, None, None];  // PCB temps max (inlet)
    let mut fans = vec![None, None, None, None];

    if let Ok(resp) = serde_json::from_str::<CgMinerStatsResponse>(json) {
        if let Some(stats_vec) = resp.stats {
            for stat in stats_vec {
                if let Some(obj) = stat.as_object() {
                    for (k, v) in obj {
                        // Parse specific fan indices: fan1, fan2, fan3, fan4
                        if k == "fan1" {
                            if let Some(speed) = v.as_u64() {
                                if speed > 0 {
                                    fans[0] = Some(speed as u32);
                                }
                            }
                        } else if k == "fan2" {
                             if let Some(speed) = v.as_u64() {
                                if speed > 0 {
                                    fans[1] = Some(speed as u32);
                                }
                            }
                        } else if k == "fan3" {
                             if let Some(speed) = v.as_u64() {
                                if speed > 0 {
                                    fans[2] = Some(speed as u32);
                                }
                            }
                        } else if k == "fan4" {
                             if let Some(speed) = v.as_u64() {
                                if speed > 0 {
                                    fans[3] = Some(speed as u32);
                                }
                            }
                        }
                        // Parse specific chip temp indices: temp_chip1, temp_chip2, temp_chip3
                        else if k == "temp_chip1" {
                            let (min, max) = parse_temp_min_max(v);
                            temp_outlet_min[0] = min;
                            temp_outlet_max[0] = max;
                        } else if k == "temp_chip2" {
                            let (min, max) = parse_temp_min_max(v);
                            temp_outlet_min[1] = min;
                            temp_outlet_max[1] = max;
                        } else if k == "temp_chip3" {
                            let (min, max) = parse_temp_min_max(v);
                            temp_outlet_min[2] = min;
                            temp_outlet_max[2] = max;
                        }
                        // Parse specific PCB temp indices: temp_pcb1, temp_pcb2, temp_pcb3
                        else if k == "temp_pcb1" {
                            let (min, max) = parse_temp_min_max(v);
                            temp_inlet_min[0] = min;
                            temp_inlet_max[0] = max;
                        } else if k == "temp_pcb2" {
                            let (min, max) = parse_temp_min_max(v);
                            temp_inlet_min[1] = min;
                            temp_inlet_max[1] = max;
                        } else if k == "temp_pcb3" {
                            let (min, max) = parse_temp_min_max(v);
                            temp_inlet_min[2] = min;
                            temp_inlet_max[2] = max;
                        }
                    }
                }
            }
        }
    }

    (temp_outlet_min, temp_outlet_max, temp_inlet_min, temp_inlet_max, fans)
}

/// Helper function to parse temperature values from JSON - returns min and max
fn parse_temp_min_max(v: &serde_json::Value) -> (Option<f64>, Option<f64>) {
    if let Some(s) = v.as_str() {
        // Parse "45-62" or "40-40-60-60" -> (min, max)
        return parse_temp_string(s);
    } else if let Some(n) = v.as_f64() {
        if n > 0.0 {
            return (Some(n), Some(n));
        }
    }
    (None, None)
}

fn parse_temp_string(s: &str) -> (Option<f64>, Option<f64>) {
    // Format: "min-max" or "min-min-max-max" or just "temp"
    // Return (min, max)
    let temps: Vec<f64> = s.split('-')
        .filter_map(|part| part.parse::<f64>().ok())
        .filter(|&t| t > 0.0)
        .collect();

    if temps.is_empty() {
        return (None, None);
    }

    let min = temps.iter().copied().min_by(|a, b| a.partial_cmp(b).unwrap_or(std::cmp::Ordering::Equal));
    let max = temps.iter().copied().max_by(|a, b| a.partial_cmp(b).unwrap_or(std::cmp::Ordering::Equal));

    (min, max)
}

pub(crate) fn parse_pools_data(json: &str) -> (Option<String>, Option<String>, Option<String>, Option<String>, Option<String>, Option<String>) {
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

pub(crate) fn parse_version_data(json: &str) -> (Option<String>, Option<String>, Option<String>, Option<String>) {
    if let Ok(resp) = serde_json::from_str::<CgMinerVersionResponse>(json) {
        if let Some(versions) = resp.version {
            if let Some(v) = versions.first() {
                // Hardware: "Miner" field (e.g. "uart_trans.1.3")
                let hardware = v.miner.clone();
                
                // Firmware: "CompileTime" formatted as YYYYMMDD
                let firmware = v.compile_time.as_deref().map(parse_compile_time).flatten();
                
                // Software: "Bmminer " + "BMMiner" field
                let software = v.bm_miner.as_ref().map(|s| format!("Bmminer {}", s));
                
                // Model: "Type" field (e.g. "Antminer S19")
                let model = v._type.clone();
                
                return (hardware, firmware, software, model); 
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
        assert_eq!(parse_temp_string("40-40-60-60"), (Some(40.0), Some(60.0)));
        assert_eq!(parse_temp_string("40-60"), (Some(40.0), Some(60.0)));
        assert_eq!(parse_temp_string("50"), (Some(50.0), Some(50.0)));
    }
}
