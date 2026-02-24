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

/// Result of a batch command execution
#[derive(Debug, Clone)]
pub struct CommandResult {
    pub ip: String,
    pub success: bool,
    pub error: Option<String>,
}
