---
name: wuji-cli-upgrade
description: "Upgrade Wuji device firmware with wuji upgrade: check which devices have updates (--check), upgrade one or all devices to the latest release, install a specific version (--to), flash a local firmware package (--file), and browse the firmware catalog (--list). Use when the user wants to upgrade, downgrade, or re-flash device firmware, or asks whether firmware updates are available."
metadata:
  author: wuji-technology
  version: "1.0"
  requires:
    bins: ["wuji"]
  cliHelp: "wuji upgrade --help"
---

`wuji upgrade` fetches firmware from the official catalog, flashes it over the connected transport, and prints a per-device report. The device reboots into the new firmware automatically.

## Mental Model: Scope × Action

Every invocation is a **scope** (which devices) combined with an **action** (what to do). Running `wuji upgrade` with no arguments prints help — flashing never happens implicitly.

Scope (defaults to the only connected device):

- `--all` — every discovered device (latest firmware only)
- `--type <TYPE>` — every device of one type (matches `ping`'s Device Type, case-insensitive)
- `--sn` / `--address` / `--handedness` — one device, same selectors as other commands

Actions:

- `--check` — update overview, read-only, works with **any** scope
- *(no action flag)* — upgrade the scoped devices to their latest catalog version
- `--to <VERSION>` — install a specific catalog version
- `--file <PATH>` — flash a local firmware file
- `--list` — browse the firmware catalog, read-only

A version only makes sense for one device type, so `--to`, `--file`, and `--list` require a single-type scope: `--type` or one device. `--all` always means "latest for each device".

## Usage

```bash
wuji upgrade --check                        # Which devices have updates (read-only)
wuji upgrade --all                          # Upgrade every device to its latest
wuji upgrade --sn <SN>                      # Upgrade one device to its latest
wuji upgrade --sn <SN> --to 0.11.0          # Install a specific version
wuji upgrade --type WujiGlove --to 0.11.0   # Install a version on every glove
wuji upgrade --sn <SN> --list               # List firmware versions for one device
wuji upgrade --file fw.zip                  # Flash a local package
```

Without a device selector, single-device actions auto-pick the only connected device; if several are on the bus, the CLI errors out listing candidate SNs.

## Safety Semantics

- Flashing always shows a confirmation prompt with firmware version, size, and the version transition for each device. `-y` / `--yes` skips it.
- A device already on the target version is skipped. Use `--force` to downgrade a device ahead of the latest catalog version.
- Downgrading to an older version via `--to` or `--file` is allowed; the confirmation prompt flags it with `⚠ DOWNGRADE`.
- `--file` supports official `.zip` packages (verified automatically) and raw `.bin` files (flashed as-is).

## Reading the Report

- Per-device `Status`: `ok` / `skipped` / `failed`; the `Detail` column carries the failure reason or skip note
- Exit code: 0 unless a device **failed** (skipped devices don't fail), directly usable in scripts
- `--check` exits 0 whether or not updates exist (only a query failure exits 1); gate on the JSON `status` field instead

## Examples

`wuji upgrade --check` gives a read-only overview of all devices:

```bash
$ wuji upgrade --check
1/2 device(s) have updates available
┌──────────────────┬─────────────┬─────────┬────────┬──────────────────┐
│ SN               ┆ Device Type ┆ Current ┆ Latest ┆ Status           │
╞══════════════════╪═════════════╪═════════╪════════╪══════════════════╡
│ WG1KXXXXXXXXXX01 ┆ WujiGlove   ┆ 0.11.0  ┆ 0.11.1 ┆ update available │
├╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌┼╌╌╌╌╌╌╌╌╌╌╌╌╌┼╌╌╌╌╌╌╌╌╌┼╌╌╌╌╌╌╌╌┼╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌┤
│ WG1KXXXXXXXXXX02 ┆ WujiGlove   ┆ 0.11.1  ┆ 0.11.1 ┆ up to date       │
└──────────────────┴─────────────┴─────────┴────────┴──────────────────┘
```

`wuji upgrade --all` confirms the plan, then flashes each device in turn and prints a report:

```bash
$ wuji upgrade --all
firmware: 0.11.1 (157.15 KiB, released 2026-06-24)
  - Fixed an incorrect IMU initialization warning.
device(s) to upgrade (2):
  WG1KXXXXXXXXXX01 (0.11.0 → 0.11.1)
  WG1KXXXXXXXXXX02 (0.11.0 → 0.11.1)
proceed? [y/N] y

2 upgraded (2 device(s))
┌──────────────────┬────────┬────────┬────────┬──────────┐
│ SN               ┆ Status ┆ Before ┆ After  ┆ Duration │
╞══════════════════╪════════╪════════╪════════╪══════════╡
│ WG1KXXXXXXXXXX01 ┆ ok     ┆ 0.11.0 ┆ 0.11.1 ┆ 16s      │
├╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌┼╌╌╌╌╌╌╌╌┼╌╌╌╌╌╌╌╌┼╌╌╌╌╌╌╌╌┼╌╌╌╌╌╌╌╌╌╌┤
│ WG1KXXXXXXXXXX02 ┆ ok     ┆ 0.11.0 ┆ 0.11.1 ┆ 16s      │
└──────────────────┴────────┴────────┴────────┴──────────┘
```

Devices already on the target version are skipped, and the Detail column says why:

```bash
$ wuji upgrade --all --yes
0 upgraded, 2 skipped (2 device(s))
┌──────────────────┬─────────┬────────┬───────┬──────────┬─────────────────────┐
│ SN               ┆ Status  ┆ Before ┆ After ┆ Duration ┆ Detail              │
╞══════════════════╪═════════╪════════╪═══════╪══════════╪═════════════════════╡
│ WG1KXXXXXXXXXX02 ┆ skipped ┆ 0.11.1 ┆ -     ┆ -        ┆ already on 0.11.1   │
├╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌┼╌╌╌╌╌╌╌╌┼╌╌╌╌╌╌╌╌┼╌╌╌╌╌╌╌┼╌╌╌╌╌╌╌╌╌╌┼╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌┤
│ WG1KXXXXXXXXXX01 ┆ skipped ┆ 0.11.1 ┆ -     ┆ -        ┆ already on 0.11.1   │
└──────────────────┴─────────┴────────┴───────┴──────────┴─────────────────────┘
```

Installing a version below the current one is flagged in the prompt:

```bash
$ wuji upgrade --sn WG1KXXXXXXXXXX01 --to 0.11.0
firmware: 0.11.0 (155.68 KiB, released 2026-06-18)
  - Updated tactile output to the new 24×31 matrix format.
device(s) to upgrade (1):
  WG1KXXXXXXXXXX01 (0.11.1 → 0.11.0)  ⚠ DOWNGRADE
proceed? [y/N]
```

`wuji upgrade --sn <SN> --list` shows the catalog for that device, newest first:

```bash
$ wuji upgrade --sn WG1KXXXXXXXXXX01 --list
WG1KXXXXXXXXXX01 (current: 0.11.1)
┌─────────────────┬────────────┬────────────┬──────────────────────────────────┐
│ Version         ┆ Released   ┆ Size       ┆ Notes                            │
╞═════════════════╪════════════╪════════════╪══════════════════════════════════╡
│ 0.11.1 (latest, ┆ 2026-06-24 ┆ 157.15 KiB ┆ Fixed an incorrect IMU           │
│ current)        ┆            ┆            ┆ initialization warning.          │
├╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌┼╌╌╌╌╌╌╌╌╌╌╌╌┼╌╌╌╌╌╌╌╌╌╌╌╌┼╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌┤
│ 0.11.0          ┆ 2026-06-18 ┆ 155.68 KiB ┆ Updated tactile output to the    │
│                 ┆            ┆            ┆ new 24×31 matrix format.         │
├╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌┼╌╌╌╌╌╌╌╌╌╌╌╌┼╌╌╌╌╌╌╌╌╌╌╌╌┼╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌┤
│ 0.10.1          ┆ 2026-04-28 ┆ 152.27 KiB ┆ Fixed some known issues.         │
└─────────────────┴────────────┴────────────┴──────────────────────────────────┘
```

For scripting, add `--json` (flashing also needs `--yes`); the report carries the same fields as the tables above.
