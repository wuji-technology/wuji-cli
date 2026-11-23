---
name: wuji-cli-base
description: "Interact with Wuji devices (data gloves / dexterous hands) via the wuji CLI: list devices with status and firmware (device list, aliases devices / ping), read and write device parameters (get/set), and subscribe to real-time data such as EMF, tactile, and IMU (sub). Use when you need to check device status, read sensor data, change device configuration, or write device automation scripts. For live Wuji Hand 2 visualization, see wuji-cli-viz. For device health diagnostics, see wuji-cli-doctor. For firmware upgrades, see wuji-cli-upgrade."
compatibility: Requires Wuji CLI installed with the wuji executable available on PATH. Run `wuji update --skills` first so these skills match the installed CLI version.
metadata:
  author: wuji-technology
  version: "2026.11.23"
  requires:
    bins:
      - wuji
  cliHelp: "wuji --help"
---

## Before running commands

Sync these skills to the installed CLI version:

```bash
wuji update --skills
```

When the local skills already match the CLI version, the command installs nothing, but it still reports stale Skills directories and automatically moves them out of `~/.agents/skills` (see the Stale Skill Directories section below). It exits non-zero only when the sync fails to converge.

## Mental Model

- **Stateless**: each command runs connect → operate → disconnect on its own. No connection persists between commands, so there's no separate "connect" step.
- **Single occupancy**: device firmware allows only one direct session at a time. When a host app (such as Wuji Studio) holds the device, the CLI automatically falls back to read-only access through the Zenoh bridge (set writes are rejected in this mode).
- **Exit codes**: the CLI uses only seven codes. 0 = success (declining a confirmation also exits 0; `wuji device list` without `--sn` or `--address` exits 0 once the list is printed, except when the discovery scan times out, which exits 4 `no_response`, or when no device is found and no usable non-loopback IPv4 discovery subnet is available (interfaces with only IPv6 or loopback do not count), which exits 4 `no_route`); 1 = the operation failed (`doctor` reporting a Fail exits 1); 2 = fix the command, arguments, target, or add `--yes`; 3 = the device or environment state refuses the operation (`wuji device list --sn` exits 3 on an address conflict); 4 = the device is unreachable, busy, or timed out (`wuji device list --sn` exits 4 when the device is offline, busy, or unroutable, or when no non-loopback IPv4 network interface is available; `wuji device list --address` exits 4 `no_response` when the endpoint does not respond); 70 = a CLI bug; 130 = interrupted (Ctrl-C or a cancelled picker; long-running commands stop on Ctrl-C and still exit 0 when they finish normally (a `record` whose manifest ends up Completed, `sub` ending its stream, a running `viz`), only their forced stop and picker cancel differ; on a real Ctrl-C the process ends by SIGINT after its output is written, so shells stop the calling script and `$?` is 130 while Python `subprocess` reports `-2`; a cancelled picker or prompt is a plain exit status 130; on Windows the process ends with `0xC000013A`). With `--json` / `--jsonl`, a failed `wuji device list` (with `--sn`, `--address`, a scan timeout, or `no_route`) prints the `devices` list alongside the embedded `error` object (`code`, `kind`, `reason`, `message`, `hint`).
- **Errors**: in human mode stderr shows `error: <message>` and, when there is one, `hint: <command to run next>`; argument errors keep clap's native `error:`/`tip:`/`Usage:` output, and an object without an action (e.g. `wuji user`) prints its full help. When an argument is misspelled, `hint` carries the fix: the full command for a wrong subcommand (e.g. `wuji user list`), the correct spelling for a wrong option or value (e.g. `--address`), and `wuji <path> --help` when no suggestion exists; a wrong option also appends `similar: '...'` to `message`. With `--json` or `--jsonl`, stdout carries the error object `{"error":{"code","kind","reason","message","hint"}}` (pretty-printed under `--json`, one line under `--jsonl`) and stderr has no error line; `wuji viz` is the exception where argument errors follow this rule to stdout, but runtime errors after the command starts running (connection failure, first-frame timeout) write the error envelope to stderr while keeping stdout as the startup report or empty. An `error` object always comes with a non-zero exit code. Machine modes never prompt: missing authorization fails with exit 2 (`missing_yes` without `--yes`, `object_exists` when overwriting a file without `--force`). Branch on `reason` (for example `missing_yes`, `device_not_found`, `session_held`), not on the message text.

