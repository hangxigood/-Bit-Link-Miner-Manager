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
    
    #[serde(rename = "GHS av")]
    ghs_av: Option<f64>,
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
    
    // Convert to MinerStats
    let stats = parse_summary_to_stats(summary)?;
    
    Ok(stats)
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
    } else if let Some(hs_5s) = summary.hs_5s {
        // Whatsminer format: parse string like "13.5T" or "13500G"
        parse_hashrate_string(&hs_5s)?
    } else {
        0.0
    };
    
    Ok(MinerStats {
        hashrate_rt: hashrate_avg, // For now, use avg as rt (will be refined in Step 3)
        hashrate_avg,
        temperature_chip: Vec::new(), // Will be populated from detailed stats
        temperature_pcb: Vec::new(),
        fan_speeds: Vec::new(),
        uptime: summary.elapsed.unwrap_or(0),
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

#[cfg(test)]
mod tests {
    use super::*;
    
    #[test]
    fn test_parse_hashrate_string() {
        assert_eq!(parse_hashrate_string("13.5T").unwrap(), 13.5);
        assert_eq!(parse_hashrate_string("100G").unwrap(), 0.1);
        assert_eq!(parse_hashrate_string("1000G").unwrap(), 1.0);
    }
}
