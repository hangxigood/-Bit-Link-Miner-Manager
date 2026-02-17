use std::env;
use std::time::Duration;
use reqwest::{Client, StatusCode};

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    let args: Vec<String> = env::args().collect();
    // Usage: cargo run --example debug_whatsminer_web [IP] [USERNAME] [PASSWORD]
    let ip = if args.len() > 1 { &args[1] } else { "192.168.56.192" };
    let username = if args.len() > 2 { &args[2] } else { "admin" };
    let password = if args.len() > 3 { &args[3] } else { "admin" };

    println!("Attempting to connect to Whatsminer Web Interface at {}", ip);
    println!("Credentials: {}/{}", username, password);

    // 1. Create client
    // 1. Create client
    let mut headers = reqwest::header::HeaderMap::new();
    headers.insert("Accept", "text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.7".parse().unwrap());
    headers.insert("Accept-Language", "en-US,en;q=0.9".parse().unwrap());
    headers.insert("Cache-Control", "max-age=0".parse().unwrap());
    headers.insert("Sec-Ch-Ua", "\"Chromium\";v=\"142\", \"Google Chrome\";v=\"142\", \"Not_A Brand\";v=\"99\"".parse().unwrap());
    headers.insert("Sec-Ch-Ua-Mobile", "?0".parse().unwrap());
    headers.insert("Sec-Ch-Ua-Platform", "\"macOS\"".parse().unwrap());
    headers.insert("Sec-Fetch-Dest", "document".parse().unwrap());
    headers.insert("Sec-Fetch-Mode", "navigate".parse().unwrap());
    headers.insert("Sec-Fetch-Site", "none".parse().unwrap()); // none for direct navigation
    headers.insert("Sec-Fetch-User", "?1".parse().unwrap());
    headers.insert("Upgrade-Insecure-Requests", "1".parse().unwrap());

    let client = Client::builder()
        .timeout(Duration::from_secs(10))
        .danger_accept_invalid_certs(true)
        .user_agent("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36")
        .default_headers(headers)
        .cookie_store(true)
        .build()?;

    // 2. Check Root Page first
    println!("Fetching root page: https://{}/", ip);
    let _ = client.get(format!("https://{}/", ip)).send().await; // Ignore result, just priming
    
    // 3. Attempt Login with multiple credential pairs
    let credentials_to_try = vec![
        (username, password),
        ("root", password),
        ("root", "root"),
        ("admin", "root"),
    ];

    let mut sysauth = String::new();

    for (u, p) in credentials_to_try {
        println!("\nTrying credentials: {}/{}", u, p);
        
        let login_url = format!("https://{}/cgi-bin/luci", ip);
        let params = [
            ("luci_username", u),
            ("luci_password", p),
        ];

        let resp = client.post(&login_url)
            .form(&params)
            .send()
            .await?;
        
        println!("POST Login Status: {}", resp.status());
        if resp.url().path() != "/cgi-bin/luci" {
            println!("Redirected to: {}", resp.url());
        }

        // Check for sysauth in URL or Cookies (cookie store handles headers, but we can't easily see them)
        // Check if we got past the login page.
        // If status is 200 and body doesn't contain "Authorization Required", we are good.
        let body = resp.text().await?;
        if !body.contains("Authorization Required") {
            println!("Login SUCCESS with {}/{}", u, p);
            println!("Page title: {}", body.lines().find(|l| l.contains("<title>")).unwrap_or("Unknown"));
            
            // Try to extract sysauth from internal cookie store? 
            // Reqwest doesn't expose cookie store easily.
            // But subsequent requests will use it automatically.
            sysauth = "stored".to_string(); // Mark as success
            break;
        } else {
             println!("Login FAILED (still at login page)");
        }
    }
    // 4. Test Endpoints
    let test_endpoints = vec![
        // Expected Reboot URL
        "/cgi-bin/luci/admin/status/cgminerstatus/restart",
        // Expected Locate URL (Guess)
        "/cgi-bin/luci/admin/status/cgminerstatus/blink",
        // Alternative Locate URL?
        "/cgi-bin/luci/admin/status/cgminerstatus/led",
        // Main status page
        "/cgi-bin/luci/admin/status/cgminerstatus",
    ];

    for endpoint in test_endpoints {
        let url = format!("https://{}{}", ip, endpoint);
        println!("\nTesting Endpoint: {}", url);
        
        let req = client.get(&url);
        // Cookie store handles cookies automatically if login succeeded

        let resp = req.send().await?;
        println!("Status: {}", resp.status());
        
        if resp.status().is_success() || resp.status().is_redirection() {
            println!("Response Headers: {:?}", resp.headers());
            let body = resp.text().await?;
            if endpoint.contains("cgminerstatus") && !endpoint.contains("restart") {
                // Scan for ANY action links or buttons
                println!("Scanning body for actions...");
                for line in body.lines() {
                    if line.contains("href") || line.contains("onclick") || line.contains("action") {
                        if line.contains("luci") || line.contains("cgi-bin") {
                            println!("Action Candidate: {}", line.trim());
                        }
                    }
                }
            }
        } else if resp.status() == StatusCode::FORBIDDEN {
             println!("Still Forbidden. Login likely failed or path is wrong.");
        }
    }

    Ok(())
}
