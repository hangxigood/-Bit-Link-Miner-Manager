//! Whatsminer HTTPS LuCI Web Client
//!
//! Implements the exact same protocol used by BTCTools (reverse-engineered from
//! `src/lua/scripts/rebooter/WhatsMinerHttpsLuci.lua` and
//! `src/lua/scripts/configurator/WhatsMinerHttpsLuci.lua`).
//!
//! ## Protocol Flow
//!
//! ### 1. Login (`getSession`)
//! ```text
//! POST https://<ip>/cgi-bin/luci
//! Content-Type: application/x-www-form-urlencoded
//! Body: luci_username=admin&luci_password=<password>
//!
//! ← 302 redirect with Set-Cookie: sysauth=<session>
//! ```
//! Fallback: if login with password fails, retry with empty password.
//!
//! ### 2. Reboot
//! ```text
//! GET  /cgi-bin/luci/admin/system/reboot   (with session cookie)
//! ← 200 HTML containing: token:'<csrf_token>'
//!
//! POST /cgi-bin/luci/admin/system/reboot/call
//! Body: token=<csrf_token>
//! ← 200 OK
//! ```
//!
//! ### 3. Pool Configuration
//! ```text
//! GET  /cgi-bin/luci/admin/network/btminer   (try btminer first, then cgminer)
//! ← 200 HTML containing: name="token" value="<csrf_token>"
//!
//! POST /cgi-bin/luci/admin/network/btminer
//! Body: token=<t>&cbi.submit=1&cbi.apply=1&cbid.pools.default.coin_type=<coin>
//!       &cbid.pools.default.pool1url=<url>&cbid.pools.default.pool1user=<worker>&cbid.pools.default.pool1pw=<pw>
//!       &cbid.pools.default.pool2url=...  (repeat for pool2, pool3)
//! ← 200 OK
//!
//! GET  /cgi-bin/luci/admin/status/btminerstatus/restart   (restarts mining daemon)
//! ← 302 (redirect = success)
//! ```

use crate::core::Result;
use regex::Regex;
use reqwest::{Client, header};
use std::time::Duration;

// ─────────────────────────────────────────────────────────────────────────────
// Pool entry
// ─────────────────────────────────────────────────────────────────────────────

pub struct WhatsminerPool {
    pub url: String,
    pub worker: String,
    pub password: String,
}

// ─────────────────────────────────────────────────────────────────────────────
// WhatsminerWebClient
// ─────────────────────────────────────────────────────────────────────────────

pub struct WhatsminerWebClient;

impl WhatsminerWebClient {
    // ── Shared HTTP client ────────────────────────────────────────────────────

    fn build_client() -> Result<Client> {
        Client::builder()
            .timeout(Duration::from_secs(10))
            .danger_accept_invalid_certs(true) // Whatsminer uses self-signed certs
            .cookie_store(true)                // Essential: keep the LuCI session cookie
            .build()
            .map_err(|e| format!("Failed to build HTTP client: {}", e).into())
    }

    /// Build a client that does NOT follow redirects — needed for the login POST
    /// so we can capture the session cookie from the 302 Set-Cookie header.
    fn build_client_no_redirect() -> Result<Client> {
        Client::builder()
            .timeout(Duration::from_secs(10))
            .danger_accept_invalid_certs(true)
            .cookie_store(true)
            .redirect(reqwest::redirect::Policy::none())
            .build()
            .map_err(|e| format!("Failed to build no-redirect HTTP client: {}", e).into())
    }

    // ── Login → returns (client_with_session_cookie, session_ok) ─────────────

    /// POST to `/cgi-bin/luci` to obtain the LuCI session cookie.
    /// Whatsminer returns 302 on success. The cookie in the 302 `Set-Cookie` is
    /// the session token. We capture it with a no-redirect client, then switch
    /// to a normal following-client for subsequent requests.
    async fn login(ip: &str, username: &str, password: &str) -> Result<Client> {
        let login_url = format!("https://{}/cgi-bin/luci", ip);

        for pw in &[password, ""] {
            let client = Self::build_client_no_redirect()?;
            let params = [
                ("luci_username", username),
                ("luci_password", pw),
            ];

            let resp = client
                .post(&login_url)
                .header(header::CONTENT_TYPE, "application/x-www-form-urlencoded")
                .form(&params)
                .send()
                .await
                .map_err(|e| format!("Login POST to {} failed: {}", login_url, e))?;

            let code = resp.status().as_u16();
            eprintln!("[whatsminer] login({}) pw={:?} → HTTP {}", ip, if pw.is_empty() { "(empty)" } else { "(set)" }, code);

            // LuCI returns 302 on success. Accept 200 too (some firmware versions).
            if code == 302 || code == 200 {
                // The cookie_store on `client` now has the sysauth session cookie.
                // Return this same client for subsequent requests.
                return Ok(client);
            }
        }

        Err(format!(
            "LuCI login failed for {} — miner returned non-302/200 for both password and no-password attempts. \
            Check that HTTPS is enabled on port 443 and credentials are correct.",
            ip
        ).into())
    }

