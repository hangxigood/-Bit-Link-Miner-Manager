use crate::api::models::{MinerCommand, CommandResult};

use crate::core::MinerCredentials;
use crate::client::{
    get_summary,
    antminer_web::AntminerWebClient,
    whatsminer_web::WhatsminerWebClient,
};


/// Execute a command on multiple miners in parallel.
/// Returns results for each IP (success/failure).
pub async fn execute_batch_command(
    target_ips: Vec<String>,
    command: MinerCommand,
    credentials: Option<MinerCredentials>,
) -> Vec<CommandResult> {
    let mut results = Vec::new();
    
    let settings = AppSettings::load();
    let antminer_creds = settings.antminer_credentials;
    let whatsminer_creds = settings.whatsminer_credentials;
    
    // Execute commands concurrently
    let tasks: Vec<_> = target_ips
        .into_iter()
        .map(|ip| {
            let cmd = command.clone();
            let a_creds = antminer_creds.clone();
            let w_creds = whatsminer_creds.clone();
            
            tokio::spawn(async move {
                execute_single_command(ip, cmd, a_creds, w_creds).await
            })
        })
        .collect();
    
    // Wait for all tasks to complete
    for task in tasks {
        if let Ok(result) = task.await {
            results.push(result);
        }
    }
    
    results
}

use crate::api::settings::get_app_settings;
use crate::core::config::AppSettings;

/// Execute a command on a single miner.
async fn execute_single_command(
    ip: String,
    command: MinerCommand,
    antminer_creds: MinerCredentials,
    whatsminer_creds: MinerCredentials,
) -> CommandResult {
    println!("Executing command {:?} for {}...", command, ip);
    
    // Detect miner type by querying CGMiner summary
    let is_whatsminer = if let Ok(stats) = get_summary(&ip, 4028, 500).await {
         let model = stats.model.as_ref().map(|m| m.to_lowercase()).unwrap_or_default();
         let firmware = stats.firmware.as_ref().map(|f| f.to_lowercase()).unwrap_or_default();
         println!("Miner Detection - IP: {}, Model: {}, Firmware: {}", ip, model, firmware);
         model.contains("whatsminer") || firmware.contains("whatsminer")
    } else {
        println!("Miner Detection - Failed to get summary for {}. Defaulting to Antminer.", ip);
        false
    };

    if is_whatsminer {
        println!("Detected Whatsminer for {}", ip);
        execute_whatsminer_command(ip, command, whatsminer_creds).await
    } else {
        println!("Detected Antminer for {}", ip);
        execute_antminer_command(ip, command, antminer_creds).await
    }
}

// ---------------------------------------------------------------------------
// Antminer command dispatch
// ---------------------------------------------------------------------------

async fn execute_antminer_command(
    ip: String,
    command: MinerCommand,
    creds: MinerCredentials,
) -> CommandResult {
    let (user, pass) = (creds.username.as_str(), creds.password.as_str());

    match command {
        MinerCommand::Reboot => {
            match AntminerWebClient::reboot(&ip, user, pass).await {
                Ok(_) => {
                    println!("Antminer reboot SUCCESS for {}", ip);
                    CommandResult { ip, success: true, error: None }
                }
                Err(e) => {
                    println!("Antminer reboot FAILED for {}: {}", ip, e);
                    CommandResult { ip, success: false, error: Some(e.to_string()) }
                }
            }
        }

        MinerCommand::BlinkLed => {
            match AntminerWebClient::set_led(&ip, user, pass, true).await {
                Ok(_) => CommandResult { ip, success: true, error: None },
                Err(e) => CommandResult { ip, success: false, error: Some(e.to_string()) },
            }
        }

        MinerCommand::StopBlink => {
            match AntminerWebClient::set_led(&ip, user, pass, false).await {
                Ok(_) => CommandResult { ip, success: true, error: None },
                Err(e) => CommandResult { ip, success: false, error: Some(e.to_string()) },
            }
        }

        MinerCommand::SetPools { pools } => {
            use crate::client::antminer_web::AntminerPool;
            let antminer_pools: Vec<AntminerPool> = pools
                .into_iter()
                .map(|p| AntminerPool { url: p.url, user: p.worker, pass: p.password })
                .collect();
            match AntminerWebClient::set_pools(&ip, user, pass, antminer_pools).await {
                Ok(_) => {
                    println!("Antminer set_pools SUCCESS for {} (will reboot automatically)", ip);
                    CommandResult { ip, success: true, error: None }
                }
                Err(e) => {
                    println!("Antminer set_pools FAILED for {}: {}", ip, e);
                    CommandResult { ip, success: false, error: Some(e.to_string()) }
                }
            }
        }
    }
}

// ---------------------------------------------------------------------------
// Whatsminer command dispatch
// ---------------------------------------------------------------------------

