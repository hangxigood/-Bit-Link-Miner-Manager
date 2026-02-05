pub mod core;
pub mod client;

pub use core::{Miner, MinerStats, MinerStatus, MinerError, Result};
pub use client::{send_command, get_summary, DEFAULT_PORT, DEFAULT_TIMEOUT_MS};
