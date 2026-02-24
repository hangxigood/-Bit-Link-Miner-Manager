# Technical Design: "Bit-Link" Miner Manager

## 1. System Architecture
The application uses a **Split Architecture**: Rust for high-performance backend logic, and Flutter for the UI. Communication is handled via `flutter_rust_bridge`.

### High-Level Components
```mermaid
graph TD
    UI[Flutter Frontend] <-->|FFI Stream| API[Rust API Facade]
    API --> Config[Settings & State]
    API --> Scanner[Scanner Module]
    API --> Monitor[Monitor Module]
    API --> Cmd[Command Executor]
    
    Scanner -->|TCP Handshake| Network
    Monitor -->|CGMiner API| Network
    Cmd -->|Web API| Network
```

---

## 2. Code Map
This table defines the responsibility of each module in the codebase.

| Path | Module | Responsibility |
| :--- | :--- | :--- |
| **Backend** | | |
| `backend/src/api/` | **Facade** | FFI boundary (`lib.rs`, `simple.rs`, `settings.rs`) and sub-modules (`commands`, `monitor`, `scanner`) exposed to Dart. |
| `backend/src/core/config.rs` | **Config** | `AppSettings` struct. Handles JSON persistence of credentials & scan settings. |
| `backend/src/scanner/` | **Discovery** | Logic for `scan_range`. Manages thread pool & semaphores. |
| `backend/src/monitor/` | **State** | The polling loop. Maintains `DashMap<IP, MinerStats>`. |
| `backend/src/client/` | **Protocol** | `CGMinerClient` (TCP), `WhatsminerWebClient` (LuCI HTTP) & `AntminerWebClient` (Digest HTTP). |
| `backend/src/core/` | **Domain** | Shared types: `Miner`, `MinerStats`, `MinerStatus`, `MinerCredentials`. |
| `backend/src/api/models.rs` | **FFI Types** | `MinerCommand` (exported as `@freezed` sealed class) and `PoolConfig`. |
| `backend/src/utils.rs` | **Utils** | Shared utilities (e.g., JSON cleanup). |
| **Frontend** | | |
| `frontend/lib/src/rust/` | **Bridge** | Auto-generated FFI code (Do not edit manually). |
| `frontend/lib/src/controllers/` | **State** | Logic & State Management (`ActionController`, `DashboardController`). Handles concurrent batch operations. |
| `frontend/lib/src/widgets/` | **UI** | Reusable components (`MinerDataTable`, `DashboardShell`). Uses `GlobalKey` for local state lifting (e.g., config sections). |
| `frontend/lib/src/constants/` | **Config** | Shared constants (`ColumnConstants`). |
| `frontend/lib/src/theme/` | **Style** | App implementation of design system. |

---

## 3. Core Data Structures (`backend/src/core/mod.rs`)

### 3.1 `AppSettings` (New)
Persisted in `app_settings.json` via `backend/src/core/config.rs`.
*   **antminer_credentials**: `MinerCredentials` (User/Pass)
*   **whatsminer_credentials**: `MinerCredentials` (User/Pass)
*   **scan_thread_count**: `u32`
*   **monitor_interval**: `u64`

### 3.2 `Miner`
Represents the **identity** of a device.
*   **ip**: `String` (Unique Key)
*   **mac**: `Option<String>`
*   **model**: `String` (e.g., "S19 Pro")

### 3.3 `MinerStats`
Represents the **telemetry** of a device at a specific point in time.
*   **hashrate_rt**: `f64` (Real-time 5s average)
*   **hashrate_avg**: `f64` (Session average)
*   **temp_outlet_min/max**: `Vec<Option<f64>>` (Outlet/Chip temperatures)
*   **temp_inlet_min/max**: `Vec<Option<f64>>` (Inlet/PCB temperatures)
*   **fan_speeds**: `Vec<Option<u32>>` (RPMs)
*   **pools**: `Vec<PoolConfig>` (Active stratum URLs) - *Note: implementation uses explicit fields pool1/worker1 etc.*
*   **firmware**: `Option<String>`
*   **software**: `Option<String>`
*   **hardware**: `Option<String>`

### 3.4 `MinerStatus` (Enum)
Logic for classifying device health:
*   **Active**: `Hashrate > Limit` && `Temp < Limit`
*   **Warning**: Performance degraded.
*   **Offline**: Connection refused / Timeout.
*   **Scanning**: Initial discovery phase.

### 3.5 `MinerCommand` and `PoolConfig` (API Models)
*   **`PoolConfig`**: FFI-safe struct containing `url`, `worker`, and `password`.
*   **`MinerCommand`**: Enum (`Reboot`, `BlinkLed`, `StopBlink`, `SetPools { pools: Vec<PoolConfig> }`). Exposed to Dart via Flutter Rust Bridge as a `freezed` sealed class to support complex variants holding data.

---

## 4. System Flows

### 4.1 Network Discovery (Scan)
**Module:** `backend/src/scanner/mod.rs`