## Command Overview

| Command                    | Purpose                                                                 |
| -------------------------- | ----------------------------------------------------------------------- |
| `wuji device list`         | Scan devices and probe each one: status and firmware version (`--sn` for one device) |
| `wuji devices`             | Alias of `wuji device list --no-probe`: scan only, never opens a session |
| `wuji ping`                | Alias of `wuji device list`                                              |
| `wuji device set-ip --sn <SN> <IP[:PORT]>` | Change a network device's IP and optional data port (e.g. 192.168.1.120:7440); confirms, reboots and waits at the new address. `--no-reboot` only saves; `-y` skips confirmation; `-f` forces cross-subnet configuration |
| `wuji device reboot --sn <SN>` | Reboot a device, then verify it is back with a fixed 60-second budget; `-y` skips confirmation |
| `wuji resources`           | List readable/writable params and subscribable topics                   |
| `wuji get <path>`          | Read a parameter (auto-decoded to JSON per schema)                      |
| `wuji set <path> <value>`  | Write a parameter (`--sn` or `--address` required; value is JSON; `0x` prefix means raw hex bytes) |
| `wuji sub <topic>`         | Subscribe to real-time data (`--count N` exits after N frames)          |
| `wuji viz --sn <SN>`       | Visualize live Wuji Hand 2 data (see the wuji-cli-viz skill)            |
| `wuji calib hand-model`    | Hand model calibration (see the wuji-cli-calib skill)                  |
| `wuji calib tactile`       | Tactile contact-model calibration (see the wuji-cli-calib skill)       |
| `wuji doctor`              | Device health self-check (see the wuji-cli-doctor skill)                |
| `wuji upgrade`             | Firmware update check and upgrade (see the wuji-cli-upgrade skill)      |
| `wuji user`                | Manage SDK users and export/import calibration data (see the wuji-cli-user skill) |
| `wuji update`              | Update the CLI and its Agent Skills (`--check` checks only, `--skills` syncs Skills only) |
| `wuji completions <shell>` | Generate shell completion scripts                                       |

Add `--help` after any command to see its detailed help.

## Selecting a Device

Most commands accept one of three mutually exclusive selector modes:

```bash
--sn WG1KXXXXXXXXXXX            # By serial number (recommended, most precise)
--address 192.168.1.100:50001    # By network address (ip:port or udp://ip:port); for USB devices, use --sn
--handedness left                # Filter by handedness left/right (can combine with --type)
--type wuji_glove                # Filter by device type (e.g. wuji_glove, wuji_hand_2)
```

Without a device selector: `device list` and routine `doctor` scan **all** matching devices; `get`, `resources`, and `sub` auto-select when exactly one applicable device is found, or error out (`2 ambiguous_device`) with candidate SNs listed when multiple match; `set` always requires an explicit `--sn` or `--address`. In an interactive TTY without an explicit target, `viz` opens an interactive selector when multiple applicable devices match (auto-selecting when one matches), `calib hand-model` opens an interactive selector whenever at least one applicable device is found (or when `--handedness` / `--type` matches multiple gloves), and active `doctor` items (such as `thumb_opposition`) open an interactive selector whenever `--sn` and `--address` are omitted and at least one applicable device is found; all targets must be passed via CLI flags (no `WUJI_CLI_SN` environment variable).

## Typical Workflow

```bash
wuji devices --json                            # 1. What devices are there (scan only)
wuji device list --json                        # 2. Can they all connect (check each device's status and firmware)
wuji resources --sn <SN> --json                # 3. What params / topics are available
wuji get data_port --sn <SN> --json            # 4. Read a parameter
wuji set data_port 50001 --sn <SN>             # 5. Write a parameter (JSON value)
wuji sub tactile --sn <SN> --count 10 --jsonl  # 6. Capture 10 tactile frames
```

## Common Resources at a Glance

`wuji resources --sn <SN> --json` is the authoritative list; these are the high-frequency items:

