# Project Backlog: Bit-Link Miner Manager

This document tracks the execution status of features defined in [PRD.md](PRD.md) and [TechnicalDesign.md](TechnicalDesign.md).

## 🟢 Completed (Done)

### Phase 1: Foundation & Discovery
- [x] **Project Setup**: Rust backend + Flutter frontend with `flutter_rust_bridge`.
- [x] **Network Scanner**:
    - [x] TCP handshake on port 4028.
    - [x] Concurrent scanning (tokio::spawn + Semaphore).
    - [x] Auto-Range Detection (local interface enumeration).
    - [x] IP Range Management (Add/Remove CIDR ranges).
- [x] **Protocol Implementation**:
    - [x] CGMiner JSON-RPC client.
    - [x] Parsing logic for Antminer (MHS av) vs Whatsminer (HS 5s).
    - [x] Trailing null byte handling.
- [x] **Device Identification**:
    - [x] Model, Firmware Version extraction.
    - [x] MAC Address lookup (ARP table).

### Phase 2: Monitoring & Control
- [x] **Real-Time Monitor**:
    - [x] Background polling loop (default 10s).
    - [x] State diffing and event broadcasting.
- [x] **Batch Commands**:
    - [x] **Reboot**: HTTP Digest Auth support.
    - [x] **Blink LED**: Toggling physical locator light.
    - [x] **Staggered Execution**: Backend logic for batch delays.

### Phase 3: UI/UX (Frontend)
- [x] **Dashboard Shell**: Collapsible sidebar, Header bar.
- [x] **Miner Data Table**:
    - [x] Sortable columns.
    - [x] Dense layout with status colors.
    - [x] Multi-selection (Checkbox).
    - [x] **Direct Drill-down**: Click row to open miner Web UI.
- [x] **Sidebar Controls**:
    - [x] IP Range Input section.
    - [x] Pool Configuration UI (Visual only).

### Phase 4: Documentation
- [x] **Refactor Docs**: Converted PRD/Tech Design to "Source of Truth" (Removed ephemeral status).
- [x] **Protocol Specs**: Documented parsing logic in Appendix A.

### Phase 3.5: Data Grid Enhancements
- [x] **Data Grid**:
    - [x] **Reorderable Columns**: Settings Dialog with drag-and-drop.
    - [x] **Persistence**: Saved column visibility/order (shared_preferences).
    - [x] **Resizable Columns**: Drag column headers to resize.
    - [x] **Locate Toggle**: Boolean switch column (Blink ON/OFF).
    - [x] **Fan Speed Display**: Fixed width/formatting with fit-to-content.
- [x] **Temperature Data**:
    - [x] Split into `Inlet Temp` and `Outlet Temp` columns.
    - [x] Formatted as `min | max`.
- [x] **UX Improvements**:
    - [x] **Auto Scan Button**: Renamed to "Detect".
    - [x] **Locate Toggle Refactor**: Remove global button, rely on selection-aware table toggles.
    - [x] **ActionController**: Refactored for testability and bug fixes.

### Phase 5: Configuration & Backend APIs
- [x] **Antminer HTTP API**:
    - [x] Pool configuration (`set_miner_pools`, `get_miner_pools`).
    - [x] Power mode control (`set_miner_power_mode`) — Normal / LPM.
    - [x] HTTP Digest Auth via `AntminerWebClient`.
- [x] **Whatsminer LuCI HTTPS API**:
    - [x] LuCI login + CSRF token extraction.
    - [x] Pool configuration via form POST.
    - [x] Reboot + LED control.
    - [x] Power mode dispatch (`WhatsminerWebClient`).
- [x] **Configurable Credentials**: Settings UI for per-brand username/password.
- [x] **FFI Models Expanded**: `PoolConfig`, `WorkerSuffix`, `MinerCommand` sealed variants.
- [x] **Frontend Wiring**: Batch config actions connected to sidebar, Action Bar.

### Phase 6: Rebranding & Polish
- [x] **Rebranding (GreatTool)**:
    - [x] App title, window title, "About" dialog updated.
    - [x] Theme: Teal `#0DCBA3`, Deep Navy `#201C3D`, Greyish Blue `#515A6E`.
    - [x] Custom `SnackBar` theme (Success/Error toast with rounded design).

### Phase 7: CI & Windows Build
- [x] **GitHub Actions Workflow**: Windows CI build pipeline.
- [x] **Windows ARP Fix**: Platform-specific MAC address lookup branch.
- [x] **TLS**: Switched to `native-tls` for Windows (`reqwest`).
- [x] **MSVC Toolchain**: Windows build uses MSVC Rust toolchain.
- [x] **FRB Generated Files**: Committed to repo so Windows CI compiles without code generator.
- [x] **Scanner Windows Flash Fix**: Prevent console windows flashing on Windows during scan.

---

## 🟡 In Progress / Next Up (v0.6)

### Testing
- [ ] **Frontend Widget Tests**: Create `MinerDataTable` test suite to verify rendering without backend.
- [ ] **Integration Tests**: Verify full scan→monitor flow in CI environment.

---

## 🔴 Backlog (To Do)

### Bug Fixes
- [ ] **MAC Address on Windows**: MAC address not showing in the data table on Windows — investigate ARP lookup result propagation to the UI.

### Feature: UX / Data Table
- [x] **Horizontal Scrollbar**: Add a visible left-to-right scrollbar on the data table so users without a touchpad can scroll all columns.
- [ ] **Row-Drag Multi-Select**: Allow users to click-and-drag the mouse to select multiple rows at once; show selected miner count in the UI (checkbox multi-select already exists).
- [ ] **Power Mode Column**: Add a `Power Mode` column to the data table (Normal / LPM / Sleep / etc.).
- [ ] **Temperature Column (Config View)**: New column type showing real-time temperature in the configuration panel.
- [ ] **Fan Speed Column (Config View)**: New column type showing all fan speeds divided by `/` (e.g. `3120/3240/3180`).
- [ ] **Log Link Column**: Add a `Log Link` column to the data table (e.g. `http://192.168.56.32/#blog`).

### Feature: Action Bar
- [ ] **Locate All Button**: Button in action bar to locate (blink LED) every miner in the list.
- [ ] **Locate Selected Button**: Button in action bar to locate (blink LED) only the currently selected miners.

### Feature: Configuration / Toast UX
- [ ] **Persistent Toast Messages**: Keep configuration toast messages visible (spinner/pending state) until the backend result arrives — similar to how pool setting success/failure is surfaced. Do not auto-dismiss before the result is known.

### Feature: App Identity
- [ ] **App Icon**: Replace the default Flutter/Electron icon with the GreatTool / Bit-Link branded icon (matching the header logo).
- [ ] **App Name**: Change the executable/window title from `frontend` to the correct product name.

### Feature: Batch Configuration (Remaining)
- [ ] **Worker Suffix Logic**: Wire up IP-based worker-suffix appending in pool config.
- [ ] **Frequency Scaling**: Overclock/Underclock profiles.

### Feature: Data Management
- [ ] **Export to CSV**: Button to dump current `MinerDataTable` to `.csv` file.
- [ ] **Historical Data**:
    - [ ] SQLite integration for storing hashrate history (24h/7d).
    - [ ] Simple sparkline charts in UI.

### Feature: Advanced UI
- [ ] **Search & Filter**:
    - [ ] Text search (IP, Model).
    - [ ] Quick Filters (Show only Warning/Offline).
- [ ] **Sticky Headers**: Keep table headers visible during scroll.
