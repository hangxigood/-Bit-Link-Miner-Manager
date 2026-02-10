# Technical Design Document: "Bit-Link" Miner Manager

## 1. Architecture Overview

The system follows a split architecture to leverage the best of both worlds: **Rust** for high-performance, concurrent backend logic, and **Flutter** for a distinct, reactive cross-platform UI.

### High-Level Diagram
```mermaid
graph TD
    UI[Flutter Frontend] <-->|FFI / method_channels| Bridge[Rust Bridge Layer]
    Bridge <--> Controller[Backend Controller]
    Controller --> Scanner[Network Scanner]
    Controller --> Monitor[Miner Monitor]
    
    Scanner -- TCP Connect --> M1[Miner 1]
    Scanner -- TCP Connect --> M2[Miner 2]
    Monitor -- TCP Poll --> M1
    Monitor -- TCP Poll --> M2
```

## 2. Technology Stack

### Backend (The "Engine")
*   **Language:** Rust (Edition 2021)
*   **Async Runtime:** `tokio` (for non-blocking I/O and scheduling)
*   **Serialization:** `serde` + `serde_json` (for parsing CGMiner RPC responses)
*   **Interoperability:** `flutter_rust_bridge` (v2 recommended) for type-safe, zero-copy communication with Flutter.

### Frontend (The "Cockpit")
*   **Framework:** Flutter (MacOS/Windows/Linux)
*   **State Management:** Riverpod (via generated FFI bindings)
*   **Key Widgets:**
    *   `MinerListView` - DataTable with sortable columns
    *   `ScannerControlPanel` - IP range input and scan trigger
    *   `MinerDetailDialog` - Expanded view for individual miner
    *   `BatchActionBar` - Multi-select actions (reboot, blink)
*   **Responsive Design:** Adaptive layout for desktop window resizing (minimum 1024x768)

## 3. Rust Module Design

The Rust codebase (crate: `rust_lib_frontend`) is organized into distinct modules. For full implementation details, refer to the source code links.

### Module Dependency Graph

```text
    +-----------------------------------------------------------+
    |                      api (Facade)                         |
    |  - Exposes: start_scan, start_monitoring                  |
    +------------------------+----------------------------------+
                             |
           +-----------------v-----------------+
           |                                   |
+----------v----------+             +----------v----------+
|      scanner        |             |      monitor        |
| - IP Range Scanning |             | - State Management  |
| - Discovery Stream  |             | - Polling Loop      |
+----------+----------+             +----------+----------+
           |                                   |
           +-----------------v-----------------+
                             |
             +---------------v---------------+
             |            client             |
             | - CGMiner Protocol Impl       |
             | - TCP / Socket Communication  |
             +---------------+---------------+
                             |
                  +----------v----------+
                  |        core         |
                  | - Domain Models     |
                  +---------------------+
```

### 3.1 `core`
**Responsibility:** Shared data models and domain types used across the application.

**Key Types:**
*   **`Miner`** ([backend/src/core/mod.rs](../backend/src/core/mod.rs)): Represents a mining device.
    *   Input: IP address, discovery metadata.
    *   Output: Aggregated device state (model, stats, status).
*   **`MinerStats`**: Real-time metrics and detailed device info.
    *   **Metrics:** `hashrate_rt` (5s avg), `hashrate_avg` (session avg), `temperature_chip` (all chips), `temperature_pcb` (all boards), `fan_speeds`, `uptime`.
    *   **Configuration:** `pool1`..`pool3`, `worker1`..`worker3` (Top 3 pools/workers).
    *   **System:** `firmware` (Version/Date), `software` (Miner implementation), `hardware` (Physical model), `mac_address`.
*   **`MinerStatus`**: logic for health classification.
    *   `Active`: Responding + temp < 85°C + hashrate > 90% expected.
    *   `Warning`: Use for degraded performance.
    *   `Dead`: Connection timeout.
    *   `Scanning`: Discovery phase.

### 3.2 `scanner`
**Responsibility:** Network device discovery.

**Behavior:**
*   **Input:** IP Range (CIDR or Start-End).
*   **Logic:** Spawns lightweight `tokio::task`s for each IP to attempt TCP handshake on port 4028.
*   **Concurrency:** Uses a semaphore to limit concurrent open file descriptors (batch processing).
*   **Output:** Stream of found devices.
*   **Enhanced Parsing:** The scanner/monitor now intelligently chains multiple commands (`summary`, `stats`, `pools`, `version`) to build a complete device profile, handling model-specific quirks (e.g., Antminer vs Whatsminer hashrate formats).