- Common params (get/set): `hand_side`, `firmware_version`, `serial_number`, `ip_address`, `data_port` — capabilities vary by device, and the GET/SET columns in `wuji resources --sn <SN>` are authoritative
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
| `Session already exists (0x0013)` | Another process holds a direct session. Read commands use a Zenoh read-only session where the SDK supports it. Write commands exit 4 `session_held`, except firmware upgrades, which record the error in a failed device row and exit 1 |
| `device is only reachable through a Zenoh session held by another process` | The write is refused before sending the request. Release the process holding the session and retry. Firmware upgrades put this message in the device row's `error` text and exit 1 when the report contains a failed row, regardless of target count. Other write commands exit 4 `session_held` |
| `connected to wrong device: requested sn=X, got sn=Y` | Multiple devices share one address, or the scan entry is stale; rerun `wuji devices` to verify                        |
| `virtual parameter 'X' currently has no value`        | The virtual param has no default and the stateless CLI doesn't persist writes; expected behavior                      |
| `'X' does not support set. Supported operations: get` | The resource doesn't support that operation, so the CLI sends nothing to the device and exits with code 2. Check the resource's GET, SET, or SUB column in `wuji resources --sn <SN>`. With `--json` or `--jsonl`, the error object has `reason: "access_not_supported"` and also carries `path`, `operation`, `device`, and `capabilities` |
| set succeeds but `wuji devices` shows no change       | Network params such as `ip_address`/`data_port` take effect after a device reboot                                     |

Most commands support --json, which gives agents more detailed, structured output.

## Global timeout

Use `--timeout <SECONDS>` before or after the command. There is no environment-variable fallback for this option.

| Command | Default and scope |
|---|---|
| `get`, `resources`, `set` | 5 seconds for connection and each request |
| `sub` | 5 seconds for connection and the maximum gap between frames, including the first frame |
| `device list`, `ping` | 10 seconds each for discovery and probing, with independent budgets |
| `viz` | 10 seconds for connection and, after subscription setup, the first valid frame: joint or tactile data for Hand 2, hand skeleton or EMF pose for Glove (not tactile data alone). Expiry exits 4 `no_data`; normal viewing has no total time limit |
| `calib tactile` | No total time limit. An explicit value limits connection and each request; when omitted, connection and each request use the SDK defaults (about 4 seconds per UDP request) |

Commands that do not accept the global option, including `device set-ip`, `device reboot`, `upgrade`, `doctor`, `logs`, `user`, `update`, `completions`, and `calib hand-model`, exit 2 `option_not_accepted` if it is supplied. After a reboot, `device set-ip` and `device reboot` use a fixed 60-second online verification budget. `calib hand-model --timeout-s` controls its own total calibration limit and is separate from global `--timeout`.

Connection values are not a wall-clock limit for the whole command. The option controls requests and connection stages that consume the supplied timeout. Discovery on an explicit `--sn` cache miss uses SDK-managed budgets. Native Zenoh connections (`--address <IP>:7447`) can also perform SDK-managed discovery, capability negotiation, and capability-page queries outside this timeout; after a native Zenoh connection is established, GET and SET requests use the SDK retry policy (four attempts with roughly 1, 2, 4, and 5 second waits when no reply arrives), so a single request can exceed the supplied value.

## Output examples
Without --json, output is human-friendly, for example:

```bash
$ wuji device list
found 2 device(s)
SN              Device Type  Handedness Address                    Firmware Status
WG1KXXXXXXXXXXX wuji_glove   right      udp://192.168.1.100:50001  1.0.2    reachable
WH2KXXXXXXXXXXX wuji_hand_2  left       udp://192.168.1.101:50001  -        busy

$ wuji device list --sn WG1KXXXXXXXXXXX --json
{
  "devices": [
    {
      "name": null,
      "sn": "WG1KXXXXXXXXXXX",
      "device_type": "wuji_glove",
      "handedness": "right",
      "address": "udp://192.168.1.100:50001",
      "transport": "udp",
      "status": "reachable",
      "firmware_version": "1.0.2",
      "firmware_latest": null,
      "channel": null,
      "selected": true,
      "last_seen": "2026-11-10T02:47:18Z"
    }
  ]
}
```

The human table shows SN, Device Type, Handedness, Address, Firmware, and Status. `-` means unknown. Address carries the transport as a scheme (`udp://ip:port` or `zenoh://<sn>`), while USB shows the serial port. Status shows the JSON `status` value, or `unprobed` when probing did not reach a conclusion. A leading unlabeled column marks the row selected by `--sn` with `>`. `wuji devices` omits Status (JSON still carries `status`) and omits Firmware unless some row has a value.

