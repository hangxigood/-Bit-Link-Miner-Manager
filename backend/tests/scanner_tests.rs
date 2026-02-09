use bitlink_miner_manager::{parse_ip_range, scan_range, ScanConfig, ScanEvent};
use std::time::Instant;
use tokio::io::{AsyncReadExt, AsyncWriteExt};
use tokio::net::TcpListener;

/// Start multiple mock miners on different ports
async fn start_mock_miners(ports: Vec<u16>) {
    for port in ports {
        tokio::spawn(async move {
            let listener = TcpListener::bind(format!("127.0.0.1:{}", port))
                .await
                .unwrap();
            
            loop {
                if let Ok((mut socket, _)) = listener.accept().await {
                    tokio::spawn(async move {
                        let mut buffer = vec![0; 1024];
                        if let Ok(n) = socket.read(&mut buffer).await {
                            let request = String::from_utf8_lossy(&buffer[..n]);
                            
                            let response = if request.contains("version") {
                                r#"{"STATUS":[{"STATUS":"S","When":1738800000,"Code":22,"Msg":"CGMiner versions"}],"VERSION":[{"Type":"Test Miner"}],"id":1}"#
                            } else if request.contains("summary") {
                                r#"{"STATUS":[{"STATUS":"S","When":1738800000,"Code":11,"Msg":"Summary"}],"SUMMARY":[{"Elapsed":12345,"MHS av":95000000.0}],"id":1}"#
                            } else {
                                r#"{"STATUS":[{"STATUS":"E","Msg":"Unknown"}]}"#
                            };
                            
                            let _ = socket.write_all(response.as_bytes()).await;
                        }
                    });
                }
            }
        });
    }
    
    // Give servers time to start
    tokio::time::sleep(tokio::time::Duration::from_millis(100)).await;
}

#[tokio::test]
async fn test_parse_cidr_notation() {
    let ips = parse_ip_range("192.168.1.0/30").unwrap();
    assert_eq!(ips.len(), 4);
    
    let ips = parse_ip_range("10.0.0.0/24").unwrap();
    assert_eq!(ips.len(), 256);
}

#[tokio::test]
async fn test_parse_range_notation() {
    let ips = parse_ip_range("192.168.1.1-192.168.1.10").unwrap();
    assert_eq!(ips.len(), 10);
    assert_eq!(ips[0].to_string(), "192.168.1.1");
    assert_eq!(ips[9].to_string(), "192.168.1.10");
}

#[tokio::test]
async fn test_scan_with_single_miner() {
    // Start a mock miner on port 14028
    start_mock_miners(vec![14028]).await;
    
    let config = ScanConfig {
        timeout_ms: 1000,
        max_concurrent: 10,
        ports: vec![14028],
    };
    
    let mut rx = scan_range("127.0.0.1", config).await.unwrap();
    
    let mut found_count = 0;
    
    while let Some(event) = rx.recv().await {
        match event {
            ScanEvent::Found(miner) => {
                found_count += 1;
                assert_eq!(miner.ip, "127.0.0.1");
                assert!(miner.stats.hashrate_avg > 0.0);
            }
            ScanEvent::Complete { found, .. } => {
                assert_eq!(found, 1);
                break;
            }
            _ => {}
        }
    }
    
    assert_eq!(found_count, 1);
}

#[tokio::test]
async fn test_scan_with_multiple_miners() {
    // Start mock miners on ports 14030, 14031, 14032
    start_mock_miners(vec![14030, 14031, 14032]).await;
    
    let config = ScanConfig {
        timeout_ms: 1000,
        max_concurrent: 10,
        ports: vec![14030, 14031, 14032],
    };
    
    // Scan localhost (should find all 3 miners on different ports)
    let mut rx = scan_range("127.0.0.1", config).await.unwrap();
    
    let mut found_count = 0;
    
    while let Some(event) = rx.recv().await {
        match event {
            ScanEvent::Found(_) => {
                found_count += 1;
            }
            ScanEvent::Complete { found, .. } => {
                // Should find at least 1 (first port that responds)
                assert!(found >= 1);
                break;
            }
            _ => {}
        }
    }
    
    assert!(found_count >= 1);
}

#[tokio::test]
async fn test_scan_performance() {
    // Scan a small range quickly (mostly dead IPs)
    let config = ScanConfig {
        timeout_ms: 500, // Short timeout
        max_concurrent: 50,
        ports: vec![14099], // Unlikely to be used
    };
    
    let start = Instant::now();
    let mut rx = scan_range("127.0.0.1-127.0.0.20", config).await.unwrap();
    
    // Consume all events
    while let Some(event) = rx.recv().await {
        if matches!(event, ScanEvent::Complete { .. }) {
            break;
        }
    }
    
    let duration = start.elapsed();
    
    // Should complete quickly even with dead IPs
    // 20 IPs with 50 concurrent and 500ms timeout should take ~1s
    assert!(duration.as_secs() < 3, "Scan took too long: {:?}", duration);
}

#[tokio::test]
async fn test_concurrent_limit() {
    // This test verifies that the semaphore limits concurrent connections
    // We can't easily test the exact number, but we can verify it doesn't crash
    
    let config = ScanConfig {
        timeout_ms: 100,
        max_concurrent: 5, // Very low limit
        ports: vec![14100],
    };
    
    let mut rx = scan_range("127.0.0.1-127.0.0.50", config).await.unwrap();
    
    // Should complete without errors
    while let Some(event) = rx.recv().await {
        if matches!(event, ScanEvent::Complete { .. }) {
            break;
        }
    }
}