**Source:** [backend/src/scanner/mod.rs](../backend/src/scanner/mod.rs)

### 3.3 `client` (Miner Communication)
**Responsibility:** Encapsulates the CGMiner / BMiner API protocol.

**Interface Contract (Trait):**
The `MinerClient` trait defines the standard operations for any miner model.

```rust
#[async_trait]
pub trait MinerClient {
    /// Fetch current metrics (hashrate, temps, etc.)
    async fn get_summary(&self) -> Result<MinerStats, Error>;
    
    /// Restart the device
    async fn reboot(&self) -> Result<(), Error>;
    
    /// Identify device physically
    async fn blink_led(&self) -> Result<(), Error>;
}
```

**Source:** [backend/src/client/mod.rs](../backend/src/client/mod.rs)

### 3.4 `monitor`
**Responsibility:** Manages the lifecycle of known miners.

**Behavior:**
*   **Loop:** Maintains a list of active IPs and polls them at a configurable interval.
*   **State:** Holds a concurrent hash map (`DashMap`) of the latest miner states.
*   **Broadcasting:** Pushes state updates/diffs to the UI via the bridge.

**Source:** [backend/src/monitor/mod.rs](../backend/src/monitor/mod.rs)

### 3.5 `api` (High-Level Interface)
**Responsibility:** Facade layer for the Flutter bridge. Wraps core functionality into cohesive, FFI-friendly APIs.

**Key Components:**
*   **`scanner`**: Orchestrates `scan_range`, collecting stream events into a final `Vec<Miner>` result for simple frontend consumption.
*   **`monitor`**: Manages global state of monitored miners (`CURRENT_MINERS`) and exposes a simplified `start_monitoring` command.
*   **`commands`**: Implements `execute_batch_command` for parallel control operations.

**Source:** [backend/src/api/mod.rs](../backend/src/api/mod.rs)

### 3.6 `scanner` (Scan Progress) [NOT IMPLEMENTED]
To support real-time progress bars in the UI, the scanner module needs to expose atomic counters.

**Proposed Implementation:**
```rust
static SCAN_PROGRESS_FOUND: AtomicU32 = AtomicU32::new(0);
static SCAN_PROGRESS_TOTAL: AtomicU32 = AtomicU32::new(0);
pub fn get_scan_progress() -> (u32, u32, bool) { ... }
```

## 4. Flutter UI Components

The frontend is organized into reusable widgets that consume data from the Rust backend via FFI streams.

### Component Dependency Graph

```text
    +-----------------------------------------------------------+
    |                     MinerDashboard                        |
    |  (State: List<Miner>, SelectedIPs, Search, Filters, Sort) |
    +-----+-----------+------------+------------+---------------+
          |           |            |            |
  +-------v--------+  |  +---------v---------+ |  +------------v-----+
  |ScannerControl  |  |  | SearchFilterBar   | |  |  BatchActionBar  |
  |Panel           |  |  | (Text + Toggles)  | |  |  (Bulk Actions)  |
  |(Collapsible)   |  |  +-------------------+ |  +------------------+
  +----------------+  |                        |
                +-----v------------------------v---+
                |         MinerListView            |
                |  (Sortable, Color-coded rows,    |
                |   Sticky headers, Wide grid)     |
                +----------------------------------+
                                |
                         +------v------+
                         | MinerDetail |
                         |   Dialog    |
                         +-------------+
    +-----------------------------------------------------------+
    |                      StatusBar                            |
    |   Total: X | Active: X | Warning: X | Offline: X | Sel: X|
    +-----------------------------------------------------------+
```

### 4.1 `MinerListView` (Main Screen)
**Purpose:** Displays all discovered miners in a sortable data table.

**Behavior:**
*   **Input:** `List<Miner>`
*   **Features:** Sortable columns (Status, IP, Model, Hashrate RT, Max Temp, Pool, Worker), selection support.
*   **Output:** `onSelectionChanged` callback.

**Source:** `frontend/lib/src/widgets/miner_list_view.dart`

### 4.1.1 Color-Coded Row Backgrounds [Implemented]
Rows are tinted based on the miner's status:
*   **Active:** Default (no tint)
*   **Warning:** `Colors.orange.withOpacity(0.1)`
*   **Dead:** `Colors.red.withOpacity(0.15)`
*   **Scanning:** `Colors.blue.withOpacity(0.08)`

