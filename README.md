# Bit-Link Miner Manager

A high-performance Rust-based miner management system for CGMiner-compatible mining hardware.

## Project Status

**Step 1: Basic TCP Client** ✅ Complete  
**Step 2: Network Scanner** ✅ Complete

The core TCP client and network scanner are implemented and tested, supporting:
- CGMiner JSON-RPC protocol over TCP
- Concurrent network scanning with semaphore-based resource management
- Support for both Antminer and Whatsminer formats
- CIDR notation (e.g., `192.168.1.0/24`) and IP range (e.g., `192.168.1.1-192.168.1.254`)
- Real-time progress events
- Comprehensive error handling

## Quick Start

### Prerequisites

- Rust 1.93+ (installed automatically if needed)
- Access to a CGMiner-compatible miner on your network

### Running Tests

```bash
# Run all automated tests
cargo test

# Run with output
cargo test -- --nocapture
```

### Manual Testing with Real Miner

1. Edit `examples/manual_test.rs` and update the miner IP address:
   ```rust
   let miner_ip = "192.168.1.100"; // <-- Change to your miner's IP
   ```

2. Run the manual test:
   ```bash
   cargo run --example manual_test
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


## Architecture

```
src/
├── core/           # Data structures and error types
│   ├── models.rs   # Miner, MinerStats, MinerStatus
│   └── error.rs    # MinerError types
├── client/         # TCP client for CGMiner protocol
│   └── mod.rs      # send_command, get_summary
├── scanner/        # Network scanner
│   └── mod.rs      # scan_range, parse_ip_range, ScanEvent
└── lib.rs          # Public API exports

tests/
├── mock_miner.rs      # Mock CGMiner server
└── scanner_tests.rs   # Scanner integration tests

examples/
├── manual_test.rs     # Single miner test
└── scan_network.rs    # Network scanning demo
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

## Next Steps

- **Step 3**: Monitor loop with state management
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
