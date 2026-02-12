# PRD: "Bit-Link" Miner Manager

## 1. Project Objective
To build a high-performance, cross-platform desktop application that discovers, monitors, and manages Bitcoin ASIC miners (Antminer, Whatsminer, etc.) within a local network. The goal is to demonstrate proficiency in concurrency (Rust) and cross-platform UI (Flutter).

---

## 2. Target Audience
*   **Primary:** Mine operators who need to monitor hardware health and performance in real-time.
*   **Environment:** Industrial warehouses with high-density networking and hardware (100–1000+ miners per facility).

---

## 3. Core Features

### Phase 1: Network Discovery (High Priority) ✅
*   **IP Range Scanning:** User can input an IP range (e.g., `192.168.1.1-192.168.1.254` or CIDR `192.168.1.0/24`).
*   **IP Range Management:** Support multiple saved IP ranges. Users can add (+), remove (−), and select which ranges to scan.
*   **High-Speed Probing:** Multi-threaded/concurrent scanner checks for open port `4028` (CGMiner/BMiner API default).
*   **Auto-Identification:** Identify miner model, firmware version, and MAC address upon connection.
*   **Auto-Range Detection:** One-click feature to automatically detect and populate local network subnets where miners are active, eliminating manual IP entry.

### Phase 2: Real-Time Monitoring (High Priority) ✅
**Comprehensive Data Grid:**
*   **Single View Philosophy:** All vital miner information is displayed directly in the main list view to allow rapid cross-comparison. No separate "Detail Dialogs" — operators get the full picture at a glance.
*   **Columns:**
    *   **Status:** Active (✅), Warning (⚠️), Dead (❌), Scanning (🔍).
    *   **Identification:** IP Address, MAC Address, Model.
    *   **Performance:** Hashrate RT, Hashrate Avg.
    *   **Thermals:** Max Temp, Chip Temps, PCB Temps (detailed breakdown if space permits or on hover).
    *   **Cooling:** Fan Speeds (RPMs).
    *   **Uptime:** Session duration.
    *   **Configuration:** Full Pool 1–3 URLs, Workers, Firmware Version.

### Phase 3: Batch Control (Medium Priority) ✅
*   **Reboot:** Send a reboot command to selected miners.
*   **Blink LED:** Trigger the "Flash LED" command.
*   **Safe Execution (Staggered Batching):**
    *   **Problem:** Rebooting or changing power modes on hundreds of miners simultaneously causes massive power surges/drops that can trip breakers.
    *   **Solution:** Users can configure a **"Max Concurrent Operations"** limit (e.g., reboot 10 miners at a time) or a delay interval between batches. The system queues commands and executes them sequentially to smooth out power consumption.

### Phase 4: Batch Configuration (Future — Medium Priority)
*   **Pool Configuration Panel:** Dedicated area for setting Pool/Worker/Password.
*   **Power Control:** LPM / Enhanced LPM modes.
*   **Power Safety:** Staggered execution logic (defined in Phase 3) applies strictly to power control commands.
*   **Overclock/Underclock:** Model-specific frequency profiles.

### Phase 5: Data & Export (Future — Low Priority)
*   **Export:** Export current miner list to CSV/Excel for record-keeping and reporting.
*   **Auto-Import:** Import miner lists from file for quick setup.
*   **Filter: "Only Success Miners"** — Toggle to show only responsive/active miners.

---

## 4. Technical Architecture

### Backend (The "Engine")
*   **Language:** Rust (Edition 2021).
*   **Async Runtime:** `tokio` for non-blocking I/O and scheduling.
*   **Communication:**
    *   **TCP Sockets:** Direct communication with miners via JSON-RPC over TCP.
*   **Concurrency:** `tokio::spawn` tasks with semaphore-controlled concurrency for hundreds of concurrent connections.
*   **Data Bridge:** `flutter_rust_bridge` (FFI) for type-safe communication with Flutter.

### Frontend (The "Cockpit")
*   **Framework:** Flutter for Desktop (macOS/Windows/Linux).
*   **State Management:** `Provider` or `Riverpod` for real-time stream updates from the backend.
*   **Components:**
    *   `DataTable` / `DataGrid` for the miner list.
    *   Scanner control panel with IP range input.
    *   Detail dialog for individual miner inspection.
    *   Batch action bar for multi-select operations.

---

## 5. UI/UX Requirements

