use crate::api::models::{MinerCommand, CommandResult};
use crate::core::MinerCredentials;


/// Execute a command on multiple miners
/// Returns results for each IP (success/failure)
pub async fn execute_batch_command(
    target_ips: Vec<String>,
    command: MinerCommand,
    credentials: Option<MinerCredentials>,
) -> Vec<CommandResult> {
    let mut results = Vec::new();
    
    // Use provided credentials or default to root/root
    let creds = credentials.unwrap_or_default();
    
    // Execute commands concurrently
    let tasks: Vec<_> = target_ips
        .into_iter()
        .map(|ip| {
            let cmd = command.clone();
            let creds_clone = creds.clone();
            tokio::spawn(async move {
                execute_single_command(ip, cmd, creds_clone).await
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

/// Execute a command on a single miner
async fn execute_single_command(ip: String, command: MinerCommand, credentials: MinerCredentials) -> CommandResult {
    match command {
        MinerCommand::Reboot => {
            // Reboot uses the HTTP web interface with Digest Auth
            // because the CGMiner API rejects privileged commands
            match reboot_via_http(&ip, &credentials.username, &credentials.password).await {
                Ok(_) => CommandResult {
                    ip,
                    success: true,
                    error: None,
                },
                Err(e) => CommandResult {
                    ip,
                    success: false,
                    error: Some(e),
                },
            }
        }
        MinerCommand::BlinkLed => {
            // Modern Antminers use HTTP API for blink control
            match blink_led_via_http(&ip, &credentials.username, &credentials.password, true).await {
                Ok(_) => CommandResult {
                    ip,
                    success: true,
                    error: None,
                },
                Err(e) => CommandResult {
                    ip,
                    success: false,
                    error: Some(e),
                },
            }
        }
        MinerCommand::StopBlink => {
            // Modern Antminers use HTTP API for blink control
            match blink_led_via_http(&ip, &credentials.username, &credentials.password, false).await {
                Ok(_) => CommandResult {
                    ip,
                    success: true,
                    error: None,
                },
                Err(e) => CommandResult {
                    ip,
                    success: false,
                    error: Some(e),
                },
            }
        }
    }
}

/// Reboot a miner via its HTTP web interface using Digest Authentication.
/// Antminer endpoint: GET /cgi-bin/reboot.cgi
/// Auth: HTTP Digest (realm "antMiner Configuration")
async fn reboot_via_http(ip: &str, username: &str, password: &str) -> std::result::Result<(), String> {
    let url = format!("http://{}/cgi-bin/reboot.cgi", ip);
    let client = reqwest::Client::new();

    // Step 1: Send initial request to get the WWW-Authenticate challenge
    let resp = client
        .get(&url)
        .timeout(std::time::Duration::from_secs(5))
        .send()
        .await
        .map_err(|e| format!("HTTP request failed: {}", e))?;

    if resp.status() != reqwest::StatusCode::UNAUTHORIZED {
        // If the miner doesn't challenge us (maybe no auth required?), check if it's a success
        if resp.status().is_success() {
            return Ok(());
        }
        return Err(format!("Unexpected status: {}", resp.status()));
    }

    // Step 2: Extract the WWW-Authenticate header
    let www_auth = resp
        .headers()
        .get("www-authenticate")
        .ok_or("Missing WWW-Authenticate header")?
        .to_str()
        .map_err(|e| format!("Invalid WWW-Authenticate header: {}", e))?
        .to_string();

    // Step 3: Compute the Digest Auth response
    let context = digest_auth::AuthContext::new(username, password, "/cgi-bin/reboot.cgi");
    let mut prompt = digest_auth::parse(&www_auth)
        .map_err(|e| format!("Failed to parse digest challenge: {:?}", e))?;
    let answer = prompt
        .respond(&context)
        .map_err(|e| format!("Failed to compute digest response: {:?}", e))?;

    // Step 4: Send the authenticated request
    let auth_header = answer.to_header_string();
    let resp = client
        .get(&url)
        .header("Authorization", auth_header)
        .timeout(std::time::Duration::from_secs(5))
        .send()
        .await
        .map_err(|e| format!("Authenticated request failed: {}", e))?;

    if resp.status().is_success() {
        Ok(())
    } else {
        Err(format!(
            "Reboot request failed with status: {} (check credentials)",
            resp.status()
        ))
    }
}

/// Blink LED via HTTP (POST /cgi-bin/blink.cgi)
/// state: true for blink, false for stop
async fn blink_led_via_http(ip: &str, username: &str, password: &str, state: bool) -> std::result::Result<(), String> {
    let url = format!("http://{}/cgi-bin/blink.cgi", ip);
    let client = reqwest::Client::new();
    // Payload MUST be exactly `{"blink": true}` or `{"blink": false}`
    let payload = format!(r#"{{"blink": {}}}"#, state);

    // Step 1: Send initial request (likely to fail with 401, but might work)
    let resp = client
        .post(&url)
        .header("Content-Type", "text/plain;charset=UTF-8")
        .header("X-Requested-With", "XMLHttpRequest")
        .header("Referer", format!("http://{}/", ip))
        .body(payload.clone())
        .timeout(std::time::Duration::from_secs(5))
        .send()
        .await
        .map_err(|e| format!("HTTP request failed: {}", e))?;

    if resp.status().is_success() {
        return Ok(());
    }

    if resp.status() != reqwest::StatusCode::UNAUTHORIZED {
        return Err(format!("Unexpected status: {}", resp.status()));
    }

    // Step 2: Extract WWW-Authenticate header
    let www_auth = resp
        .headers()
        .get("www-authenticate")
        .ok_or("Missing WWW-Authenticate header")?
        .to_str()
        .map_err(|e| format!("Invalid WWW-Authenticate header: {}", e))?
        .to_string();

    // Step 3: Compute Digest Auth
    let mut context = digest_auth::AuthContext::new(username, password, "/cgi-bin/blink.cgi");
    // Set method to POST (default is GET)
    context.method = digest_auth::HttpMethod::POST;

    let mut prompt = digest_auth::parse(&www_auth)
        .map_err(|e| format!("Failed to parse digest challenge: {:?}", e))?;
    let answer = prompt
        .respond(&context) // digest_auth 0.3 uses context method
        .map_err(|e| format!("Failed to compute digest response: {:?}", e))?;

    // Step 4: Send authenticated request
    let auth_header = answer.to_header_string();
    let resp = client
        .post(&url)
        .header("Authorization", auth_header)
        .header("Content-Type", "text/plain;charset=UTF-8")
        .header("X-Requested-With", "XMLHttpRequest")
        .header("Referer", format!("http://{}/", ip))
        .body(payload.clone())
        .timeout(std::time::Duration::from_secs(5))
        .send()
        .await
        .map_err(|e| format!("Authenticated request failed: {}", e))?;

    if resp.status().is_success() {
        Ok(())
    } else {
        Err(format!("Blink request failed with status: {}", resp.status()))
    }
}

/// Test connection to a single miner
pub fn test_connection(ip: String) -> String {
    format!("Testing connection to {}", ip)
}
