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
    // Outlet (chip) temperatures for 3 hash boards (°C)
    pub temp_outlet_min: Vec<Option<f64>>,
    pub temp_outlet_max: Vec<Option<f64>>,
    // Inlet (PCB) temperatures for 3 hash boards (°C)
    pub temp_inlet_min: Vec<Option<f64>>,
    pub temp_inlet_max: Vec<Option<f64>>,
    pub fan_speeds: Vec<Option<u32>>,   // Fan speeds for 4 fans (RPM)
    pub uptime: u64,                    // Uptime in seconds
    
    // Detailed Info
    pub pool1: Option<String>,
    pub worker1: Option<String>,
    pub pool2: Option<String>,
    pub worker2: Option<String>,
    pub pool3: Option<String>,
    pub worker3: Option<String>,
    
    pub model: Option<String>,       // Miner model (e.g., "Antminer S19")
    pub firmware: Option<String>,    // CompileTime formatted YYYYMMDD
    pub software: Option<String>,    // "Bmminer X.X.X"
    pub hardware: Option<String>,    // "uart_trans.X.X"
    pub mac_address: Option<String>, // Keep this if we find it later
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
            temp_outlet_min: vec![None, None, None],
            temp_outlet_max: vec![None, None, None],
            temp_inlet_min: vec![None, None, None],
            temp_inlet_max: vec![None, None, None],
            fan_speeds: vec![None, None, None, None],
            uptime: 0,
            pool1: None,
            worker1: None,
            pool2: None,
            worker2: None,
            pool3: None,
            worker3: None,
            model: None,
            firmware: None,
            software: None,
            hardware: None,
            mac_address: None,
        }
    }
}
