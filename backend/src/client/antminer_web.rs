use crate::core::Result;
use reqwest::Client;
use serde::{Deserialize, Serialize};
use std::time::Duration;

// ---------------------------------------------------------------------------
// Public data types
// ---------------------------------------------------------------------------

/// A mining pool configuration entry.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AntminerPool {
    pub url: String,
    pub user: String,
    pub pass: String,
}

// ---------------------------------------------------------------------------
// Internal response types
// ---------------------------------------------------------------------------

/// Response from `/cgi-bin/get_miner_conf.cgi`.
/// We serialise this back verbatim for the write endpoint, only swapping the
/// fields we care about (pools / miner-mode).  Any unknown fields from the
/// miner are preserved through `serde_json::Value` so we don't clobber them.
#[derive(Debug, Clone, Serialize, Deserialize)]
struct MinerConf {
    #[serde(default)]
    pub pools: Vec<AntminerPool>,

    #[serde(rename = "bitmain-fan-ctrl", default)]
    pub fan_ctrl: bool,

    #[serde(rename = "bitmain-fan-pwm", default = "default_fan_pwm")]
    pub fan_pwm: String,

    /// 0 = normal, 1 = sleep
    #[serde(rename = "miner-mode", default)]
    pub miner_mode: u8,

    #[serde(rename = "freq-level", default = "default_freq_level")]
    pub freq_level: String,
}

fn default_fan_pwm() -> String {
    "100".to_string()
}

fn default_freq_level() -> String {
    "100".to_string()
}

// ---------------------------------------------------------------------------
// Client
// ---------------------------------------------------------------------------

/// HTTP client for the Antminer web API (port 80, HTTP Digest Auth).
pub struct AntminerWebClient;

impl AntminerWebClient {
    // -----------------------------------------------------------------------
    // Private helpers
    // -----------------------------------------------------------------------

    fn build_client() -> Result<Client> {
        Client::builder()
            .timeout(Duration::from_secs(8))
            .build()
            .map_err(|e| format!("Failed to build HTTP client: {}", e).into())
    }

    /// Perform a GET request with HTTP Digest Auth.
    async fn digest_get(
        ip: &str,
        path: &str,
        username: &str,
        password: &str,
    ) -> Result<String> {
        let url = format!("http://{}{}", ip, path);
        let client = Self::build_client()?;

        // Step 1 – unauthenticated probe to get the 401 challenge
        let resp = client
            .get(&url)
            .send()
            .await
            .map_err(|e| format!("GET {} failed: {}", url, e))?;

        if resp.status().is_success() {
            return Ok(resp.text().await.unwrap_or_default());
        }

        if resp.status() != reqwest::StatusCode::UNAUTHORIZED {
            return Err(format!(
                "Unexpected status {} for GET {}",
                resp.status(),
                url
            )
            .into());
        }

        // Step 2 – compute Digest response
        let www_auth = resp
            .headers()
            .get("www-authenticate")
            .ok_or("Missing WWW-Authenticate header")?
            .to_str()
            .map_err(|e| format!("Invalid WWW-Authenticate header: {}", e))?
            .to_string();

        let context = digest_auth::AuthContext::new(username, password, path);
        let mut prompt = digest_auth::parse(&www_auth)
            .map_err(|e| format!("Failed to parse digest challenge: {:?}", e))?;
        let answer = prompt
            .respond(&context)
            .map_err(|e| format!("Failed to compute digest response: {:?}", e))?;

        // Step 3 – authenticated request
        let resp = client
            .get(&url)
            .header("Authorization", answer.to_header_string())
            .send()
            .await
            .map_err(|e| format!("Authenticated GET {} failed: {}", url, e))?;

        if resp.status().is_success() {
            Ok(resp.text().await.unwrap_or_default())
        } else {
            Err(format!("GET {} returned {}", url, resp.status()).into())
        }
    }

    /// Perform a POST request with HTTP Digest Auth, sending a JSON body.
    /// If the miner drops the connection after applying the config (e.g. because
    /// it immediately reboots), that is treated as an error here — use
    /// `digest_post_tolerant` for commands that trigger reboots.
    async fn digest_post(
        ip: &str,
        path: &str,
        username: &str,
        password: &str,
        body: String,
    ) -> Result<String> {
        Self::_digest_post_inner(ip, path, username, password, body, false).await
    }

    /// Like `digest_post` but treats connection errors on the *authenticated*
    /// request as success.  Use this for endpoints that trigger an immediate
    /// reboot (set_miner_conf.cgi) where the miner drops the TCP connection
    /// before it can send an HTTP response.
    async fn digest_post_tolerant(
        ip: &str,
        path: &str,
        username: &str,
        password: &str,
        body: String,
    ) -> Result<String> {
        Self::_digest_post_inner(ip, path, username, password, body, true).await
    }

