// Re-export core models - they already have Serialize/Deserialize
pub use crate::core::{Miner, MinerStats, MinerStatus};

/// A mining pool configuration entry.
/// This is the FRB-visible version of `AntminerPool`.
#[derive(Debug, Clone)]
pub struct PoolConfig {
    pub url: String,
    pub worker: String,
    pub password: String,
}

/// Command to execute on miners
#[derive(Debug, Clone)]
pub enum MinerCommand {
    Reboot,
    BlinkLed,
    StopBlink,
    SetPools { pools: Vec<PoolConfig> },
}

/// Power mode for a miner.
///
/// Antminer miner-mode values (field `miner-mode` in `set_miner_conf.cgi`):
///   - Normal → 0
///   - Sleep  → 1   (miner stops hashing, stays reachable)
///   - Lpm    → 3   (Low Power Mode — reduced hashrate; not all firmware supports this)
///
/// Whatsminer (LuCI `miner_type` field):
///   - Normal → "Normal"
///   - Lpm    → "Low"
///   - Sleep  → "Low"  (no dedicated sleep mode; falls back to Low)
#[derive(Debug, Clone, Copy)]
pub enum PowerMode {
    Normal,
    Lpm,
    Sleep,
}

/// Result of a batch command execution
#[derive(Debug, Clone)]
pub struct CommandResult {
    pub ip: String,
    pub success: bool,
    pub error: Option<String>,
}
