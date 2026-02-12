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

---

## 🟡 In Progress (v0.5 Rebranding & Enhancements)

### Rebranding (GreatTool)
- [ ] **Name Change**: Update app title, window title, and "About" dialog to **GreatTool**.
- [ ] **Theme Update**: Apply `greatpool.ca` palette:
    - [ ] Primary: Teal (`#0DCBA3`).
    - [ ] Background: Deep Navy (`#201C3D`).
    - [ ] Text: Greyish Blue (`#515A6E`).

### Enhanced Monitoring
- [ ] **Data Grid**:
    - [ ] **Reorderable Columns**: Implement drag-and-drop for column headers.
    - [ ] **Persistence**: Save column order to local storage (shared_preferences).
    - [ ] **Locate Toggle**: Replace logic with boolean switch column (Blink ON/OFF).
- [ ] **Temperature Data**:
    - [ ] Split into `Inlet Temp` and `Outlet Temp` columns.
    - [ ] Format: `40 | 42 | 41` (Show all boards).

### Testing
- [ ] **Frontend Widget Tests**: Create `MinerDataTable` test suite to verify rendering without backend.
- [ ] **Integration Tests**: Verify full scan->monitor flow in CI environment.

---

## 🔴 Backlog (To Do)

### Feature: Batch Configuration
- [ ] **Pool Configuration**:
    - [ ] Implement backend logic to send `addpool` / `removepool` commands.
    - [ ] Wire up "Worker Suffix" logic (IP-based appending).
- [ ] **Power Control**:
    - [ ] Implement Low Power Mode (LPM) toggling.
    - [ ] Frequency scaling (Overclock/Underclock) profiles.

### Feature: Data Management
- [ ] **Export to CSV**:
    - [ ] Button to dump current `MinerDataTable` to `.csv` file.
- [ ] **Historical Data**:
    - [ ] SQLite integration for storing hashrate history (24h/7d).
    - [ ] Simple sparkline charts in UI.

### Feature: Advanced UI
- [ ] **Search & Filter**:
    - [ ] Text search (IP, Model).
    - [ ] Quick Filters (Show only Warning/Offline).
- [ ] **Sticky Headers**: Keep table headers visible during scroll.