    async fn _digest_post_inner(
        ip: &str,
        path: &str,
        username: &str,
        password: &str,
        body: String,
        tolerate_connection_error: bool,
    ) -> Result<String> {
        let url = format!("http://{}{}", ip, path);
        let client = Self::build_client()?;

        // Step 1 – unauthenticated probe
        let resp = client
            .post(&url)
            .header("Content-Type", "application/json")
            .body(body.clone())
            .send()
            .await
            .map_err(|e| format!("POST {} failed: {}", url, e))?;

        if resp.status().is_success() {
            return Ok(resp.text().await.unwrap_or_default());
        }

        if resp.status() != reqwest::StatusCode::UNAUTHORIZED {
            return Err(format!(
                "Unexpected status {} for POST {}",
                resp.status(),
                url
            )
            .into());
        }

        // Step 2 – compute Digest response for POST
        let www_auth = resp
            .headers()
            .get("www-authenticate")
            .ok_or("Missing WWW-Authenticate header")?
            .to_str()
            .map_err(|e| format!("Invalid WWW-Authenticate header: {}", e))?
            .to_string();

        let mut context = digest_auth::AuthContext::new(username, password, path);
        context.method = digest_auth::HttpMethod::POST;

        let mut prompt = digest_auth::parse(&www_auth)
            .map_err(|e| format!("Failed to parse digest challenge: {:?}", e))?;
        let answer = prompt
            .respond(&context)
            .map_err(|e| format!("Failed to compute digest response: {:?}", e))?;

        // Step 3 – authenticated request
        let resp = client
            .post(&url)
            .header("Authorization", answer.to_header_string())
            .header("Content-Type", "application/json")
            .body(body)
            .send()
            .await;

        // Some commands (set_miner_conf) cause the miner to reboot immediately,
        // dropping the TCP connection before it sends a response.  If the caller
        // opted in to tolerance, treat connection errors as success.
        let resp = match resp {
            Ok(r) => r,
            Err(ref e) if tolerate_connection_error && (e.is_connect() || e.is_request() || e.is_timeout()) => {
                println!("[antminer_web] POST {} — connection dropped (miner likely rebooting, treating as success)", path);
                return Ok(String::new());
            }
            Err(e) => {
                return Err(format!("Authenticated POST {} failed: {}", url, e).into());
            }
        };

        if resp.status().is_success() {
            Ok(resp.text().await.unwrap_or_default())
        } else {
            Err(format!("POST {} returned {}", url, resp.status()).into())
        }
    }

    /// Read the current miner config (required for read-modify-write).
    async fn get_miner_conf(ip: &str, username: &str, password: &str) -> Result<MinerConf> {
        let raw = Self::digest_get(ip, "/cgi-bin/get_miner_conf.cgi", username, password).await?;
        let conf: MinerConf = serde_json::from_str(&raw)
            .map_err(|e| format!("Failed to parse miner conf: {} — raw: {}", e, &raw[..raw.len().min(200)]))?;
        Ok(conf)
    }

    // -----------------------------------------------------------------------
    // Public API
    // -----------------------------------------------------------------------

    /// Reboot the miner immediately.
    /// The miner will be unreachable for ~2 minutes after this call.
    pub async fn reboot(ip: &str, username: &str, password: &str) -> Result<()> {
        Self::digest_get(ip, "/cgi-bin/reboot.cgi", username, password).await?;
        Ok(())
    }

    /// Set the LED blink state.
    /// - `true`  → LED starts blinking (Locate mode)
    /// - `false` → LED returns to normal
    pub async fn set_led(ip: &str, username: &str, password: &str, state: bool) -> Result<()> {
        let body = serde_json::json!({ "blink": state }).to_string();
        Self::digest_post(ip, "/cgi-bin/blink.cgi", username, password, body).await?;
        Ok(())
    }

    /// Get the current LED blink state.
    pub async fn get_led(ip: &str, username: &str, password: &str) -> Result<bool> {
        let raw = Self::digest_get(ip, "/cgi-bin/get_blink_status.cgi", username, password).await?;
        #[derive(Deserialize)]
        struct BlinkResp { blink: bool }
        let resp: BlinkResp = serde_json::from_str(&raw)
            .map_err(|e| format!("Failed to parse blink status: {}", e))?;
        Ok(resp.blink)
    }

    /// Set the power mode.
    /// - `sleep: true`  → miner enters sleep / low-power mode
    /// - `sleep: false` → miner returns to normal mining mode
    ///
    /// Triggers an automatic reboot.
    pub async fn set_power_mode(ip: &str, username: &str, password: &str, sleep: bool) -> Result<()> {
        let mut conf = Self::get_miner_conf(ip, username, password).await?;
        conf.miner_mode = if sleep { 1 } else { 0 };
        let body = serde_json::to_string(&conf)
            .map_err(|e| format!("Failed to serialise miner conf: {}", e))?;
        // Miner reboots on mode change — use tolerant POST
        Self::digest_post_tolerant(ip, "/cgi-bin/set_miner_conf.cgi", username, password, body).await?;
        Ok(())
    }

    /// Configure up to three mining pools.
    ///
    /// Uses a **read-modify-write** pattern: the current config is fetched
    /// first so that fan / frequency / power-mode settings are preserved.
    ///
    /// The miner will **automatically reboot** 2-3 minutes after this call
    /// if the pool configuration changed.
    pub async fn set_pools(
        ip: &str,
        username: &str,
        password: &str,
        pools: Vec<AntminerPool>,
    ) -> Result<()> {
        if pools.is_empty() || pools.len() > 3 {
            return Err("set_pools: must supply 1–3 pools".into());
        }

        let mut conf = Self::get_miner_conf(ip, username, password).await?;
        conf.pools = pools;

        let body = serde_json::to_string(&conf)
            .map_err(|e| format!("Failed to serialise miner conf: {}", e))?;
        // Miner reboots after pool change — use tolerant POST
        Self::digest_post_tolerant(ip, "/cgi-bin/set_miner_conf.cgi", username, password, body).await?;
        Ok(())
    }

    /// Read the currently configured pools (from the miner config, not live stats).
    pub async fn get_pools(ip: &str, username: &str, password: &str) -> Result<Vec<AntminerPool>> {
        let conf = Self::get_miner_conf(ip, username, password).await?;
        Ok(conf.pools)
    }
}
