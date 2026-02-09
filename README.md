# Bit-Link Miner Manager

A high-performance Rust-based miner management system for CGMiner-compatible mining hardware.

## Project Status

**Step 1: Basic TCP Client** ✅ Complete  
**Step 2: Network Scanner** ✅ Complete  
**Step 3: Monitor Loop** ✅ Complete

The core backend is fully implemented, supporting:
- CGMiner JSON-RPC protocol over TCP
- Concurrent network scanning with semaphore-based resource management
- Continuous monitoring with real-time status tracking
- Support for both Antminer and Whatsminer formats
- CIDR notation (e.g., `192.168.1.0/24`) and IP range (e.g., `192.168.1.1-192.168.1.254`)
- Real-time progress events and state updates
- Comprehensive error handling

## Quick Start

### Prerequisites

- Rust 1.93+ (installed automatically if needed)
- Flutter 3.19+ (Follow [installation guide](https://docs.flutter.dev/get-started/install))
- Access to a CGMiner-compatible miner on your network

### Running Tests

> **Note:** All Rust commands must be run from the `backend/` directory.

```bash
cd backend

# Run all automated tests
cargo test

# Run with output
cargo test -- --nocapture
```

### Manual Testing with Real Miner

1. Edit `backend/examples/manual_test.rs` and update the miner IP address:
   ```rust
   let miner_ip = "192.168.1.100"; // <-- Change to your miner's IP
   ```

2. Run the manual test:
   ```bash
   cd backend && cargo run --example manual_test
   ```

3. Expected output:
   ```
   === Bit-Link Miner Manager - Manual Test ===
   
   Attempting to connect to miner at 192.168.1.100:4028...
   ✓ Connection successful!
   Version response: {...}
   
   Fetching miner summary...
   ✓ Summary retrieved successfully!
   
   Miner Statistics:
     Hashrate (avg): 95.00 TH/s
     Hashrate (rt):  95.00 TH/s
     Uptime:         123456 seconds (34.3 hours)
     ...
   ```

### Network Scanning

Scan your entire network to discover all miners:

```bash
# Edit examples/scan_network.rs and set your network range
# Example: "192.168.1.0/24" or "192.168.56.1-192.168.56.254"
cargo run --example scan_network
```

Expected output:
```
=== Network Scanner Test ===
Scanning range: 192.168.56.0/24 (256 IPs)
Max concurrent: 100, Timeout: 2000ms

[Progress: 50/256] ✓ Found miner at 192.168.56.31
  Model: Antminer S19 XP
  Hashrate: 143.02 TH/s
  Uptime: 354237 seconds (98.4 hours)

[Progress: 256/256 (100.0%)]

=== Scan Complete ===
Found: 1 miner(s)
Failed: 255 IP(s)
Duration: 6.23s
```

### Continuous Monitoring

Monitor discovered miners in real-time with automatic status tracking:

```bash
cargo run --example monitor_demo
```

This will:
1. Scan your network for miners
2. Start monitoring them every 10 seconds
3. Display real-time status updates in a live table

Expected output:
```
Step 1: Scanning network for miners...
  ✓ Found: 192.168.56.31 (Antminer S19 XP)
  ✓ Found: 192.168.56.32 (Antminer S19 XP)

Scan complete! Found 2 miner(s)

Step 2: Starting continuous monitoring...
Monitoring 2 miner(s) with 10-second poll interval

[  10.5s] 📊 Status Snapshot:
  ┌────────────────────┬──────────┬────────────┬──────────┐
  │ IP Address         │ Status   │ Hashrate   │ Max Temp │
  ├────────────────────┼──────────┼────────────┼──────────┤
  │ 192.168.56.31      │ ✅ Active │  143.03 TH │   72.5°C │
  │ 192.168.56.32      │ ✅ Active │  136.82 TH │   71.2°C │
  └────────────────────┴──────────┴────────────┴──────────┘
```

**Status indicators:**
- ✅ **Active**: Healthy (temp < 85°C, hashrate normal)
- ⚠️ **Warning**: High temperature OR low hashrate
- ❌ **Dead**: Not responding





## Architecture

## Architecture

```
backend/            # Rust Backend ("The Engine")
├── src/            # Core logic
│   ├── client/     # TCP client
│   ├── scanner/    # Network scanner
│   ├── monitor/    # Continuous monitoring
│   └── lib.rs      # Public API exports
├── examples/       # Usage demos
└── tests/          # Integration tests

frontend/           # Flutter Frontend ("The Cockpit")
└── lib/            # UI components (Coming soon)
```

## API Usage

```rust
use bitlink_miner_manager::{get_summary, DEFAULT_PORT, DEFAULT_TIMEOUT_MS};

#[tokio::main]
async fn main() {
    let stats = get_summary("192.168.1.100", DEFAULT_PORT, DEFAULT_TIMEOUT_MS)
        .await
        .expect("Failed to get miner stats");
    
    println!("Hashrate: {:.2} TH/s", stats.hashrate_avg);
}
```

**Scan a network range:**
```rust
use bitlink_miner_manager::{scan_range, ScanConfig, ScanEvent};

#[tokio::main]
async fn main() {
    let config = ScanConfig::default();
    let mut rx = scan_range("192.168.1.0/24", config).await.unwrap();
    
    while let Some(event) = rx.recv().await {
        match event {
            ScanEvent::Found(miner) => {
                println!("Found: {} - {:.2} TH/s", 
                         miner.ip, miner.stats.hashrate_avg);
            }
            ScanEvent::Complete { found, .. } => {
                println!("Scan complete! Found {} miners", found);
                break;
            }
            _ => {}
        }
    }
}
```

**Monitor miners continuously:**
```rust
use bitlink_miner_manager::{start_monitor, MonitorConfig, MonitorEvent};

#[tokio::main]
async fn main() {
    let ips = vec!["192.168.1.31".to_string(), "192.168.1.32".to_string()];
    let config = MonitorConfig::default(); // Polls every 10 seconds
    let mut rx = start_monitor(ips, config).await;
    
    while let Some(event) = rx.recv().await {
        match event {
            MonitorEvent::MinerUpdated(miner) => {
                println!("{} is now {:?}", miner.ip, miner.status);
            }
            MonitorEvent::FullSnapshot(miners) => {
                println!("Current fleet: {} miners", miners.len());
            }
            _ => {}
        }
    }
}
```

## Next Steps

- **Step 4**: Flutter integration via flutter_rust_bridge

## Technical Details

### CGMiner Protocol

The client communicates using JSON-RPC over raw TCP sockets:

**Request:**
```json
{"command": "summary", "parameter": ""}
```

**Response:**
```json
{
  "STATUS": [{"STATUS": "S", "Msg": "Summary"}],
  "SUMMARY": [{"Elapsed": 123456, "MHS av": 95000000.0, ...}]
}
```

### Supported Miner Models

- ✅ Antminer S19 series (tested with mock data)
- ✅ Whatsminer M30 series (format supported)
- 🔄 Other CGMiner-compatible miners (should work)

### Configuration

Default values (can be customized):
- Port: `4028`
- Timeout: `1500ms`

## License

MIT
