---
name: wuji-cli-base
description: "Interact with Wuji devices (data gloves / dexterous hands) via the wuji CLI: scan for devices (devices), probe connectivity with a handshake (ping), read and write device parameters (get/set), and subscribe to real-time data such as EMF, tactile, and IMU (sub). Use when you need to check device status, read sensor data, change device configuration, or write device automation scripts. For device health diagnostics, see wuji-cli-doctor. For firmware upgrades, see wuji-cli-upgrade."
metadata:
  author: wuji-technology
  version: "1.2"
  requires:
    bins: ["wuji"]
  cliHelp: "wuji --help"
---

## Mental Model

- **Stateless**: each command runs connect → operate → disconnect on its own. No connection persists between commands, so there's no separate "connect" step.
- **Single occupancy**: device firmware allows only one direct session at a time. When a host app (such as Wuji Studio) holds the device, the CLI automatically falls back to read-only access through the Zenoh bridge (set writes are rejected in this mode).
- **Exit codes**: 0 = success; non-zero = failure (`ping` failing on any device or `doctor` reporting a Fail both exit 1), directly usable in scripts.

## Command Overview

| Command                    | Purpose                                                                 |
| -------------------------- | ----------------------------------------------------------------------- |
| `wuji devices`             | Scan and list devices (USB/UDP)                                         |
| `wuji ping`                | Handshake probe; reports SN/firmware/IP (probes all devices by default) |
| `wuji resources`           | List readable/writable params and subscribable topics                   |
| `wuji get <path>`          | Read a parameter (auto-decoded to JSON per schema)                      |
| `wuji set <path> <value>`  | Write a parameter (value is JSON; `0x` prefix means raw hex bytes)      |
| `wuji sub <topic>`         | Subscribe to real-time data (`--count N` exits after N frames)          |
| `wuji doctor`              | Device health self-check (see the wuji-cli-doctor skill)                |
| `wuji upgrade`             | Firmware update check and upgrade (see the wuji-cli-upgrade skill)      |
| `wuji update`              | Update the CLI to the latest release (`--check` checks only)            |
| `wuji completions <shell>` | Generate shell completion scripts                                       |

Add `--help` after any command to see its detailed help.

## Selecting a Device

Most commands accept one of three mutually exclusive selectors:

```bash
--sn WG1KXXXXXXXXXXX            # By serial number (recommended, most precise)
--address 192.168.1.100:50000    # By address: ip:port for UDP, /dev/ttyACM0 for USB
--handedness left                # By handedness left/right (two-handed setups)
```

Without a device selector: `ping` / `doctor` handle **all** devices; `get` / `set` / `sub` / `resources` require a specific device and error out with candidate SNs listed.

## Typical Workflow

```bash
wuji devices --json                            # 1. What devices are there
wuji ping --json                               # 2. Can they all connect (confirm SN/firmware/IP)
wuji resources --sn <SN> --json                # 3. What params / topics are available
wuji get data_port --sn <SN> --json            # 4. Read a parameter
wuji set data_port 50001 --sn <SN>             # 5. Write a parameter (JSON value)
wuji sub tactile --sn <SN> --count 10 --jsonl  # 6. Capture 10 tactile frames
```

## Common Resources at a Glance

`wuji resources --sn <SN> --json` is the authoritative list; these are the high-frequency items:

- Common params (get/set): `hand_side`, `firmware_version`, `serial_number`, `ip_address`, `data_port`
- Common topics (sub): `tactile` (tactile matrix), `emf_poses` (EMF poses), `imu_data/palm` (IMU), `tip_poses` (fingertip poses), `hand_joint_angles` (joint angles), `hand_skeleton`, `tf`

## Recording Data to Files

`--jsonl` prints one frame per line, so a pipe is all you need for lightweight recording:

```bash
wuji sub tactile --count 500 --jsonl > data/tactile.jsonl             # Silent recording
wuji sub emf_poses --count 500 --jsonl | tee data/emf.jsonl | jq      # Record and watch
```

## Common Errors and Handling

| Symptom                                               | Meaning and handling                                                                                                  |
| ----------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------- |
| `found N devices: ...`                                | No device specified and multiple are on the bus; use `--sn` as prompted                                               |
| `Session already exists (0x0013)`                     | Another process holds a direct session; with `--sn` or no target, the CLI falls back to Zenoh read-only automatically |
| `connected to wrong device: requested sn=X, got sn=Y` | Multiple devices share one address, or the scan entry is stale; rerun `wuji devices` to verify                        |
| `virtual parameter 'X' currently has no value`        | The virtual param has no default and the stateless CLI doesn't persist writes; expected behavior                      |
| set rejected (`direct_only`)                          | Currently read-only through the Zenoh bridge; retry after the direct session holder releases the device               |
| set succeeds but `wuji devices` shows no change       | Network params such as `ip_address`/`data_port` take effect after a device reboot                                     |

Most commands support --json, which gives agents more detailed, structured output.

Without --json, output is human-friendly, for example:

```bash
$ wuji devices
found 1 device(s)
┌──────────────────┬───────────┬──────────┬─────────────────────┬─────────────────────┐
│ SN               ┆ Transport ┆ USB Port ┆ IP                  ┆ Address             │
╞══════════════════╪═══════════╪══════════╪═════════════════════╪═════════════════════╡
│ WG1KXXXXXXXXXXX  ┆ Udp       ┆ -        ┆ 192.168.1.100:50001 ┆ 192.168.1.100:50001 │
└──────────────────┴───────────┴──────────┴─────────────────────┴─────────────────────┘
💡 run `wuji ping` to get device type and firmware version

$ wuji devices --json
{
  "devices": [
    {
      "sn": "WG1KXXXXXXXXXXX",
      "transport": "Udp",
      "usb_port": null,
      "ip": "192.168.1.100:50001",
      "address": "192.168.1.100:50001"
    }
  ]
}
```

Device type and firmware version are not shown here: discovery is a broadcast scan without a handshake. Use `wuji ping` to get them.

## Keeping the CLI Up to Date

```bash
wuji update --check --json   # {"current": ..., "latest": ..., "update_available": true/false}
wuji update                  # Download, verify, and replace the binary in place
```

`update --check` always exits 0 when the check itself succeeds; gate on the `update_available` JSON field instead of the exit code. A background check also runs at most once every 24 hours and prints a notice on stderr — it never blocks commands or touches stdout. Set `WUJI_NO_UPDATE_CHECK=1` to disable it.

## Install Shell Completions (Optional)

```bash
# bash example; for other shells (zsh/fish/powershell/elvish), see wuji completions --help
mkdir -p ~/.local/share/bash-completion/completions
wuji completions bash > ~/.local/share/bash-completion/completions/wuji
exec bash   # Takes effect in the current session
```
