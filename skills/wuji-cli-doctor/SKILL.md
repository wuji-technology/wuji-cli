---
name: wuji-cli-doctor
description: "Run health self-checks on Wuji devices with wuji doctor: EMF disconnect detection (pinpoints the affected finger and tells RX faults from TX faults) and tactile sensor dead pixel / bad row / bad column detection. Use when the user reports a glove not working, abnormal sensor data, or asks for troubleshooting or a device checkup."
compatibility: Requires Wuji CLI installed with the wuji executable available on PATH.
metadata:
  author: wuji-technology
  version: "2026.9.21"
  requires:
    bins:
      - wuji
  cliHelp: "wuji doctor --help"
---

`wuji doctor` connects to each device, samples real-time data (about 100 frames, done within seconds), and prints a tree-style checkup report.

Currently supported devices and fault types:

- wuji_glove
  - EMF disconnect detection: pinpoints the affected finger and tells RX (receive) faults from TX (transmit) faults
  - Tactile sensor dead pixel / bad row / bad column detection (keep the glove static — don't wear or press it, or false positives may occur)

## Usage

```bash
wuji doctor                # Diagnose all devices
wuji doctor --sn <SN>      # Diagnose one device only
wuji doctor -v             # Show all check items (passing items hidden by default)
wuji doctor --json         # The same information as the tree report, as structured JSON
```

## Reading the Report

- Status: ✔ pass / ! warn (informational anomaly) / ✘ fail (confirmed fault) / ~ skip (the check didn't apply or couldn't run)
- `Tip:` lines are fix suggestions
- Exit code: 0 = no fail (warns allowed). 1 = a fail exists or diagnosis couldn't complete, directly usable in scripts. No device attached is not an error — the host-environment and discovery checks still run and determine the exit code.
- Tactile check results are for reference only (capped at warn). Verify via tactile heatmap in Wuji Studio
- Duplicate device IP and host-subnet checks run only when discovery finds a UDP device. If every device uses USB or Zenoh, both checks show `~ not attempted: no UDP devices`. These skipped checks don't make the exit code 1.
- Devices without a diagnostic recipe show a ~ connect & diagnose node. This skipped node doesn't make the exit code 1. Connection or data-collection failures still show ✘ and return 1.

## Examples

```bash
$ wuji doctor

 ══════ Environment ══════
~ Software: version info incomplete
├─ ✔ CLI: 2026.8.3 (up to date)
├─ ~ SDK: not installed or version undetectable (skipped)
└─ ✔ Studio: 2026.8.3 (up to date)

✔ System: supported
└─ ✔ OS: Ubuntu 26.04 (supported)

! Network interfaces: 2 interfaces, see interface count
├─ ✔ eth0 (192.168.1.100/24, fe80::abcd:.../64)
└─ ! Interface count: 2 interfaces — multiple interfaces may cause routing issues

══════ Generic ══════
✔ Device discovery: 2 device(s) found, no issues
├─ ✔ Devices found: 2 device(s) found
├─ ✔ Duplicate device IP
└─ ✔ Host subnet

══════ wuji_glove: WG1KXXXXXXXXXX01 ══════
├─ ✔ EMF disconnect check: all 5 fingers normal
└─ ! tactile dead-pixel check: 0 dead pixels, 0 bad rows, 0 bad cols

══════ wuji_glove: WG1KXXXXXXXXXX02 ══════
├─ ✔ EMF disconnect check: all 5 fingers normal
└─ ! tactile dead-pixel check: 0 dead pixels, 2 bad rows, 2 bad cols
   ├─ ! Bad rows: 2 bad row(s)
   └─ ! Bad cols: 2 bad col(s)
   Tip: Tactile check result is for reference only. Verify via tactile heatmap in Wuji Studio
```

`wuji doctor -v` lists every check item. Passing items are hidden by default, so add `-v` to show them all. Device sections only — the Environment / Generic sections shown above are omitted here for brevity (they are printed before the devices in real output):

```bash
$ wuji doctor

══════ wuji_glove: WG1KXXXXXXXXXXX ══════
├─ ✔ EMF disconnect check: all 5 fingers normal
└─ ! tactile dead-pixel check: 0 dead pixels, 0 bad rows, 1 bad col
   └─ ! Bad cols: 1 bad col(s)
   Tip: Tactile check result is for reference only. Verify via tactile heatmap in Wuji Studio

$ wuji doctor -v

══════ wuji_glove: WG1KXXXXXXXXXXX ══════
├─ ✔ EMF disconnect check: all 5 fingers normal
│  ├─ ✔ Thumb
│  ├─ ✔ Index
│  ├─ ✔ Middle
│  ├─ ✔ Ring
│  └─ ✔ Pinky
└─ ! tactile dead-pixel check: 0 dead pixels, 0 bad rows, 1 bad col
   ├─ ✔ Thumb
   ├─ ✔ Index
   ├─ ✔ Middle
   ├─ ✔ Ring
   ├─ ✔ Pinky
   ├─ ✔ Palm
   └─ ! Bad cols: 1 bad col(s)
   Tip: Tactile check result is for reference only. Verify via tactile heatmap in Wuji Studio
```

`wuji doctor --json` outputs the same information as the tree report in machine-readable form. The top-level object has two arrays:

- `env`: host-environment checks — software versions (CLI / SDK / Studio), system, and network interfaces, each a check node (nested via `children`)
- `device`: device-layer results — a `Generic` entry without `sn` holding the device-discovery check (added whenever a scan ran, even when no device is found), then one entry per device (`label` + `sn` + check tree)

Each array is omitted only when it is empty. `env` is always present online. `device` is present whenever a scan ran or a device was targeted. Example:

The example assumes discovery found a UDP device. With only USB or Zenoh devices, the discovery node and both IP checks use `"status": "skip"`, and the summary states that no UDP device was found.

```bash
$ wuji doctor --json

{
  "env": [
    {
      "id": "env_software",
      "label": "Software",
      "status": "warn",
      "summary": "updates available or unable to verify latest",
      "children": [
        {
          "label": "CLI",
          "status": "warn",
          "summary": "2026.8.3 (unable to check latest version)"
        },
        {
          "label": "SDK",
          "status": "skip",
          "summary": "not installed or version undetectable (skipped)"
        },
        {
          "label": "Studio",
          "status": "pass",
          "summary": "2026.8.3 (up to date)"
        }
      ]
    },
    {
      "id": "env_system",
      "label": "System",
      "status": "pass",
      "summary": "supported",
      "children": [
        {
          "label": "OS",
          "status": "pass",
          "summary": "Ubuntu 26.04 (supported)"
        }
      ]
    }
  ],
  "device": [
    {
      "label": "Generic",
      "children": [
        {
          "id": "device_discovery",
          "label": "Device discovery",
          "status": "pass",
          "summary": "1 device(s) found, no issues",
          "children": [
            {
              "label": "Devices found",
              "status": "pass",
              "summary": "1 device(s) found"
            },
            {
              "label": "Duplicate device IP",
              "status": "pass"
            },
            {
              "label": "Host subnet",
              "status": "pass"
            }
          ]
        }
      ]
    },
    {
      "label": "wuji_glove",
      "sn": "WG1KXXXXXXXXXXX",
      "children": [
        {
          "id": "emf_disconnect",
          "label": "EMF disconnect check",
          "status": "pass",
          "summary": "all 5 fingers normal",
          "children": [
            {
              "label": "Thumb",
              "status": "pass",
              "summary": "normal"
            },
            {
              "label": "Index",
              "status": "pass",
              "summary": "normal"
            },
            {
              "label": "Middle",
              "status": "pass",
              "summary": "normal"
            },
            {
              "label": "Ring",
              "status": "pass",
              "summary": "normal"
            },
            {
              "label": "Pinky",
              "status": "pass",
              "summary": "normal"
            }
          ]
        }
      ]
    }
  ]
}
```
