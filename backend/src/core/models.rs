use serde::{Deserialize, Serialize};

/// Represents a discovered miner on the network
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Miner {
    pub ip: String,
    pub model: Option<String>,
    pub status: MinerStatus,
    pub stats: MinerStats,
    pub last_updated: u64,
}

/// Performance metrics for a miner
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct MinerStats {
    pub hashrate_rt: f64,      // Real-time hashrate (TH/s)
    pub hashrate_avg: f64,     // Average hashrate (TH/s)
    pub temperature_chip: Vec<f64>,  // Chip temperatures (°C)
    pub temperature_pcb: Vec<f64>,   // PCB temperatures (°C)
    pub fan_speeds: Vec<u32>,        // Fan speeds (RPM)
    pub uptime: u64,                 // Uptime in seconds
}

/// Status of a miner
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub enum MinerStatus {
    Active,   // Responding + temp < 85°C + hashrate > 90% of expected
    Warning,  // Responding but temp >= 85°C OR hashrate < 90%
    Dead,     // Connection timeout or no response
    Scanning, // Initial discovery phase
}

impl Default for MinerStats {
    fn default() -> Self {
        Self {
            hashrate_rt: 0.0,
            hashrate_avg: 0.0,
            temperature_chip: Vec::new(),
            temperature_pcb: Vec::new(),
            fan_speeds: Vec::new(),
            uptime: 0,
        }
    }
}
