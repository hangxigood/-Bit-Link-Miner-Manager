use crate::core::Result;
use reqwest::{Client, header};
use std::time::Duration;

/// Client for interacting with Whatsminer's LuCI web interface
pub struct WhatsminerWebClient;

impl WhatsminerWebClient {
    fn build_client() -> Result<Client> {
        let mut headers = header::HeaderMap::new();
        headers.insert("Accept", "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8".parse().unwrap());
        headers.insert("Accept-Language", "en-US,en;q=0.9".parse().unwrap());
        headers.insert("User-Agent", "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36".parse().unwrap());

        Client::builder()
            .timeout(Duration::from_secs(5))
            .danger_accept_invalid_certs(true)
            .default_headers(headers)
            .cookie_store(true)
            .build()
            .map_err(|e| format!("Failed to build client: {}", e).into())
    }

    /// Perform login and return the authenticated client (with cookies)
    async fn login_and_get_client(ip: &str, username: &str, password: &str) -> Result<Client> {
        let client = Self::build_client()?;
        // Some LuCI versions need a priming GET to set a session cookie even before login
        let params = [
            ("luci_username", username),
            ("luci_password", password),
        ];

        let login_url = format!("https://{}/cgi-bin/luci", ip);
        
        // 1. Prime (ignore result)
        let _ = client.get(&login_url).send().await;

        // 2. POST credentials
        let resp = client.post(&login_url)
            .form(&params)
            .send()
            .await
            .map_err(|e| format!("Login request failed: {}", e))?;

        // Check if we are redirected to dashboard or get a success
        if resp.status().is_success() || resp.status().is_redirection() {
             // We assume success if no connection error and status is OK/302.
             // (Debug script showed 200 OK after redirect to /cgi-bin/luci/)
             Ok(client)
        } else {
             Err(format!("Login failed with status: {}", resp.status()).into())
        }
    }

    /// Reboot the miner
    pub async fn reboot(ip: &str, username: &str, password: &str) -> Result<()> {
        let client = Self::login_and_get_client(ip, username, password).await?;
        let url = format!("https://{}/cgi-bin/luci/admin/status/cgminerstatus/restart", ip);

        let resp = client.get(&url)
            .send()
            .await
            .map_err(|e| format!("Reboot request failed: {}", e))?;

        if resp.status().is_success() || resp.status().is_redirection() {
            Ok(())
        } else {
             Err(format!("Reboot failed with status: {}", resp.status()).into())
        }
    }

    /// Blink LED (Locate)
    pub async fn blink_led(ip: &str, username: &str, password: &str, blink: bool) -> Result<()> {
         let client = Self::login_and_get_client(ip, username, password).await?;
        
        // Potential URLs based on common OpenWrt/LuCI patterns
        // We try them in order.
        let candidates = vec![
            format!("https://{}/cgi-bin/luci/admin/status/cgminerstatus/blink", ip),
            format!("https://{}/cgi-bin/luci/admin/system/led_blink", ip),
            format!("https://{}/cgi-bin/luci/admin/status/cgminerstatus/led", ip),
        ];
        
        if blink {
            for url in candidates {
                let resp = client.get(&url).send().await;
                if let Ok(r) = resp {
                    if r.status().is_success() {
                        return Ok(());
                    }
                }
            }
             Err("Locate failed: Could not find working endpoint (tried /blink, /led_blink, /led)".into())
        } else {
             // For stopping, we might need a different URL or just assume toggling is manual?
             // If we don't 'know' the stop URL, we might just return OK or try a stop candidate
             // Attempting off candidates
            let stop_candidates = vec![
                format!("https://{}/cgi-bin/luci/admin/status/cgminerstatus/blink_off", ip),
                format!("https://{}/cgi-bin/luci/admin/system/led_off", ip),
            ];
            for url in stop_candidates {
                let _ = client.get(&url).send().await;
            }
            Ok(())
        }
    }
}