    // ── Extract CSRF token from Reboot page HTML ───────────────────────────────

    /// GET `/cgi-bin/luci/admin/system/reboot` and parse:
    /// `token:'<csrf_token>'`  or  `token:"<csrf_token>"`
    async fn get_reboot_token(client: &Client, ip: &str) -> Result<String> {
        let url = format!("https://{}/cgi-bin/luci/admin/system/reboot", ip);
        let resp = client
            .get(&url)
            .send()
            .await
            .map_err(|e| format!("GET reboot page failed: {}", e))?;

        if !resp.status().is_success() {
            return Err(format!("Reboot page returned HTTP {}", resp.status()).into());
        }

        let body = resp.text().await.map_err(|e| format!("Read body: {}", e))?;

        // BTCTools uses: `token:'([^']+)'` or `token:"([^"]+)"`
        let re = Regex::new(r#"token:\s*['"]([^'"]+)['"]"#).unwrap();
        if let Some(m) = re.captures(&body) {
            let token = m[1].trim().to_string();
            eprintln!("[whatsminer] reboot CSRF token: {}…", &token[..token.len().min(8)]);
            return Ok(token);
        }

        Err(format!("Could not find CSRF token in reboot page body for {}", ip).into())
    }

    // ── Extract CSRF token from Network/Pool config page ──────────────────────

    /// GET `/cgi-bin/luci/admin/network/<program>` and parse:
    /// `name="token" value="<csrf_token>"`
    /// Returns (token, program_name, current_coin_type)
    async fn get_config_token(client: &Client, ip: &str) -> Result<(String, String, String)> {
        // Try cgminer first (confirmed on M31SV10), then btminer (newer firmware)
        for program in &["cgminer", "btminer"] {
            let url = format!("https://{}/cgi-bin/luci/admin/network/{}", ip, program);
            let resp = client
                .get(&url)
                .send()
                .await
                .map_err(|e| format!("GET config page failed: {}", e))?;

            let status = resp.status().as_u16();
            eprintln!("[whatsminer] GET /admin/network/{} → HTTP {}", program, status);

            if status == 404 {
                continue; // try next program
            }
            if status != 200 {
                return Err(format!("Config page returned HTTP {} for program {}", status, program).into());
            }

            let body = resp.text().await.map_err(|e| format!("Read body: {}", e))?;

            // BTCTools: `name="token"%s*value="%s*([^"]-)*%s*"`
            let token_re = Regex::new(r#"name="token"\s+value="([^"]+)""#).unwrap();
            let token = token_re.captures(&body)
                .map(|c| c[1].trim().to_string())
                .ok_or_else(|| format!("No token in config page for program={}", program))?;

            // Also grab the current coin type (preserve it in the POST)
            let coin_re = Regex::new(r#"id="cbid\.pools\.default\.coin_type[^"]*"\s+value="([^"]*)"[^>]*selected="selected""#).unwrap();
            let coin_type = coin_re.captures(&body)
                .map(|c| c[1].to_string())
                .unwrap_or_default();

            eprintln!("[whatsminer] config token found for program={} coin_type={:?}", program, coin_type);
            return Ok((token, program.to_string(), coin_type));
        }

        Err(format!("Could not find network config page for {} (tried btminer/cgminer)", ip).into())
    }

    // ── Restart mining daemon after pool/config change ────────────────────────

    async fn restart_miner_daemon(client: &Client, ip: &str, program: &str) -> Result<()> {
        // Status path: /admin/status/<program>status/restart
        // e.g. cgminer → cgminerstatus, btminer → btminerstatus
        let daemon = format!("{program}status");
        let url = format!("https://{}/cgi-bin/luci/admin/status/{}/restart", ip, daemon);
        let resp = client
            .get(&url)
            .send()
            .await
            .map_err(|e| format!("Restart daemon request failed: {}", e))?;

        let code = resp.status().as_u16();
        eprintln!("[whatsminer] restart /admin/status/{}/restart → HTTP {}", daemon, code);

        // BTCTools expects 302 on success
        if code == 302 || code == 200 {
            return Ok(());
        }

        // Fallback: try the other daemon name
        let daemon2 = if program == "cgminer" { "btminerstatus" } else { "cgminerstatus" };
        let url2 = format!("https://{}/cgi-bin/luci/admin/status/{}/restart", ip, daemon2);
        let resp2 = client.get(&url2).send().await.map_err(|e| format!("Restart fallback failed: {}", e))?;
        let code2 = resp2.status().as_u16();
        eprintln!("[whatsminer] restart fallback /admin/status/{}/restart → HTTP {}", daemon2, code2);

        if code2 == 302 || code2 == 200 {
            return Ok(());
        }

        Err(format!("restart_miner_daemon failed (code={}/{})", code, code2).into())
    }

    // ── Public API ────────────────────────────────────────────────────────────

    /// Reboot the control board via LuCI.
    pub async fn reboot(ip: &str, username: &str, password: &str) -> Result<()> {
        let client = Self::login(ip, username, password).await?;
        let token = Self::get_reboot_token(&client, ip).await?;

        let url = format!("https://{}/cgi-bin/luci/admin/system/reboot/call", ip);
        let resp = client
            .post(&url)
            .header(header::CONTENT_TYPE, "application/x-www-form-urlencoded")
            .body(format!("token={}", token))
            .send()
            .await
            .map_err(|e| format!("Reboot POST failed: {}", e))?;

        let code = resp.status().as_u16();
        eprintln!("[whatsminer] reboot/call → HTTP {}", code);

        if code == 200 || code == 302 {
            Ok(())
        } else {
            Err(format!("Reboot call returned HTTP {}", code).into())
        }
    }

    /// Set mining pools via LuCI.
    pub async fn set_pools(ip: &str, username: &str, password: &str, mut pools: Vec<WhatsminerPool>) -> Result<()> {
        // Pad to 3 entries
        while pools.len() < 3 {
            pools.push(WhatsminerPool { url: String::new(), worker: String::new(), password: String::new() });
        }

        let client = Self::login(ip, username, password).await?;
        let (token, program, coin_type) = Self::get_config_token(&client, ip).await?;

        let url = format!("https://{}/cgi-bin/luci/admin/network/{}", ip, program);
        let body = format!(
            "token={}&cbi.submit=1&cbi.apply=1\
            &cbid.pools.default.coin_type={}\
            &cbid.pools.default.pool1url={}&cbid.pools.default.pool1user={}&cbid.pools.default.pool1pw={}\
            &cbid.pools.default.pool2url={}&cbid.pools.default.pool2user={}&cbid.pools.default.pool2pw={}\
            &cbid.pools.default.pool3url={}&cbid.pools.default.pool3user={}&cbid.pools.default.pool3pw={}",
            urlencoding::encode(&token),
            urlencoding::encode(&coin_type),
            urlencoding::encode(&pools[0].url), urlencoding::encode(&pools[0].worker), urlencoding::encode(&pools[0].password),
            urlencoding::encode(&pools[1].url), urlencoding::encode(&pools[1].worker), urlencoding::encode(&pools[1].password),
            urlencoding::encode(&pools[2].url), urlencoding::encode(&pools[2].worker), urlencoding::encode(&pools[2].password),
        );

        let resp = client
            .post(&url)
            .header(header::CONTENT_TYPE, "application/x-www-form-urlencoded")
            .body(body)
            .send()
            .await
            .map_err(|e| format!("Set pools POST failed: {}", e))?;

        let code = resp.status().as_u16();
        eprintln!("[whatsminer] set_pools → HTTP {}", code);
        if code != 200 && code != 302 {
            return Err(format!("set_pools returned HTTP {}", code).into());
        }

        // Restart mining daemon to apply changes (BTCTools `restartCGMiner` step)
        Self::restart_miner_daemon(&client, ip, &program).await?;
        Ok(())
    }

    /// Control the locate LED blink.
    /// `blink = true`  → start blinking
    /// `blink = false` → stop blinking
    pub async fn blink_led(ip: &str, username: &str, password: &str, blink: bool) -> Result<()> {
        let client = Self::login(ip, username, password).await?;

        // Candidate LED control endpoints (Whatsminer LuCI doesn't have a standardized one)
        let candidates = if blink {
            vec![
                format!("https://{}/cgi-bin/luci/admin/system/cgminerstatus/blink", ip),
                format!("https://{}/cgi-bin/luci/admin/system/btminerstatus/blink", ip),
                format!("https://{}/cgi-bin/luci/admin/status/cgminerstatus/blink", ip),
                format!("https://{}/cgi-bin/luci/admin/status/btminerstatus/blink", ip),
            ]
        } else {
            vec![
                format!("https://{}/cgi-bin/luci/admin/system/cgminerstatus/blink_off", ip),
                format!("https://{}/cgi-bin/luci/admin/system/btminerstatus/blink_off", ip),
                format!("https://{}/cgi-bin/luci/admin/status/cgminerstatus/blink_off", ip),
                format!("https://{}/cgi-bin/luci/admin/status/btminerstatus/blink_off", ip),
            ]
        };

        for url in &candidates {
            let resp = client.get(url).send().await;
            if let Ok(r) = resp {
                let code = r.status().as_u16();
                eprintln!("[whatsminer] blink_led → {} HTTP {}", url, code);
                if code == 200 || code == 302 {
                    return Ok(());
                }
            }
        }

        // LED endpoint not found — return a non-fatal warning (older models don't have it)
        eprintln!("[whatsminer] ⚠️  blink_led: no working endpoint found — model may not support LED control");
        Ok(()) // best-effort, don't fail the whole operation
    }

    /// Set power mode via LuCI CBI form (BTCTools `setPowerMode` flow).
    ///
    /// `mode` is the LuCI `miner_type` field value. Common values on Whatsminer:
    ///   `"Low"`, `"Normal"`, `"High"` (exact string depends on firmware version).
    ///
    /// The mining daemon restarts after applying; no full board reboot required.
    pub async fn set_power_mode(ip: &str, username: &str, password: &str, mode: &str) -> Result<()> {
        let client = Self::login(ip, username, password).await?;

        // Try cgminer first (M31SV10), then btminer (newer firmware)
        for program in &["cgminer", "btminer"] {
            let url = format!("https://{}/cgi-bin/luci/admin/network/{}/power", ip, program);

            // Step 1: GET the power page to retrieve the CSRF token
            let resp = client.get(&url).send().await
                .map_err(|e| format!("GET power page failed: {}", e))?;
            let status = resp.status().as_u16();
            eprintln!("[whatsminer] GET /network/{}/power → HTTP {}", program, status);

            if status == 404 { continue; }
            if status != 200 {
                return Err(format!("Power page returned HTTP {} for {}", status, program).into());
            }

            let body = resp.text().await.map_err(|e| format!("Read power page: {}", e))?;

            // Extract CSRF token
            let token_re = Regex::new(r#"name="token"\s+value="([^"]+)""#).unwrap();
            let token = token_re.captures(&body)
                .map(|c| c[1].trim().to_string())
                .ok_or_else(|| format!("No CSRF token in power page for {}", program))?;

            // Step 2: POST the new power mode
            // BTCTools field: cbid.<program>.default.miner_type = <mode_value>
            let field = format!("cbid.{}.default.miner_type", program);
            let post_body = format!(
                "token={}&cbi.submit=1&cbi.apply=1&{}={}",
                urlencoding::encode(&token),
                urlencoding::encode(&field),
                urlencoding::encode(mode)
            );
            let resp2 = client.post(&url)
                .header(header::CONTENT_TYPE, "application/x-www-form-urlencoded")
                .body(post_body)
                .send().await
                .map_err(|e| format!("POST power mode failed: {}", e))?;

            let code = resp2.status().as_u16();
            eprintln!("[whatsminer] POST /network/{}/power mode={} → HTTP {}", program, mode, code);

            if code == 200 || code == 302 {
                // Restart mining daemon to apply
                Self::restart_miner_daemon(&client, ip, program).await?;
                return Ok(());
            }

            return Err(format!("set_power_mode returned HTTP {}", code).into());
        }

        Err(format!("No power mode endpoint found for {} (tried cgminer/btminer)", ip).into())
    }
}