### 5.1 Visual Design
*   **Dark Mode First:** Default dark theme — standard for engineering/monitoring tools. Easier on the eyes during extended warehouse shifts and low-light environments.
*   **Color System:**
    *   **Status Colors:** Green (healthy), Orange (warning), Red (critical/dead), Blue (scanning).
    *   **Temperature Gradient:** Green → Orange → Red based on thermal thresholds.
    *   **Accent Color:** Deep purple/blue for interactive elements (buttons, selection highlights).
*   **Typography:**
    *   Monospaced or semi-monospaced numbers for hashrates, temperatures, and IPs — ensures column alignment.
    *   Bold IP addresses for quick visual scanning.
    *   Smaller font (12px) for secondary info (MACs, firmware, pool URLs) to reduce clutter.

### 5.2 Layout & Information Architecture
*   **Three-Zone Layout:**
    1.  **Top Bar:** App title + global actions (Settings).
    2.  **Control Panel:** Collapsible scanner input + batch config area. Should minimize when not in use to maximize table space.
    3.  **Data Table:** Takes up the majority of screen real estate. Full-width, horizontally scrollable.
*   **Status Bar (Bottom):** Summary strip showing: `Total: X | Active: X | Warning: X | Offline: X | Selected: X` — always visible for at-a-glance fleet health.
*   **Information Density:** Optimize for "scan and compare" workflows — operators glance across rows to spot outliers, not read individual cells carefully.

### 5.3 Interactions
*   **Row Selection:** Checkbox-based multi-select for batch operations. Shift-click for range selection.
*   **No "Drill-Down":** Avoid navigating away from the list. All data is surface-level.
*   **Long Press → Web UI:** Long-press or right-click on a row opens the miner's HTTP management interface in the browser.
*   **Column Sorting:** Click column headers to sort ascending/descending.
*   **Search & Filter Bar:** Text search by IP, model, or worker name. Quick toggle filters: "Active Only", "Warnings Only".

### 5.4 Responsiveness & Performance
*   **Non-Blocking UI:** The UI must never freeze during network scans.
*   **Progress Feedback:** Real-time counter of active scans.
*   **Staggered Execution Feedback:** visual progress bar showing the progress of batch operations (e.g. "Rebooting: 20/50 complete").
*   **Minimum Window Size:** 1024×768.

### 5.5 Scannability (High-Density Layout)
*   **Wide Table Support:** The UI must support horizontal scrolling for 15+ columns.
*   **Compact Rows:** Minimized whitespace to show maximum miners per screen height.
*   **Visual Anchors:** Bold IP addresses and color-coded Status icons to help the eye traverse long rows.
*   **Sticky Headers:** Column headers remain visible while scrolling.

---

## 6. Success Metrics for the Demo
*   **Speed:** Scan 254 IPs in under 10 seconds.
*   **Stability:** No crashes when encountering non-miner hardware on the network.
*   **Accuracy:** Hashrate shown in the tool matches the miner's web dashboard.
*   **Usability:** An operator can identify all unhealthy miners in a 100-device fleet within 5 seconds of scan completion.

---

## 7. Roadmap

### Completed (v0.1 — Weeks 1–2)
| Focus | Status |
| :--- | :--- |
| TCP scanner with concurrent probing | ✅ Done |
| CGMiner JSON-RPC client (summary, stats, pools, version) | ✅ Done |
| Flutter ↔ Rust FFI bridge via `flutter_rust_bridge` | ✅ Done |
| Main dashboard data table with sortable columns | ✅ Done |
| Scanner control panel with IP range input | ✅ Done |
| Miner detail data logic (thermals, fans, pools, system info) | ✅ Done (UI Deprecated) |
| Batch commands: Reboot + Blink LED | ✅ Done |
| Auto-identification: model, firmware, MAC address | ✅ Done |

### Next (v0.2 — UI/UX Polish)
| Focus | Priority |
| :--- | :--- |
| Status bar with fleet summary counts | High |
| Color-coded row backgrounds for warnings/dead miners | High |
| Column sorting (clickable headers) | High |
| Search/filter bar (IP, model, worker) | Medium |
| Sticky column headers | Medium |
| Collapsible scanner panel | Medium |
| Real-time scan progress (count updates) | Medium |
| **Staggered Batch Execution Logic** | **High** |
| **Wide Data Grid (All Columns)** | **High** |

### Future (v0.3+ — Advanced Features)
| Focus | Priority |
| :--- | :--- |
| Batch pool configuration panel | High |
| IP range list management (+/− saved ranges) | Medium |
| Export to CSV | Medium |
| Auto-refresh / monitoring loop integration | Medium |
| Power control (LPM toggling) | Low |
| Overclock/underclock profiles | Low |
| Historical data & trend charts | Low |
| Desktop notifications for alerts | Low |