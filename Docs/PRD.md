# PRD: "Bit-Link" Miner Manager (BTC Tools Replica)

## 1. Project Objective
To build a high-performance, cross-platform desktop application that discovers, monitors, and manages Bitcoin ASIC miners (Antminer, Whatsminer, etc.) within a local network. The goal is to demonstrate proficiency in concurrency (Go/Rust) and cross-platform UI (Flutter).

---

## 2. Target Audience
*   **Primary:** Mine operators who need to monitor hardware health and performance in real-time.
*   **Environment:** Industrial warehouses with high-density networking and hardware.

---

## 3. Core Features (The "One-Week" Scope)

### Phase 1: Network Discovery (High Priority)
*   **IP Range Scanning:** User can input an IP range (e.g., `192.168.1.1` to `192.168.1.255`).
*   **High-Speed Probing:** Use a multi-threaded/concurrent scanner to check for open port `4028` (default for CGMiner/BMiner API).
*   **Auto-Identification:** Identify the miner model and firmware version upon connection.

### Phase 2: Real-Time Monitoring (High Priority)
**Health Dashboard:** A list/table view showing:
*   **IP Address & Status:** Active, Warning, Dead.
*   **Hashrate:** Real-time (RT) vs. Average (Avg).
*   **Temperature:** PCB and Chip temperatures.
*   **Fan Speed:** RPM for all fans.
*   **Uptime:** How long the miner has been running.
*   **Visual Indicators:** Color-coded status (e.g., Red for high temp or low hashrate).

### Phase 3: Basic Batch Control (Medium Priority)
*   **Reboot:** Ability to send a reboot command to selected miners.
*   **Locate:** Trigger the "Flash LED" command to find a specific miner in a physical rack.

---

## 4. Technical Architecture

### Backend (The "Engine")
*   **Language:** Go (recommended for rapid development) or Rust (recommended for performance/safety).
*   **Communication:**
    *   **TCP Sockets:** Direct communication with miners via JSON-RPC over TCP.
*   **Concurrency:** Use goroutines or tokio to handle hundreds of concurrent socket connections without blocking the UI.
*   **Data Bridge:** A lightweight local API (REST or WebSockets) or a Foreign Function Interface (FFI) to send data to Flutter.

### Frontend (The "Cockpit")
*   **Framework:** Flutter for Desktop.
*   **State Management:** Use `Provider` or `Riverpod` to handle real-time stream updates from the backend.
*   **Components:**
    *   `DataGrid` for the miner list.
    *   Search/Filter bar for large deployments.

---

## 5. UI/UX Requirements
*   **Dark Mode:** Standard for "engineering" tools; easier on the eyes in warehouse environments.
*   **Scannability:** Information must be readable from a distance (large hashrate numbers).
*   **Responsiveness:** The UI must not "freeze" while the network scan is running.

---

## 6. Success Metrics for the Demo
*   **Speed:** Scan 254 IPs in under 10 seconds.
*   **Stability:** No crashes when encountering non-miner hardware on the network.
*   **Accuracy:** Hashrate shown in the tool matches the miner’s web dashboard.

---

## 7. 1-Week Roadmap

| Day | Focus | Milestone |
| :--- | :--- | :--- |
| **1-2** | Backend Logic | TCP scanner functional; can pull JSON from one miner. |
| **3** | Concurrency | Can pull data from multiple IPs simultaneously. |
| **4** | The Bridge | Establish communication between Go/Rust and Flutter. |
| **5** | UI Layout | Build the main dashboard table in Flutter. |
| **6** | Refinement | Add sorting, filtering, and "Reboot" button logic. |
| **7** | Testing | Virtual testing (using a miner simulator) and polish. |