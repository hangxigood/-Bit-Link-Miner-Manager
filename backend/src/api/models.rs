// Re-export core models - they already have Serialize/Deserialize
pub use crate::core::{Miner, MinerStats, MinerStatus};

/// Command to execute on miners
#[derive(Debug, Clone)]
pub enum MinerCommand {
    Reboot,
    BlinkLed,
}

/// Result of a batch command execution
#[derive(Debug, Clone)]
pub struct CommandResult {
    pub ip: String,
    pub success: bool,
    pub error: Option<String>,
}
