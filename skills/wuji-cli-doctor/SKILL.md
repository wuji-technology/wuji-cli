---
name: wuji-cli-doctor
description: "Run health self-checks on Wuji devices with wuji doctor: EMF disconnect detection (pinpoints the affected finger and tells RX faults from TX faults) and tactile sensor dead pixel / bad row / bad column detection. Use when the user reports a glove not working, abnormal sensor data, or asks for troubleshooting or a device checkup."
metadata:
  author: wuji-technology
  version: "1.1"
  requires:
    bins: ["wuji"]
  cliHelp: "wuji doctor --help"
---

`wuji doctor` connects to each device, samples real-time data (about 100 frames, done within seconds), and prints a tree-style checkup report.

Currently supported devices and fault types:

- Wuji Glove
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

- Status: ✔ pass / ! warn (informational anomaly) / ✘ fail (confirmed fault) / ~ skip
- `Tip:` lines are fix suggestions
- Exit code: 0 = no fail (warns allowed); 1 = a fail exists or diagnosis couldn't complete, directly usable in scripts
- Tactile check results are for reference only (capped at warn); verify via tactile heatmap in Wuji Studio
- Devices that fail to diagnose show up in the report as a ✘ connect & diagnose node

## Examples

```bash
$ wuji doctor

══════ Wuji Glove: WG1KXXXXXXXXXX01 ══════
├─ ✔ EMF disconnect check: all 5 fingers normal
└─ ! tactile dead-pixel check: 0 dead pixels, 0 bad rows, 0 bad cols

══════ Wuji Glove: WG1KXXXXXXXXXX02 ══════
├─ ✔ EMF disconnect check: all 5 fingers normal
└─ ! tactile dead-pixel check: 0 dead pixels, 2 bad rows, 2 bad cols
   ├─ ! Bad rows: 2 bad row(s)
   └─ ! Bad cols: 2 bad col(s)
   Tip: Tactile check result is for reference only; verify via tactile heatmap in Wuji Studio
```

`wuji doctor -v` lists every check item (passing items are hidden by default; add -v to show them all)

```bash
$ wuji doctor

══════ Wuji Glove: WG1KXXXXXXXXXXX ══════
├─ ✔ EMF disconnect check: all 5 fingers normal
└─ ! tactile dead-pixel check: 0 dead pixels, 0 bad rows, 1 bad col
   └─ ! Bad cols: 1 bad col(s)
   Tip: Tactile check result is for reference only; verify via tactile heatmap in Wuji Studio

$ wuji doctor -v

══════ Wuji Glove: WG1KXXXXXXXXXXX ══════
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
   Tip: Tactile check result is for reference only; verify via tactile heatmap in Wuji Studio
```

`wuji doctor --json` outputs the same information as the tree report in machine-readable form (one node per check item, nested via `children`), handy for scripting

```bash
$ wuji doctor --json

{
  "devices": [
    {
      "sn": "WG1KXXXXXXXXXXX",
      "children": [
        {
          "id": "emf_disconnect",
          "label": "EMF disconnect check",
          "status": "pass",
          "summary": "sampled 100 valid frames, all 5 fingers normal",
          "children": [
            {
              "label": "Thumb",
              "status": "pass",
              "summary": "100 frames all normal"
            },
...

```

See [doctor.json](references/doctor.json) for the full output