async fn execute_whatsminer_command(
    ip: String,
    command: MinerCommand,
    creds: MinerCredentials,
) -> CommandResult {
    let (user, pass) = (creds.username.as_str(), creds.password.as_str());

    match command {
        MinerCommand::Reboot => {
            match WhatsminerWebClient::reboot(&ip, user, pass).await {
                Ok(_) => {
                    println!("Whatsminer reboot SUCCESS for {}", ip);
                    CommandResult { ip, success: true, error: None }
                }
                Err(e) => {
                    println!("Whatsminer reboot FAILED for {}: {}", ip, e);
                    CommandResult { ip, success: false, error: Some(e.to_string()) }
                }
            }
        }

        MinerCommand::BlinkLed => {
            match WhatsminerWebClient::blink_led(&ip, user, pass, true).await {
                Ok(_) => CommandResult { ip, success: true, error: None },
                Err(e) => CommandResult { ip, success: false, error: Some(e.to_string()) },
            }
        }

        MinerCommand::StopBlink => {
            match WhatsminerWebClient::blink_led(&ip, user, pass, false).await {
                Ok(_) => CommandResult { ip, success: true, error: None },
                Err(e) => CommandResult { ip, success: false, error: Some(e.to_string()) },
            }
        }

        MinerCommand::SetPools { pools } => {
            use crate::client::whatsminer_web::WhatsminerPool;
            let wm_pools: Vec<WhatsminerPool> = pools
                .into_iter()
                .map(|p| WhatsminerPool { url: p.url, worker: p.worker, password: p.password })
                .collect();
            match WhatsminerWebClient::set_pools(&ip, user, pass, wm_pools).await {
                Ok(_) => {
                    println!("Whatsminer set_pools SUCCESS for {} (daemon restarted)", ip);
                    CommandResult { ip, success: true, error: None }
                }
                Err(e) => {
                    println!("Whatsminer set_pools FAILED for {}: {}", ip, e);
                    CommandResult { ip, success: false, error: Some(e.to_string()) }
                }
            }
        }
    }
}

/// Test connection to a single miner
pub fn test_connection(ip: String) -> String {
    format!("Testing connection to {}", ip)
}

/// Set mining pools on a single Antminer via its HTTP API.
/// Reads the current config first to preserve fan/frequency settings.
/// The miner will automatically reboot ~2 minutes after applying the change.
///
/// `pools` must have 1–3 entries.
pub async fn set_miner_pools(ip: String, pools: Vec<crate::api::models::PoolConfig>) -> CommandResult {
    use crate::client::antminer_web::{AntminerWebClient, AntminerPool};
    let settings = AppSettings::load();
    let creds = settings.antminer_credentials;

    let antminer_pools: Vec<AntminerPool> = pools
        .into_iter()
        .map(|p| AntminerPool { url: p.url, user: p.worker, pass: p.password })
        .collect();

    match AntminerWebClient::set_pools(&ip, &creds.username, &creds.password, antminer_pools).await {
        Ok(_) => CommandResult { ip, success: true, error: None },
        Err(e) => CommandResult { ip, success: false, error: Some(e.to_string()) },
    }
}

/// Read the currently configured pools from a single Antminer.
pub async fn get_miner_pools(ip: String) -> Vec<crate::api::models::PoolConfig> {
    use crate::client::antminer_web::AntminerWebClient;
    let settings = AppSettings::load();
    let creds = settings.antminer_credentials;

    match AntminerWebClient::get_pools(&ip, &creds.username, &creds.password).await {
        Ok(pools) => pools
            .into_iter()
            .map(|p| crate::api::models::PoolConfig { url: p.url, worker: p.user, password: p.pass })
            .collect(),
        Err(_) => Vec::new(),
    }
}

/// Set the power mode on a miner. Detects Whatsminer vs Antminer automatically.
/// - `sleep = true`  → Low Power Mode
/// - `sleep = false` → Normal mode
pub async fn set_miner_power_mode(ip: String, sleep: bool) -> CommandResult {
    use crate::client::antminer_web::AntminerWebClient;
    use crate::client::whatsminer_web::WhatsminerWebClient;
    let settings = AppSettings::load();

    // Detect miner type via CGMiner summary (same logic as execute_single_command)
    let is_whatsminer = if let Ok(stats) = crate::client::get_summary(&ip, 4028, 500).await {
        let model = stats.model.as_ref().map(|m| m.to_lowercase()).unwrap_or_default();
        let firmware = stats.firmware.as_ref().map(|f| f.to_lowercase()).unwrap_or_default();
        model.contains("whatsminer") || firmware.contains("whatsminer")
    } else {
        false
    };

    if is_whatsminer {
        let creds = settings.whatsminer_credentials;
        // Map sleep flag to Whatsminer LuCI `miner_type` field value
        let mode = if sleep { "Low" } else { "Normal" };
        match WhatsminerWebClient::set_power_mode(&ip, &creds.username, &creds.password, mode).await {
            Ok(_) => {
                println!("Whatsminer set_power_mode({}) SUCCESS for {}", mode, ip);
                CommandResult { ip, success: true, error: None }
            }
            Err(e) => {
                println!("Whatsminer set_power_mode FAILED for {}: {}", ip, e);
                CommandResult { ip, success: false, error: Some(e.to_string()) }
            }
        }
    } else {
        let creds = settings.antminer_credentials;
        match AntminerWebClient::set_power_mode(&ip, &creds.username, &creds.password, sleep).await {
            Ok(_) => {
                println!(
                    "Antminer set_power_mode({}) SUCCESS for {} (will reboot automatically)",
                    if sleep { "sleep" } else { "normal" }, ip
                );
                CommandResult { ip, success: true, error: None }
            }
            Err(e) => {
                println!("Antminer set_power_mode FAILED for {}: {}", ip, e);
                CommandResult { ip, success: false, error: Some(e.to_string()) }
            }
        }
    }
}

