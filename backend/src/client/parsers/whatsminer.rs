use super::MinerResponseParser;
use crate::client::{SummaryData, send_command, parse_hashrate_string, parse_pools_data, lookup_mac_address};
use crate::core::{MinerStats, Result, MinerError};
use async_trait::async_trait;
use serde::Deserialize;

pub struct WhatsminerParser;

#[derive(Debug, Deserialize)]
struct DevDetailsResponse {
    #[serde(rename = "DEVDETAILS")]
    devdetails: Option<Vec<DevDetails>>,
}

#[derive(Debug, Deserialize)]
struct DevDetails {
    #[serde(rename = "Model")]
    model: Option<String>,
}

#[async_trait]
impl MinerResponseParser for WhatsminerParser {
    fn parse_summary(&self, summary: &SummaryData) -> Result<MinerStats> {
        // Whatsminer: MHS 5s (MH/s) -> TH/s
        let hashrate_rt = if let Some(mhs) = summary.mhs_5s {
            mhs / 1_000_000.0
        } else if let Some(hs) = &summary.hs_5s {
            // "13.5T" or "13500G"
            parse_hashrate_string(hs)?
        } else {
             // Fallback
             0.0
        };

        let hashrate_avg = summary.mhs_av.map(|m| m / 1_000_000.0).unwrap_or(hashrate_rt);

        // Extract Temps from Summary (Whatsminer specific fields)
        // "Chip Temp Min": 58.0, "Chip Temp Max": 78.28, "Chip Temp Avg": 70.06
        let mut temp_outlet_min = Vec::new();
        let mut temp_outlet_max = Vec::new();
        
        // We'll treat "Chip Temp" as Outlet/Chip temp
        if let Some(min) = summary.chip_temp_min {
            temp_outlet_min.push(Some(min));
        }
        if let Some(max) = summary.chip_temp_max {
            temp_outlet_max.push(Some(max));
        }

        // Whatsminer doesn't usually give PCB temps in summary in the same way, 
        // or they might be "Env Temp"? Let's ignore PCB temps for now if not present.
        let mut temp_inlet_min = Vec::new();
        let mut temp_inlet_max = Vec::new();

        if let Some(temp) = summary.temperature {
            temp_inlet_min.push(Some(temp));
            temp_inlet_max.push(Some(temp));
        }

        // Extract Fans from Summary
        // "Fan Speed In": 3810, "Fan Speed Out": 3780
        let mut fan_speeds = Vec::new();
        if let Some(in_speed) = summary.fan_speed_in {
            fan_speeds.push(Some(in_speed as u32));
        }
        if let Some(out_speed) = summary.fan_speed_out {
            fan_speeds.push(Some(out_speed as u32));
        }

        // Extract Firmware
        let firmware = summary.firmware_version.clone().map(|s| s.replace("'", "")); // Remove quotes

        Ok(MinerStats {
            hashrate_rt,
            hashrate_avg,
            temp_outlet_min,
            temp_outlet_max,
            temp_inlet_min,
            temp_inlet_max,
            fan_speeds,
            uptime: summary.elapsed.unwrap_or(0),
            pool1: None,
            worker1: None,
            pool2: None,
            worker2: None,
            pool3: None,
            worker3: None,
            model: None, // Will be fetched in fetch_details
            firmware,
            software: None, // Could be "Description" from status?
            hardware: None,
            mac_address: None, // Will be fetched
        })
    }

    async fn fetch_details(&self, ip: &str, port: u16, timeout_ms: u64, stats: &mut MinerStats) -> Result<()> {
        // 1. Fetch Model via devdetails
        if let Ok(response) = send_command(ip, port, "devdetails", timeout_ms).await {
            if let Some(clean) = crate::utils::extract_clean_json(&response) {
                 if let Ok(details) = serde_json::from_str::<DevDetailsResponse>(&clean) {
                     if let Some(devs) = details.devdetails {
                         if let Some(first) = devs.first() {
                                 stats.model = first.model.clone().map(|m| format!("WhatsMiner - {}", m));
                         }
                     }
                 }
            }
        }

        // 2. Fetch Pools
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

        // 3. MAC Address
        stats.mac_address = lookup_mac_address(ip).await;

        Ok(())
    }
}
