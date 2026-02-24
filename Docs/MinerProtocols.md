# Miner Protocols Documentation

This document records the raw JSON responses from different miner types to guide parsing logic.

## Whatsminer (192.168.56.192)

### `version`
**Status**: Fails
**Response**:
```json
{"STATUS":"E","When":1771351973,"Code":14,"Msg":"invalid cmd","Description":"whatsminer v1.1"}
```

### `summary`
**Status**: Success
**Response**:
```json
{
  ...
  "SUMMARY": [
    {
      ...
      "MHS 5s": 41603732.68,
      "Firmware Version": "'20200725.18.REL'",
      "Chip Temp Min": 58.0,

      "Chip Temp Max": 78.28,
      "Temperature": 58.0,
      "Fan Speed In": 3810,
      "Fan Speed Out": 3780
      ...
    }
  ]
}
```

### `devdetails`
**Status**: Success
**Response**:
```json
{
  "STATUS": [{"STATUS":"S", "Msg":"Device Details", ...}],
  "DEVDETAILS": [
    {
      "Model": "M31SV10",
      ...
    }
  ]
}
```

---

## Antminer S19 XP (192.168.56.32)

### `version`
**Status**: Success
**Response**:
```json
{
  "VERSION": [
    {
      "Type": "Antminer S19 XP",
      "CompileTime": "Mon Nov 21 16:43:16 CST 2022",
      ...
    }
  ]
}
```

### `summary`
**Status**: Success
**Response**:
```json
{
  "SUMMARY": [
    {
      "GHS 5s": 135349.88,
      ...
    }
  ]
}
```

### `devdetails`
**Status**: Fails
**Response**:
```json
{"STATUS": [{"Code": 14, "Msg": "Invalid command"}]}
```

## Parsing Strategy

1.  **Initial Check**: Call `summary`.
2.  **Detection**:
    *   If `summary` contains `Firmware Version` OR "whatsminer" in description -> **Whatsminer**.
    *   Else -> **Antminer**.
3.  **Data Extraction**:
    *   **Whatsminer**:
        *   Model: Call `devdetails` -> "WhatsMiner - " + `DEVDETAILS[0].Model`.
        *   Hashrate: `SUMMARY[0]["MHS 5s"]` converted to TH/s.
        *   Temps: `SUMMARY[0]["Temperature"]` (Inlet).
        *   Software: `STATUS[0]["Description"]`.
        *   Fans: `SUMMARY[0]["Fan Speed In/Out"]`.
    *   **Antminer**:
        *   Model: Call `version` -> `VERSION[0].Type`.
        *   Hashrate: `SUMMARY[0]["GHS 5s"]` converted to TH/s.
        *   Temps/Fans: Call `stats`.

---

## Antminer HTTP API (Port 80)

Antminers expose a second API over HTTP (port 80) with **HTTP Digest Authentication**.
- **Realm**: `"antMiner Configuration"`
- **Default creds**: `root` / `root`
- **Auth flow**: Two-request handshake — send unauthenticated, get `401 + WWW-Authenticate`, resend with computed Digest header.

This API is required for operations not available via CGMiner TCP (blink, power mode, pool write).

### Endpoints

#### `GET /cgi-bin/miner_type.cgi`
Returns model and firmware version.
```json
{
  "miner_type": "Antminer S19 XP",
  "fw_version": "20221121"
}
```

#### `GET /cgi-bin/reboot.cgi`
Triggers a reboot. Returns `200 OK` on success.

#### `GET /cgi-bin/get_blink_status.cgi`
Returns current LED blink state.
```json
{ "blink": false }
```

#### `POST /cgi-bin/blink.cgi`
Sets LED blink state.
```json
// Request body
{ "blink": true }
```
Content-Type: `text/plain;charset=UTF-8` (or `application/json`)

#### `GET /cgi-bin/get_miner_conf.cgi`
Returns full miner configuration.
```json
{
  "pools": [
    {"url": "stratum+tcp://pool1.example.com:3333", "user": "wallet.worker1", "pass": "x"},
    {"url": "stratum+tcp://pool2.example.com:3333", "user": "wallet.worker2", "pass": "x"},
    {"url": "stratum+tcp://pool3.example.com:3333", "user": "wallet.worker3", "pass": "x"}
  ],
  "bitmain-fan-ctrl": false,
  "bitmain-fan-pwm": "100",
  "bitmain-work-mode": 0,
  "bitmain-freq-level": "100"
}
```
- `bitmain-work-mode`: `0` = normal, `1` = sleep

#### `POST /cgi-bin/set_miner_conf.cgi`
Writes miner configuration. Must include all fields from `get_miner_conf` (read-modify-write pattern).
```json
// Request body (same shape as get_miner_conf response, with modified fields)
{
  "pools": [
    {"url": "...", "user": "...", "pass": "x"}
  ],
  "bitmain-fan-ctrl": false,
  "bitmain-fan-pwm": "100",
  "miner-mode": 0,
  "freq-level": "100"
}
```
> ⚠️ **Pool changes trigger an automatic reboot** (2–3 min). Power mode changes also reboot.

#### `GET /cgi-bin/pools.cgi`
Reads live pool statistics (accepted, rejected, stale, difficulty, etc.).

#### `POST /cgi-bin/passwd.cgi`
Change admin password.
```json
{
  "curPwd": "root",
  "newPwd": "newpassword",
  "confirmPwd": "newpassword"
}
```
Response: `{"code": "P000"}` on success.

#### `GET http://<ip>:6060/miner_power` (S19XP Hydro, S21, S21 Pro only)
Returns current power consumption.
```
power:1234
```
(Parse as `split(':')[1]`)
