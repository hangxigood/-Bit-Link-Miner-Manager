use tokio::io::{AsyncReadExt, AsyncWriteExt};
use tokio::net::TcpListener;

/// Mock CGMiner server for testing
/// Listens on localhost:14028 and responds to summary commands
pub async fn start_mock_miner(port: u16) -> std::io::Result<()> {
    let listener = TcpListener::bind(format!("127.0.0.1:{}", port)).await?;
    println!("Mock miner listening on 127.0.0.1:{}", port);
    
    loop {
        let (mut socket, _) = listener.accept().await?;
        
        tokio::spawn(async move {
            let mut buffer = vec![0; 1024];
            
            // Read the request
            if let Ok(n) = socket.read(&mut buffer).await {
                let request = String::from_utf8_lossy(&buffer[..n]);
                
                // Check if it's a summary command
                if request.contains("summary") {
                    // Send a realistic Antminer S19 response
                    let response = r#"{
                        "STATUS": [{
                            "STATUS": "S",
                            "When": 1738800000,
                            "Code": 11,
                            "Msg": "Summary",
                            "Description": "cgminer 4.11.1"
                        }],
                        "SUMMARY": [{
                            "Elapsed": 123456,
                            "MHS av": 95000000.0,
                            "MHS 5s": 96000000.0,
                            "MHS 1m": 95500000.0,
                            "MHS 5m": 95200000.0,
                            "MHS 15m": 95100000.0,
                            "Found Blocks": 0,
                            "Getworks": 5000,
                            "Accepted": 4950,
                            "Rejected": 50,
                            "Hardware Errors": 0,
                            "Utility": 2.5,
                            "Discarded": 100,
                            "Stale": 0,
                            "Get Failures": 0,
                            "Local Work": 1000,
                            "Remote Failures": 0,
                            "Network Blocks": 500,
                            "Total MH": 11700000000.0,
                            "Work Utility": 1300.0,
                            "Difficulty Accepted": 5000000.0,
                            "Difficulty Rejected": 50000.0,
                            "Difficulty Stale": 0.0,
                            "Best Share": 1000000,
                            "Device Hardware%": 0.0,
                            "Device Rejected%": 1.0,
                            "Pool Rejected%": 1.0,
                            "Pool Stale%": 0.0,
                            "Last getwork": 1738800000
                        }],
                        "id": 1
                    }"#;
                    
                    let _ = socket.write_all(response.as_bytes()).await;
                }
            }
        });
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use rust_lib_frontend::{get_summary, DEFAULT_TIMEOUT_MS};
    use std::time::Duration;
    use tokio::time::sleep;
    
    #[tokio::test]
    async fn test_mock_server_response() {
        // Start mock server in background
        let port = 14028;
        tokio::spawn(async move {
            let _ = start_mock_miner(port).await;
        });
        
        // Give server time to start
        sleep(Duration::from_millis(100)).await;
        
        // Test connection
        let result = get_summary("127.0.0.1", port, DEFAULT_TIMEOUT_MS).await;
        
        assert!(result.is_ok(), "Failed to get summary: {:?}", result.err());
        
        let stats = result.unwrap();
        assert!(stats.hashrate_avg > 0.0, "Hashrate should be positive");
        assert_eq!(stats.uptime, 123456, "Uptime should match mock data");
        
        // Verify hashrate conversion (95000000 MH/s = 95 TH/s)
        assert!((stats.hashrate_avg - 95.0).abs() < 0.1, 
                "Hashrate should be ~95 TH/s, got {}", stats.hashrate_avg);
    }
}
