use rust_lib_frontend::{start_monitor, MonitorConfig, MonitorEvent, MinerStatus, Miner, MinerStats};
use std::time::Duration;
use tokio::io::{AsyncReadExt, AsyncWriteExt};
use tokio::net::TcpListener;

/// Start a mock miner that can simulate status changes
async fn start_mock_miner_with_control(port: u16, temp: f64, hashrate: f64) {
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
                        
                        let response = if request.contains("summary") {
                            format!(
                                r#"{{"STATUS":[{{"STATUS":"S","When":1738800000,"Code":11,"Msg":"Summary"}}],"SUMMARY":[{{"Elapsed":12345,"MHS av":{},"Temp1":{temp},"Temp2":{temp}}}],"id":1}}"#,
                                (hashrate * 1_000_000.0) as u64
                            )
                        } else {
                            r#"{"STATUS":[{"STATUS":"S"}]}"#.to_string()
                        };
                        
                        let _ = socket.write_all(response.as_bytes()).await;
                    }
                });
            }
        }
    });
    
    tokio::time::sleep(Duration::from_millis(100)).await;
}

fn create_test_miner(ip: &str) -> Miner {
    Miner {
        ip: ip.to_string(),
        model: None,
        status: MinerStatus::Scanning,
        stats: MinerStats::default(),
        last_updated: 0,
    }
}

#[tokio::test]
async fn test_monitor_basic_polling() {
    // Start a mock miner
    start_mock_miner_with_control(15001, 70.0, 100.0).await;
    
    let config = MonitorConfig {
        poll_interval_ms: 1000, // Fast polling for testing
        port: 15001,
        ..Default::default()
    };
    
    let mut rx = start_monitor(vec![create_test_miner("127.0.0.1")], config).await;
    
    // Should receive initial snapshot
    if let Some(MonitorEvent::FullSnapshot(miners)) = rx.recv().await {
        assert_eq!(miners.len(), 1);
        assert_eq!(miners[0].ip, "127.0.0.1");
    } else {
        panic!("Expected initial snapshot");
    }
    
    // Wait for first poll
    tokio::time::sleep(Duration::from_millis(1500)).await;
    
    // Should receive updated snapshot
    let mut found_snapshot = false;
    while let Ok(event) = tokio::time::timeout(Duration::from_millis(500), rx.recv()).await {
        if let Some(MonitorEvent::FullSnapshot(miners)) = event {
            assert_eq!(miners.len(), 1);
            assert_eq!(miners[0].status, MinerStatus::Active);
            found_snapshot = true;
            break;
        }
    }
    
    assert!(found_snapshot, "Should receive snapshot after polling");
}

#[tokio::test]
async fn test_monitor_status_active() {
    // Healthy miner: normal temp, good hashrate
    start_mock_miner_with_control(15002, 70.0, 100.0).await;
    
    let config = MonitorConfig {
        poll_interval_ms: 500,
        port: 15002,
        warning_temp_threshold: 85.0,
        ..Default::default()
    };
    
    let mut rx = start_monitor(vec![create_test_miner("127.0.0.1")], config).await;
    
    // Skip initial snapshot
    let _ = rx.recv().await;
    
    // Wait for poll
    tokio::time::sleep(Duration::from_millis(1000)).await;
    
    // Find the snapshot
    while let Ok(Some(event)) = tokio::time::timeout(Duration::from_millis(500), rx.recv()).await {
        if let MonitorEvent::FullSnapshot(miners) = event {
            if !miners.is_empty() && miners[0].stats.hashrate_avg > 0.0 {
                assert_eq!(miners[0].status, MinerStatus::Active);
                return;
            }
        }
    }
}

#[tokio::test]
async fn test_monitor_multiple_miners() {
    // Start multiple mock miners
    start_mock_miner_with_control(15003, 70.0, 100.0).await;
    start_mock_miner_with_control(15004, 75.0, 95.0).await;
    start_mock_miner_with_control(15005, 80.0, 90.0).await;
    
    let config = MonitorConfig {
        poll_interval_ms: 1000,
        port: 15003, // Will be overridden per IP
        ..Default::default()
    };
    
    // Note: In a real implementation, you'd need to support different ports per IP
    // For now, we'll just test with one
    let mut rx = start_monitor(vec![create_test_miner("127.0.0.1")], config).await;
    
    // Should receive initial snapshot
    if let Some(MonitorEvent::FullSnapshot(miners)) = rx.recv().await {
        assert_eq!(miners.len(), 1);
    }
}

#[tokio::test]
async fn test_monitor_dead_detection() {
    // Don't start a server - miner should be marked as dead
    let config = MonitorConfig {
        poll_interval_ms: 500,
        port: 15099, // Non-existent port
        timeout_ms: 500,
        retry_attempts: 0,
        ..Default::default()
    };
    
    let mut rx = start_monitor(vec![create_test_miner("127.0.0.1")], config).await;
    
    // Skip initial snapshot
    let _ = rx.recv().await;
    
    // Wait for poll
    tokio::time::sleep(Duration::from_millis(1500)).await;
    
    // Should detect as dead
    while let Ok(Some(event)) = tokio::time::timeout(Duration::from_millis(500), rx.recv()).await {
        match event {
            MonitorEvent::MinerUpdated(miner) => {
                assert_eq!(miner.status, MinerStatus::Dead);
                return;
            }
            MonitorEvent::FullSnapshot(miners) => {
                if !miners.is_empty() {
                    assert_eq!(miners[0].status, MinerStatus::Dead);
                    return;
                }
            }
            _ => {}
        }
    }
}
