---
name: wuji-cli-logs
description: "Export, list, dump, and locate Wuji device logs using `wuji logs`. Use when you need to collect support bundles including hand model calibration recordings (export), collect a device-side diagnostic snapshot and flash history (dump), check what log files exist (list), or find the local log directory (path). Supports date-range filtering, source filtering (sdk/studio/stderr), device communication dumps, device diagnostic snapshots, private-data redaction, and JSON output."
metadata:
  author: wuji-technology
  version: "1.3"
  requires:
    bins: ["wuji"]
  cliHelp: "wuji logs --help"
---

## Mental Model

- **Logs are local text files** written by Wuji SDK, Studio, and stderr capture, stored under `~/.wuji/logs/`. The CLI discovers and processes these files — it does not create them.
- **Three text sources**: `sdk_*.log`, `studio_*.log`, `stderr_*.log`. Device communication dumps (`device_*.bin`) are excluded by default and gated behind `--with-dump`.
- **Export produces a single ZIP** containing the selected log files, a host snapshot (`host_snapshot.json`), doctor diagnosis results (`doctor_diagnosis.json` — environment checks under `env`, device discovery and per-device checks under `device`), device snapshots + flash history (`devices/<sn>_<ts>_device.json` / `_flash.jsonl`, when devices are found), matching hand model calibration recordings, and a manifest (`manifest.json`). The snapshot and diagnosis are included even when no log files are found.
- **Calibration recordings are automatic**: runs from `~/.wuji/calibration/recordings/` that intersect the same inclusive local-date range are copied under `calibration-recordings/<run_id>/`. Partial or legacy runs with no `ended_at` are filtered as a single point at their local `started_at` date.
- **Recording manifest compatibility**: new hand-model runs use `schema_version: 2` and `calibration_type: "hand_model"`. Export also accepts schema 1 with `"ik"` and preserves every source manifest unchanged.
- **Redaction is layered**: credentials (JWT, Bearer Token, API Key, Token, License, Password, AWS Key) are always redacted. Private data (username, user paths, hostname, SSID, IPv4, MAC) is redacted by default and can be disabled via `--no-redact` (internal builds only). Calibration `.mcap` files contain raw motion data and are never redacted.
- **Exit codes**: The command returns 0 on success. It returns 1 when device diagnosis, log export, calibration recording export, device snapshot collection, or Flash collection fails in `dump` or `export`.

## Subcommands

| Subcommand         | Purpose                                              |
| ------------------ | ---------------------------------------------------- |
| `wuji logs path`   | Print the log directory path                         |
| `wuji logs list`   | List available log files with size and date          |
| `wuji logs export` | Export logs, calibration recordings, snapshot, and diagnosis into a ZIP bundle |
| `wuji logs dump`   | Collect a device-side diagnostic snapshot + flash history (Wuji Hand 2) |

## Common Usage

```bash
# Locate the log directory
wuji logs path

# List recent log files
wuji logs list
wuji logs list --days 7
wuji logs list --source sdk,studio --days 3

# Export a default bundle (last 1 day, all text sources and matching calibration runs)
wuji logs export
wuji logs export --days 7
wuji logs export --source sdk --days 3

# Include device communication dumps
wuji logs export --with-dump

# Write the ZIP to a specific path
wuji logs export -o /tmp/support-bundle.zip

# Collect a device-side diagnostic snapshot + flash history (Wuji Hand 2)
wuji logs dump                          # scan all devices
wuji logs dump --sn <SN>                # single device
wuji logs dump --sn <SN> -o /tmp/dump   # write to a directory

# JSON / JSONL output for scripting
wuji logs export --json
wuji logs export --jsonl
wuji logs list --json
wuji logs list --jsonl
wuji logs path --json
wuji logs dump --json
wuji logs dump --jsonl
```

## Default ZIP Naming

Without `-o`, the ZIP is written to the current directory as:

```text
wuji-logs-{env_id}-{timestamp}.zip
```

`env_id` is the first 6 characters of the SHA-256 of the machine ID. `timestamp` is `YYYYMMDD-HHMMSS`.

## Redaction Overview

| Layer                  | What is redacted                                              | Can be disabled?                         |
| ---------------------- | ------------------------------------------------------------- | ---------------------------------------- |
| 🔴 Credentials         | JWT, Bearer Token, API Key, Token, License, Password, AWS Key | Never                                    |
| 🟡 Private text data   | Username, user paths, hostname, SSID, IPv4, MAC                | Via `--no-redact` (internal builds only) |
| 🟢 Preserved metadata  | Device SN, firmware version, timestamps, error stacks         | Always preserved                         |
| ⚠️ Calibration motion | Nothing. `.mcap` files contain raw hand-motion data            | Not applicable                           |

Redaction applies to text log files inside the ZIP. Binary dumps (`device_*.bin`) are not redacted. The host `host_snapshot.json` redacts hostname, machine ID, and MAC address. `doctor_diagnosis.json` and device-side data actively collected from the device (`devices/*_device.json`, `devices/*_flash.jsonl`) are **not** redacted and are included as-is — the diagnosis covers software versions, OS, network interface counts, device discovery, and per-device checks (no hostname / machine ID / MAC), and device data is not host private data. Calibration `.mcap` files also contain raw motion data and are not redacted — review the bundle before sharing.

## Typical Workflow

```bash
# 1. Check what logs are available
wuji logs list --days 3

# 2. Export a support bundle with today's logs
wuji logs export -o ~/Desktop/support.zip

# 3. Inspect the bundle contents
unzip -l ~/Desktop/support.zip
# Expected structure:
#   manifest.json
#   host_snapshot.json
#   doctor_diagnosis.json
#   logs/YYYY-MM-DD/sdk_*.log
#   logs/YYYY-MM-DD/studio_*.log
#   logs/YYYY-MM-DD/stderr_*.log
#   devices/<sn>_<ts>_device.json   (device diagnostic snapshot, when devices found)
#   devices/<sn>_<ts>_flash.jsonl   (device flash history, when devices found)
#   calibration-recordings/<run_id>/manifest.json
#   calibration-recordings/<run_id>/full.mcap
#   calibration-recordings/<run_id>/steps/*.mcap  (completed steps only)
```

## Common Errors

| Symptom                                  | Meaning and handling                                                                                          |
| ---------------------------------------- | ------------------------------------------------------------------------------------------------------------- |
| `failed to scan log directory`           | Log directory does not exist or is inaccessible. The CLI still produces a bundle with snapshot and diagnosis. |
| `failed to create zip bundle`            | Output path is not writable or disk is full. Check permissions and free space.                                |
| Bundle exceeds 300 MB                    | A warning is printed. Use `--days` to narrow the date range or exclude dumps.                                 |
| `skipped (no device found)` in diagnosis | No Wuji devices were detected. The export continues with available data.                                      |

Add `--help` after any `wuji logs` subcommand to see detailed help and all available options.