### 4.1.2 Column Sorting [Implemented]
**State:** `_sortColumnIndex`, `_sortAscending`
**Sortable Columns:** Status, IP, Model, Hashrate RT, Hashrate Avg, Max Temp, Uptime.
**Logic:** `DataColumn.onSort` triggers a state update and resorting of the local list.

### 4.1.3 Wide Data Grid Polish [Partially Implemented]
*   **Minimum column widths:** [Partially Implemented] - Basic logic exists.
*   **Monospaced numbers:** [NOT IMPLEMENTED] - Should apply `fontFamily: 'monospace'` to numeric cells.
*   **Frozen left columns:** [NOT IMPLEMENTED] - Status and IP columns should remain visible while scrolling horizontally.

### 4.1.4 Sticky Column Headers [NOT IMPLEMENTED]
**Requirement:** Split the `DataTable` into a fixed header row and a scrollable body to keep headers visible while vertically scrolling.

### 4.2 `ScannerControlPanel`
**Purpose:** Network discovery interface.

**Behavior:**
*   **Input:** User-defined IP range (CIDR or "start-end").
*   **Action:** Calls `start_scan` (Future-based), displays loading indicator.
*   **Output:** Triggers `onScanComplete` callback with results.

**Source:** `frontend/lib/src/widgets/scanner_control_panel.dart`

### 4.2.1 Collapsible UI [Partially Implemented]
**Behavior:**
*   **Expanded:** Full layout (title, range input, scan button).
*   **Collapsed:** Compact row (Title + Scan button).
*   **Auto-Collapse:** [NOT IMPLEMENTED] Should automatically collapse after the first scan completes.

### 4.2.2 Real-Time Scan Progress [NOT IMPLEMENTED]
**Behavior:**
*   **Polling:** Poll `get_scan_progress()` every 500ms.
*   **Display:** `"Scanning: X/Y IPs... (Z miners found)"`.

### 4.3 `MinerDetailDialog`
**Purpose:** Expanded view for individual miner inspection.

**Behavior:**
*   **Input:** Selected `Miner` object from `MinerListView`.
*   **Displays:** 
    *   **Performance:** RT vs Avg Hashrate, Uptime.
    *   **Thermals:** Chip and PCB temperature grids (color-coded).
    *   **Cooling:** Fan speeds (RPM).
    *   **System Info:** Hardware model, Firmware version, Software version.
    *   **Mining Pools:** List of active pools (1-3) with associated workers.
*   **Actions:** Quick access to single-device commands (reboot, blink).

**Source:** `frontend/lib/src/widgets/miner_detail_dialog.dart`

### 4.4 `BatchActionBar`
**Purpose:** Execute commands on multiple selected miners.

**Behavior:**
*   **Input:** List of selected miner IPs from `MinerListView`.
*   **Actions:** Reboot, Blink LED (calls `execute_command()` bridge function).
*   **Feedback:** Shows progress indicator and success/failure toast notifications.

**Source:** `frontend/lib/src/widgets/batch_action_bar.dart` *(to be implemented)*

### 4.4.1 Staggered Batch Execution [NOT IMPLEMENTED]
**Requirement:** To prevent network flooding and handle device limitations, batch actions should be staggered.

**Proposed Backend Logic:**
*   **BatchConfig:** `max_concurrent: 10`, `delay_between_batches_ms: 0`.
*   **Concurrency:** Use `tokio::sync::Semaphore` to limit concurrent tasks.

## 4.5 StatusBar [Implemented]
**Widget:** `StatusBar` — `frontend/lib/src/widgets/status_bar.dart`

**Behavior:**
*   **Input:** `List<Miner>`, `int selectedCount`
*   **Output:** Fixed bottom bar: `Total: X | Active: X | Warning: X | Offline: X | Selected: X`
*   **Styling:** Compact height, monospaced counts, color-coded.

## 4.6 SearchFilterBar [NOT IMPLEMENTED]
**Widget:** `SearchFilterBar` — `frontend/lib/src/widgets/search_filter_bar.dart`

**Behavior:**
*   **Inputs:** `onSearchChanged(String)`, `onFilterChanged(Set<String>)`
*   **Components:** Text search (IP/Model) + Filter Chips (Active/Warning).
*   **Logic:** `MinerDashboard` filters the list before passing it to `MinerListView`.

## 5. CGMiner API Protocol Detail

