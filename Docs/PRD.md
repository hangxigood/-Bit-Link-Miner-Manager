# Product Requirements Document (PRD): "GreatTool" Miner Manager

## 1. Product Overview
**GreatTool** is a high-performance desktop application for discovering, monitoring, and managing Bitcoin ASIC miners on a local network. It is designed for high-density industrial environments (100–1000+ devices).

**Core Philosophy:**
1.  **Speed**: Scan thousands of IPs in seconds.
2.  **Density**: "Single Pane of Glass" monitoring without drill-down navigation.
3.  **Safety**: Staggered execution of power commands to prevent electrical surges.

---

## 2. Functional Requirements

### 2.1 Feature: Network Discovery
**Goal:** Identify all active miners on the network, regardless of their current IP configuration.

*   **IP Range Scanning**:
    *   **Input**: The system accepts CIDR notation (e.g., `192.168.1.0/24`) or Range notation (`192.168.1.1-192.168.1.254`).
    *   **Logic**: The system attempts TCP connections on port **4028** (standard CGMiner port).
    *   **Concurrency**: Scans are performed in parallel with a configurable concurrency limit (default: 100) to ensure speed without flooding the network.

*   **Auto-Range Detection**:
    *   **Trigger**: User clicks "Auto" in the range input section.
    *   **Behavior**: The system enumerates all local network interfaces and automatically populates the scan input with the local subnets (e.g., if the machine is `10.0.0.5/24`, it adds `10.0.0.0/24`).

*   **Device Identification**:
    *   Upon successful TCP handshake, the system queries the miner for:
        *   **Make/Model** (e.g., Antminer S19, Whatsminer M30S)
        *   **MAC Address** (Unique Identifier)
        *   **Firmware Version**

### 2.2 Feature: Real-Time Monitoring
**Goal:** Provide a live, sortable, filterable view of the entire fleet's health.

*   **Data Grid View**: active miners are displayed in a high-density table.
    *   **Customizable Columns**: Users can drag-to-reorder columns. The order **MUST** be persisted between sessions.
    *   **Resizable Columns**: Users can drag to resize column widths. Widths **MUST** be persisted.
    *   **Temperature Format**: 
        *   Split into two columns: **Inlet Temp** and **Outlet Temp**.
        *   Each column displays individual board temps separated by pipes (e.g., `40 | 42 | 41`).
    *   **Locate Toggle**: 
        *   Replaces the old "Locate" button.
        *   A boolean switch column directly in the grid.
        *   **ON**: Sends `blink_led: true`.
        *   **OFF**: Sends `blink_led: false`.

*   **Miner Status Definitions**:
    The system assigns one of the following states to each device:
    *   **🟢 Active**: Responding to API, Hashrate > 90% of target, Temps < 85°C.
    *   **⚠️ Warning**: Responding, but Hashrate < 90% OR Temp > 85°C OR Fan Speed < 1000 RPM.
    *   **🔴 Dead/Offline**: Failed to respond to 3 consecutive API polls.
    *   **🔵 Scanning**: Discovery in progress.

*   **Polling Loop**:
    *   The system polls all known IPs at a configurable interval (Default: 10s).
    *   State changes (diffs) are broadcast to the UI immediately.

### 2.3 Feature: Batch Operations & Safety
**Goal:** Execute commands on multiple miners without causing infrastructure failure.

*   **Batch Selection**: Users can select miners via checkboxes:
    *   **Range Select**: Shift+Click to select a block of rows.
    *   **Select All/None**: Global toggle.

*   **Commands**:
    *   **Reboot**: Restarts the mining software/hardware.
    *   **Pool Config** (Future): Sets Stratum URL and Worker User/Pass.

*   **🚨 Safety: Staggered Execution**:
    *   **Problem**: Rebooting 500 miners at once causes a massive power surge (inrush current) that can trip breakers.
    *   **Requirement**: For power-intensive commands (Reboot, Power Mode), the system **MUST** offer a "Staggered" mode.
    *   **Logic**:
        1.  User selects N miners.
        2.  System prompts for **Batch Size** (e.g., 10) and **Delay** (e.g., 5s).
        3.  System executes command on first 10 -> Waits 5s -> Executes on next 10.
        4.  Progress (Success/Fail count) is shown in a modal dialog.
        5.  User can **Cancel** the remaining queue at any time.

---

## 3. UI/UX Requirements

### 3.1 Visual Language
*   **Theme**: "GreatPool" Theme (derived from `greatpool.ca`).
    *   **Primary Brand**: Teal (`#0DCBA3`) - Highlights, Active States, Toggles.
    *   **Background (Dark)**: Deep Navy (`#201C3D`) - App Headers, Sidebar.
    *   **Background (Light)**: White (`#FFFFFF`) - Data Grid background.
    *   **Text**: Greyish Blue (`#515A6E`).
    *   **Toast / Notifications**:
        *   Must use semantic colors (Success/Error/Info) with high contrast.
        *   Should appear as floating cards (Snackbars) with rounded corners, consistent with the Material 3 design but using brand colors.
*   **Color Coding**:
    *   **Hashrate**: Normal text color (Normal), Red (Low).
    *   **Temp**: Green (<70°C), Orange (70-85°C), Red (>85°C).
*   **Density**:
    *   Row height should be minimized to fit maximum devices on screen.
    *   Font should be monospaced for all numerical data to ensure alignment.

### 3.2 Layout Structure
*   **Sidebar**: Contains configuration (Ranges, Pools, Global Settings). Collapsible.
*   **Main Area**: The Data Grid.
*   **Status Bar**: Global counters (Total, Online, Offline, Network Hashrate).
*   **Action Bar**: Context-aware buttons that appear when rows are selected.

---

## 4. Non-Functional Requirements
*   **Platform**: macOS, Windows, Linux (via Flutter).
*   **Performance**: UI must typically render at 60fps even with 1000+ rows updating every 10s.
*   **Network**: The scanner must respect OS file descriptor limits (using semaphores) to prevent crashing the network stack.
*   **Sandboxing**: On macOS, the App Sandbox must be configured to allow outgoing TCP connections (`com.apple.security.network.client`).