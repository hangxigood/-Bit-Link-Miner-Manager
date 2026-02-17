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
