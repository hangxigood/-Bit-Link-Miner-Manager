use crate::core::{MinerStats, Result};
use crate::client::SummaryData;
use async_trait::async_trait;

pub mod antminer;
pub mod whatsminer;

pub use antminer::AntminerParser;
pub use whatsminer::WhatsminerParser;

#[async_trait]
pub trait MinerResponseParser: Send + Sync {
    /// Parse the summary data into a base MinerStats object
    fn parse_summary(&self, summary: &SummaryData) -> Result<MinerStats>;

    /// Fetch additional details (temps, fans, model, etc.) specific to the miner type
    async fn fetch_details(&self, ip: &str, port: u16, timeout_ms: u64, stats: &mut MinerStats) -> Result<()>;
}

pub enum MinerParser {
    Antminer(AntminerParser),
    Whatsminer(WhatsminerParser),
}

impl MinerParser {
    pub fn parse_summary(&self, summary: &SummaryData) -> Result<MinerStats> {
        match self {
            MinerParser::Antminer(p) => p.parse_summary(summary),
            MinerParser::Whatsminer(p) => p.parse_summary(summary),
        }
    }

    pub async fn fetch_details(&self, ip: &str, port: u16, timeout_ms: u64, stats: &mut MinerStats) -> Result<()> {
        match self {
            MinerParser::Antminer(p) => p.fetch_details(ip, port, timeout_ms, stats).await,
            MinerParser::Whatsminer(p) => p.fetch_details(ip, port, timeout_ms, stats).await,
        }
    }
}
