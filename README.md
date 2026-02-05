# Bit-Link Miner Manager

A high-performance Rust-based miner management system for CGMiner-compatible mining hardware.

## Project Status

**Step 1: Basic TCP Client** ✅ Complete

The core TCP client module is implemented and tested, supporting:
- CGMiner JSON-RPC protocol over TCP
- Timeout handling (1.5s default)
- Support for both Antminer and Whatsminer formats
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

## Architecture

```
src/
├── core/           # Data structures and error types
│   ├── models.rs   # Miner, MinerStats, MinerStatus
│   └── error.rs    # MinerError types
├── client/         # TCP client for CGMiner protocol
│   └── mod.rs      # send_command, get_summary
└── lib.rs          # Public API exports

tests/
└── mock_miner.rs   # Mock CGMiner server for testing

examples/
└── manual_test.rs  # Manual test with real hardware
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

## Next Steps

- **Step 2**: Network scanner with concurrent IP range scanning
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