Communication is done by sending a JSON payload over a raw TCP socket.

**Request Format:** `{"command": "summary", "parameter": ""}`

**Response Contract:**
Miners return a JSON object with a `STATUS` array and a data array (e.g., `SUMMARY`).
*   **Edge Cases:** Antminer vs Whatsminer key differences ("MHS av" vs "HS 5s"), non-standard ports (4029/4030).

## 6. Interface Layer (Flutter Bridge)

We use `flutter_rust_bridge` to generate binding code. The `backend/src/api` module defines the **API boundary** between the UI and the Rust backend.

### Exposed Functions (Rust -> Dart)

These functions are defined in the `backend/src/api` module:

1.  **`start_scan`**
    *   **Input:** `ip_range: String` (CIDR or "start-end")
    *   **Output:** `Vec<Miner>` (Waits for scan completion and returns all discovered miners)

2.  **`start_monitoring`** (Stateful)
    *   **Input:** `ips: Vec<String>`
    *   **Output:** `()` (Starts background polling loop; updates are accessible via `get_current_miners`)

3.  **`execute_batch_command`**
    *   **Input:** `target_ips: Vec<String>`, `command: MinerCommand`
    *   **Output:** `Vec<CommandResult>` (Batch execution results per IP)

## 7. Implementation Strategy

1.  **Basic TCP Client:** Implement `client` module to handshake and parse JSON.
2.  **The Scanner:** Implement `scanner` with `tokio::spawn` and timeouts.
3.  **State Management:** Implement `monitor` loop (poll, update, broadcast).
4.  **Integration:** Wire up `flutter_rust_bridge` to run Rust logic from Flutter.

## 8. Performance Considerations

*   **Socket Limits:** Scanner must respect `ulimit -n` (batch requests).
*   **Parsing Overhead:** Use `serde_json::from_slice` for efficiency.
*   **Target:** Scan 254 IPs in <10s (Requires ~100 concurrent connections).

## 9. Error Handling Strategy

**Error Categories:**
*   **Timeout:** Connection unavailable.
*   **ParseError:** Invalid JSON from miner.
*   **NetworkError:** IO failures.
*   **Authentication:** 401/403 errors (S19+ models).

**Propagation:**
*   **Rust → Flutter:** Errors are serialized as structured data via FFI.
*   **UI:** Toast notifications for transient errors, dialogs for critical failures.

## 10. Configuration Management

**Key Configuration Parameters:**
*   **Network:** `scan_timeout_ms` (Default: 2500ms), `max_concurrent_scans` (Default: 100).
*   **Monitoring:** `poll_interval_ms` (Default: 10s), `retry_attempts`.
*   **Thresholds:** `warning_temp_threshold` (85°C), `warning_hashrate_ratio` (90%).

**Storage:** User preferences saved to `~/.bitlink/config.json`.

## 11. Observability & Debugging

*   **Logging:** `tracing` crate (ERROR, WARN, INFO, DEBUG).
*   **Metrics:** Scan duration, active connections, success rates exposed via FFI.

## 12. Testing Strategy

*   **Unit Tests:** Mock TCP responses for `client` and `scanner`.
*   **Integration Tests:** End-to-end scan against mock miner servers.
*   **Manual Testing:** `docker-compose` virtual network with simulated miners.

## 13. Platform Specifics (macOS)

*   **App Sandbox:** Flutter apps on macOS run in a sandbox by default.
*   **Entitlements:** The `com.apple.security.network.client` entitlement is **required** in `DebugProfile.entitlements` and `Release.entitlements` to allow the scanner to make outgoing TCP connections.

## 14. Future Enhancements

*   **Data Persistence:** SQLite for historical trends.
*   **Alerts:** Desktop notifications.
*   **Bulk Config:** Pool configuration updates.
*   **Remote Access:** WebSocket control.


## 15. Implementation Priority (Revised)

| Order | Feature | Status |
| :---: | :--- | :--- |
| 1 | Color-coded row backgrounds | **Implemented** |
| 2 | Status bar | **Implemented** |
| 3 | Column sorting | **Implemented** |
| 4 | Collapsible scanner panel | **Partially Implemented** |
| 5 | Search & filter bar | **Pending** |
| 6 | Staggered batch execution | **Pending** |
| 7 | Scan progress | **Pending** |
| 8 | Sticky column headers | **Pending** |
| 9 | Wide data grid polish | **Partially Implemented** |