1.  **Input**: Range (e.g., `192.168.1.0/24`) -> expands to 254 IPs.
2.  **Semaphore**: Acquires a permit from `Arc<Semaphore>` (Limit: 100) to control concurrency.
3.  **Task**: Spawns `tokio::task` for each IP.
4.  **Handshake**: Attempts TCP connect to port `4028`.
    *   If Success -> `Client::get_summary()` -> Return `Miner`.
    *   If Fail -> Drop.
5.  **Collector**: Results are streamed back to the UI or collected into a `Vec<Miner>`.

### 4.2 Monitoring Loop
**Module:** `backend/src/monitor/mod.rs`

```mermaid
sequenceDiagram
    participant UI
    participant Monitor
    participant Miner
    
    UI->>Monitor: start_monitoring(ips)
    loop Every 10s
        Monitor->>Miner: TCP Poll (get_stats)
        Miner-->>Monitor: JSON Response
        Monitor->>Monitor: Diff with previous state
        Monitor-->>UI: Stream Event (Updated/Changed)
    end
```

### 4.3 Staggered Batch Execution
**Module:** `backend/src/api/commands.rs`

Goal: Execute a command on N miners without tripping breakers.
1.  **Input**: Target IPs, `MinerCommand`.
2.  **Config**: Loads `AppSettings` to get credential sets.
3.  **Routing**:
    *   **Whatsminer**: Uses `WhatsminerWebClient` with `whatsminer_credentials`.
    *   **Antminer**: Uses Digest Auth with `antminer_credentials`.
4.  **Loop**:
    *   Execute chunk concurrently (`join_all`).
    *   `sleep(DelaySeconds)`.
    *   Report progress callback to UI.

---

## 5. FFI Boundary (Rust -> Dart)
These functions in `backend/src/api/` are the **only** entry points for the UI.

1.  `get_app_settings() -> AppSettings`
2.  `save_app_settings(settings: AppSettings)`
3.  `start_scan(range: String) -> Stream<ScanEvent>`
4.  `stop_scan()`
5.  `start_monitoring(ips: Vec<String>) -> Stream<MonitorEvent>`
6.  `stop_monitoring()`
7.  `execute_command(ips: Vec<String>, cmd: MinerCommand, delay: u64, batch_size: usize)`
8.  `detect_local_ranges() -> Vec<String>`
9.  `set_miner_pools(ip: String, pools: Vec<PoolConfig>) -> CommandResult`
10. `get_miner_pools(ip: String) -> Vec<PoolConfig>`
11. `set_miner_power_mode(ip: String, sleep: bool) -> CommandResult`

---

## 6. Implementation Guidelines
*   **No "Business Logic" in UI**: The Flutter side should be a dumb renderer. State decisions (e.g., "Is this miner overheated?") happen in Rust (`MinerStatus::from_stats`).
*   **Frontend State Lifting**: Use `GlobalKey<SectionState>` in the `Sidebar` to expose localized form data (like Pool/Power configs) up to the `DashboardShell` without deeply coupling the UI components.
*   **Error Handling**: Rust errors (`anyhow::Result`) are mapped to FFI enums so Flutter can show distinct toasts (NetworkError vs AuthError). Web clients (Antminer HTTP) implement "tolerant POSTs" to gracefully handle connection drops caused by immediate reboots on config changes.

---

## Appendix A: Protocol Implementation Details
**Critical Knowledge for Rebuilding the Client Module (`backend/src/client/mod.rs`)**

### A.1 CGMiner API Quirks
*   **Port**: Default is `4028`.
*   **Request Format**: `{"command": "summary", "parameter": ""}`.
*   **Response Handling**:
    *   **Trailing Garbage**: Miners often send null bytes (`\0`) or whitespace after the JSON. The parser **MUST** trim these characters before passing to `serde_json` or implement a "find last `}`" logic.

### A.2 parsing Variability
Different manufacturers return different JSON keys for the same data. The client must try them in order:

| Metric | Primary Key (Antminer) | Fallback Key (Whatsminer/Other) | Unit Logic |
| :--- | :--- | :--- | :--- |
| **Hashrate (Avg)** | `SUMMARY[0].MHS av` | `SUMMARY[0].GHS av` | Scale to **TH/s** (MHS / 1M, GHS / 1k). |
| **Hashrate (RT)** | `SUMMARY[0].GHS 5s` | `SUMMARY[0].HS 5s` | `HS 5s` may be a string ("13.5T"); needs regex parsing. |
| **Temperatures** | `STATS[0].temp_chip` | `STATS[0].temp` | Can be list of floats OR string "45-50-60". **Take MAX**. |
| **Fans** | `STATS[0].fanX` | | Collect all `fan[0-9]` keys. Filter 0 RPM. |

### A.3 MAC Address Retrieval
Since the API does not return MAC addresses, the system **MUST** query the OS ARP table (`arp -n` on macOS/Linux) after a successful connection to resolve the IP to a MAC address.
