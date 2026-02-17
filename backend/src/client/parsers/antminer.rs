use super::MinerResponseParser;
use crate::client::{SummaryData, send_command, parse_hashrate_string, parse_stats_data, parse_pools_data, parse_version_data, lookup_mac_address, DEFAULT_TIMEOUT_MS};
use crate::core::{MinerStats, Result, MinerError};
use async_trait::async_trait;

pub struct AntminerParser;

#[async_trait]
impl MinerResponseParser for AntminerParser {
    fn parse_summary(&self, summary: &SummaryData) -> Result<MinerStats> {
        // Determine hashrate based on available fields (Antminer prefers GHS)
        let hashrate_avg = if let Some(mhs) = summary.mhs_av {
            mhs / 1_000_000.0
        } else if let Some(ghs) = summary.ghs_av {
            ghs / 1000.0
        } else {
            0.0
        };

        let hashrate_rt = if let Some(ghs_5s) = summary.ghs_5s {
            ghs_5s / 1000.0
        } else {
            hashrate_avg
        };

        Ok(MinerStats {
            hashrate_rt,
            hashrate_avg,
            temp_outlet_min: Vec::new(),
            temp_outlet_max: Vec::new(),
            temp_inlet_min: Vec::new(),
            temp_inlet_max: Vec::new(),
            fan_speeds: Vec::new(),
            uptime: summary.elapsed.unwrap_or(0),
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
        })
    }

    async fn fetch_details(&self, ip: &str, port: u16, timeout_ms: u64, stats: &mut MinerStats) -> Result<()> {
        // 1. Get Detailed Stats (Temps, Fans)
        if let Ok(stats_json) = send_command(ip, port, "stats", timeout_ms).await {
            if let Some(clean_json) = crate::utils::extract_clean_json(&stats_json) {
                let (outlet_min, outlet_max, inlet_min, inlet_max, fans) = parse_stats_data(&clean_json);
                stats.temp_outlet_min = outlet_min;
                stats.temp_outlet_max = outlet_max;
                stats.temp_inlet_min = inlet_min;
                stats.temp_inlet_max = inlet_max;
                stats.fan_speeds = fans;
            }
        }

        // 2. Get Pools (Active Pool/Worker)
        if let Ok(pools_json) = send_command(ip, port, "pools", timeout_ms).await {
            if let Some(clean_json) = crate::utils::extract_clean_json(&pools_json) {
                let (p1, w1, p2, w2, p3, w3) = parse_pools_data(&clean_json);
                stats.pool1 = p1;
                stats.worker1 = w1;
                stats.pool2 = p2;
                stats.worker2 = w2;
                stats.pool3 = p3;
                stats.worker3 = w3;
            }
        }

        // 3. Get Version (Hardware/Firmware/Model)
        if let Ok(version_json) = send_command(ip, port, "version", timeout_ms).await {
            if let Some(clean_json) = crate::utils::extract_clean_json(&version_json) {
                let (hw, fw, sw, model) = parse_version_data(&clean_json);
                stats.hardware = hw;
                stats.firmware = fw;
                stats.software = sw;
                stats.model = model;
            }
        }

        // 4. Get MAC Address
        stats.mac_address = lookup_mac_address(ip).await;

        Ok(())
    }
}