The JSON `status` is `reachable`, `busy`, `offline`, `unroutable`, `conflict`, or `null` when no conclusion was reached. A bridged `zenoh://` row is not probed and is reported as `busy`. A device not reached within the probe budget has `null` status rather than `offline`. A probe reports `busy` on a session-occupied response without reporting the occupant's name or PID.

`transport` is lowercase (`udp`, `usb`, `zenoh`), or `null` when probing could not determine it, such as an unreachable single-address `:7447` endpoint. `address` is `udp://ip:port` for UDP and native Zenoh devices (native Zenoh uses port 7447), `zenoh://<sn>` for bridged Zenoh, or a serial port for USB. `--address` accepts `udp://ip:port` and bare `ip:port`, so UDP and native Zenoh addresses can be passed back as-is. Use `--sn` for bridged Zenoh rows. `next`, when present, suggests a follow-up command.

`wuji devices` (`--no-probe`) returns the same schema without opening sessions. Its `status` is null unless discovery already shows `conflict`, `unroutable`, or `busy`, and `firmware_version` may be null.

## Keeping the CLI and Skills Up to Date

```bash
wuji update --check --json   # {"current": ..., "latest": ..., "update_available": true/false}
wuji update                  # Download, verify, and replace the binary in place
wuji update --skills         # Sync Agent Skills to this CLI's companion version only
```

`update --check` always exits 0 when the check itself succeeds. Gate on the `update_available` JSON field instead of the exit code. A background check also runs at most once every 24 hours and prints a notice on stderr — it never blocks commands or touches stdout. Set `WUJI_NO_UPDATE_CHECK=1` to disable it.

### Checking the Exact Version

```bash
wuji --version          # Two lines: short commit and version
wuji --version --long   # Four lines: full commit, version, build target, profile
wuji --version --json   # {"version", "commit" (full sha or "unknown"), "target", "profile"}
```

The `--long` output is stable line-oriented text for scripts: each line is `key: value`, in the order `commit`, `version`, `target`, `profile`. The commit is the 40-character sha the binary was built from, or `unknown` for builds outside a Git checkout.

### Agent Skills

`wuji update` and `wuji update --skills` keep the Wuji CLI Skills in `~/.agents/skills` at or above the version that ships with your CLI. The report's `skills.status` field has three states:

| Status | Meaning |
| --- | --- |
| `up-to-date` | Installed Skills are at or above the CLI's companion version |
| `update-required` | Installed Skills are older, or their version isn't readable. Skills sync automatically after a successful binary upgrade, or run `wuji update --skills` |
| `not-installed` | No Wuji CLI Skills found. `wuji update` reports this state, and `wuji update --skills` installs them |

`wuji update --skills` syncs Skills without touching the binary, so you don't need a CLI upgrade to get Skills at the CLI's version or above. It exits 1 when Skills remain below that version after the sync, their version stays unreadable, or no official Skills remain after cleanup.

### Stale Skill Directories

After a successful binary update or Skills sync, the CLI automatically moves residual official Wuji Skills out of `~/.agents/skills` into a system temp directory. This also runs when `wuji update --skills` finds the installed Skills already match. Human TTY, non-TTY, JSON, and JSONL runs never wait for confirmation. `wuji update` doesn't accept `--yes`.

Updates move out official Wuji Skills that are no longer shipped. Custom and development Skills are left alone. Directories with a newer version, a missing version, or an unreadable version remain in place and produce a warning.

The `stale_skills` JSON field lists each directory's `name`, `action`, and applicable `version`, `path`, or `error`. It's omitted when no directories qualify. Moved entries have `"action": "moved"` and their temp path. Directories retained by the version check have `"action": "kept"`. Move failures have `"action": "failed"` and produce a warning. They don't change a successful binary update or an already matching Skills result. When removing the source directory fails after a copy, the error names the complete copy and warns that the source may be partially removed. Other failures report the system error and leave the source directory untouched. If no official Skills remain after cleanup, or their versions stay below the target, `wuji update --skills` exits 1. Run it again to install the current Skills when cleanup removed every official Skill.

```bash
wuji update --skills --json   # Sync and move residual official Skills automatically
wuji update --check           # Query versions without moving Skills
```

## Install Shell Completions (Optional)

```bash
# bash example; for zsh or PowerShell, see wuji completions --help
mkdir -p ~/.local/share/bash-completion/completions
wuji completions bash > ~/.local/share/bash-completion/completions/wuji
exec bash   # Takes effect in the current session
```
