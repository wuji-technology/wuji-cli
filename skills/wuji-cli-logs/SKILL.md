---
name: wuji-cli-logs
description: "Export, list, and locate Wuji device logs using `wuji logs`. Use when you need to collect log bundles for diagnostics (export), check what log files exist (list), or find the local log directory (path). Supports date-range filtering, source filtering (sdk/studio/stderr), device communication dumps, private-data redaction, and JSON output."
metadata:
  author: wuji-technology
  version: "1.0"
  requires:
    bins: ["wuji"]
  cliHelp: "wuji logs --help"
---

## Mental Model

- **Logs are local text files** written by Wuji SDK, Studio, and stderr capture, stored under `~/.wuji/logs/`. The CLI discovers and processes these files — it does not create them.
- **Three text sources**: `sdk_*.log`, `studio_*.log`, `stderr_*.log`. Device communication dumps (`device_*.bin`) are excluded by default and gated behind `--with-dump`.
- **Export produces a single ZIP** containing the selected log files, a host snapshot (`snapshot.json`), device diagnosis results (`diagnosis.json`), and a manifest (`manifest.json`). The snapshot and diagnosis are included even when no log files are found.
- **Redaction is layered**: credentials (JWT, Bearer Token, API Key, Token, License, Password, AWS Key) are always redacted; private data (username, user paths, hostname, SSID, IPv4, MAC) is redacted by default and can be disabled via `--no-redact` (internal builds only).
- **Exit codes**: 0 = success; 1 = any failure (device diagnosis error or log export failure).

## Subcommands

| Subcommand         | Purpose                                              |
| ------------------ | ---------------------------------------------------- |
| `wuji logs path`   | Print the log directory path                         |
| `wuji logs list`   | List available log files with size and date          |
| `wuji logs export` | Export logs + snapshot + diagnosis into a ZIP bundle |

## Common Usage

```bash
# Locate the log directory
wuji logs path

# List recent log files
wuji logs list
wuji logs list --days 7
wuji logs list --source sdk,studio --days 3

# Export a default bundle (last 1 day, all text sources)
wuji logs export
wuji logs export --days 7
wuji logs export --source sdk --days 3

# Include device communication dumps
wuji logs export --with-dump

# Write the ZIP to a specific path
wuji logs export -o /tmp/support-bundle.zip

# JSON / JSONL output for scripting
wuji logs export --json
wuji logs export --jsonl
wuji logs list --json
wuji logs list --jsonl
wuji logs path --json
```

## Default ZIP Naming

Without `-o`, the ZIP is written to the current directory as:

```text
wuji-logs-{env_id}-{timestamp}.zip
```

`env_id` is the first 6 characters of the SHA-256 of the machine ID; `timestamp` is `YYYYMMDD-HHMMSS`.

## Redaction Overview

| Layer           | What is redacted                                      | Can be disabled?                         |
| --------------- | ----------------------------------------------------- | ---------------------------------------- |
| 🔴 Credentials  | JWT, Bearer Token, API Key, Token, License, Password, AWS Key | Never                                    |
| 🟡 Private data | Username, user paths (`/home/alice`), Hostname, SSID, IPv4, MAC | Via `--no-redact` (internal builds only) |
| 🟢 Preserved    | Device SN, firmware version, timestamps, error stacks | Always preserved                         |

Redaction applies to text log files inside the ZIP. Binary dumps (`device_*.bin`) are not redacted. The host `snapshot.json` redacts hostname, machine ID, and MAC address.

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
#   snapshot.json
#   diagnosis.json
#   logs/YYYY-MM-DD/sdk_*.log
#   logs/YYYY-MM-DD/studio_*.log
#   logs/YYYY-MM-DD/stderr_*.log
```

## Common Errors

| Symptom                                  | Meaning and handling                                                                                          |
| ---------------------------------------- | ------------------------------------------------------------------------------------------------------------- |
| `failed to scan log directory`           | Log directory does not exist or is inaccessible. The CLI still produces a bundle with snapshot and diagnosis. |
| `failed to create zip bundle`            | Output path is not writable or disk is full. Check permissions and free space.                                |
| Bundle exceeds 300 MB                    | A warning is printed. Use `--days` to narrow the date range or exclude dumps.                                 |
| `skipped (no device found)` in diagnosis | No Wuji devices were detected. The export continues with available data.                                      |

Add `--help` after any `wuji logs` subcommand to see detailed help and all available options.
