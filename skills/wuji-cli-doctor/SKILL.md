---
name: wuji-cli-doctor
description: "Run health self-checks on Wuji devices with wuji doctor: EMF disconnect detection (pinpoints the affected finger and tells RX faults from TX faults) and tactile sensor dead pixel / bad row / bad column detection, plus active diagnostic items like the Wuji Hand 2 thumb-opposition check. Use when the user reports a glove not working, abnormal sensor data, needs to verify thumb-to-finger motion, or asks for troubleshooting or a device checkup."
compatibility: Requires Wuji CLI installed with the wuji executable available on PATH. Run `wuji update --skills` first so these skills match the installed CLI version.
metadata:
  author: wuji-technology
  version: "2026.10.26"
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
wuji doctor                           # Run the default item: read-only checkup on every device
wuji doctor --sn <SN>                 # Read-only checkup on one device
wuji doctor -v                        # Show all check items (passing items hidden by default)
wuji doctor --json                    # The same information as the tree report, as structured JSON
wuji doctor --list                    # List every diagnostic item (local query, no connection)
wuji doctor ITEM [--sn <SN>]          # Run one specific item
```

Without an ITEM, `wuji doctor` runs the `default` item (the read-only checkup). Every check
`wuji doctor` can run is an item; `wuji doctor --list` lists them without connecting to a device.
In JSON output, only items with side effects carry an `effects` field (read-only items such as
`default` omit it): `moves_device` marks items that drive physical motion.

## Active Items

Active items drive the device. Run them only when the operator has prepared a clear motion area,
accepts the motion, and confirms the target serial number matches the hand in front of them.

An active item also reconfigures the hand before it drives it. Record the current effort limit and
MIT gains first (`wuji get effort_limit`, `wuji get mit_params`) — the run writes them back, and
this is the only way back if the process is killed outright (SIGKILL, power loss).

The current list contains one active item:

- `thumb_opposition` (`wuji_hand_2` only): checks `joint_states` and `joint_diagnostics`,
  confirms the serial-number hand side, then drives the index, middle, ring, and pinky in order.
  Each finger uses controller force setpoints of 2 N, 4 N, and 6 N — controller settings, not
  calibrated physical force measurements. The timeout is 120 seconds. Press Ctrl+C once to stop
  safely; the command unloads the hand before releasing the device.
  Each finger also has 10 seconds to reach the thumb. A finger that does not get there in time is
  skipped, the remaining fingers still run, and the result is `indeterminate` with that finger
  named in `summary.message`. Clear anything blocking the hand and run the item again.

```bash
wuji doctor thumb_opposition --sn <SN>
wuji doctor thumb_opposition --sn <SN> --json
wuji doctor thumb_opposition --sn <SN> --jsonl
```

In a terminal, omitting `--sn` for an active item opens a device selector filtered to applicable
devices. Read the serial number in the selection before you continue. Outside a terminal
(scripts, agents) pass `--sn` explicitly.

In human mode, an active item prints its preconditions, then waits for a `proceed? [y/N]` answer.
It sends no drive command before you answer `y`; any other answer aborts and exits 9. The `--json`
and `--jsonl` modes have no prompt: without an explicit authorization flag the item is rejected
with exit code 2 before it connects, and the error message lists the preconditions to confirm.
When that error appears, stop and confirm each listed precondition with the user before
re-running with the authorization flag the message names. Read-only items such as `default`
never require it and silently accept it.

An active item reports its result in JSON and JSONL through the envelope fields. `verdict` is
snake_case — `pass`, `fail`, `warn`, `skip`, `indeterminate`, or `unsupported` — and `summary`
carries `label`, `message`, and `next_action`. `checks` is always present; it is an empty array
when the item produced no check tree. Human mode shows a verdict label, and the per-finger table
uses uppercase status words (`PASS` / `FAIL` / `NOT_RUN`).

Verdict meanings:

- `pass`: the run completed and the hand reached a safe state.
- `fail`: the run completed and at least one check failed. The motion was carried out — this is
  not a run that stopped early.
- `indeterminate`: the run stopped before a safe verdict (failed precondition, execution error,
  Ctrl+C, or a check that could not run).
- `unsupported`: the device cannot run the item.
- `warn` / `skip`: the run finished, but a check raised an informational anomaly, or a check
  didn't apply.

Human mode writes preconditions to stderr and the final report to stdout — a verdict card plus a
per-finger table (`finger`, `status`, `force stages`) derived from the same `checks`. JSON and
JSONL modes emit no preconditions.

Exit codes: 0 = pass, 1 = fail / unsupported / timeout (including a finger skipped by the
10-second approach limit), 2 = parameter error (unknown item, missing or inapplicable `--sn`),
9 = the operator stopped the run (Ctrl+C, selector cancellation, or declining the confirmation
prompt). If the command says another program uses the device, close
that program and retry with the same serial number.

### Device parameter changes

`device_changes` reports the parameters an active item changed and could not write back: absent
means the run restored everything, present means it left the device altered. When present, the
report names each parameter and its joints and gives the values to write back:

- `param` and `targets` name the parameter and its joints
- `expected` gives the values to write back, one per joint; `null` where the original value is
  unknown

`verdict` and the exit code ignore this field. Write the values back with
`wuji set <param> <value> --sn <SN>` (see the wuji-cli-base skill); if a parameter cannot be
written from the CLI, follow the support channel (see the wuji-cli-support skill).

```json
"device_changes": {
  "unrestored": [{"param": "effort_limit", "targets": [5, 6], "reason": "readback mismatch", "expected": [1.5, 1.5]}]
}
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
├─ ✔ eth0 (192.168.1.50/24, fe80::abcd:.../64)
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

Every diagnostic item reports in the same envelope. One run reports only the item it ran
(`default` when no ITEM is given):

|Field|Meaning|
|---|---|
|`item`|Diagnostic item that produced the report (`default` for a bare `wuji doctor`)|
|`device`|Applies-to device, or `all` for items that span devices|
|`sn`|Targeted serial number; omitted when the item spans devices|
|`verdict`|`pass \| fail \| warn \| skip \| indeterminate \| unsupported`, derived from `checks`; active items report `pass` only when every check passed|
|`summary`|`{label, message, next_action}` — the one-line conclusion and what to do next|
|`checks`|Check tree (`id` / `label` / `status` / `summary` / `fix` / `children`); always present, an empty array when the item produced no tree|
|`device_changes`|Device parameters an active item changed and could not restore; absent unless the run left the device altered (see Device parameter changes)|

For `default`, `checks` holds the host-environment checks first, then one node per device result — the device-discovery node (`Generic`, added whenever a scan ran, even when no device is found) and one node per device titled `wuji_glove: <SN>`. Example:

Address nodes by `id`, not by `label`: `id` is stable and never changes once released, while
`label` is human-facing text that may be reworded. Nodes inside a device result can have no
`id`; address them by their position under the nearest parent that has one.

The example assumes discovery found a UDP device. With only USB or Zenoh devices, the discovery node and both IP checks use `"status": "skip"`, and the summary states that no UDP device was found.

```bash
$ wuji doctor --json

{
  "item": "default",
  "device": "all",
  "verdict": "warn",
  "summary": {
    "label": "Needs attention",
    "message": "The checkup completed with warnings.",
    "next_action": "Review the warnings above for details."
  },
  "checks": [
    {
      "id": "env_software",
      "label": "Software",
      "status": "warn",
      "summary": "updates available or unable to verify latest",
      "children": [
        {
          "id": "sw_cli",
          "label": "CLI",
          "status": "warn",
          "summary": "2026.8.3 (unable to check latest version)"
        },
        {
          "id": "sw_sdk",
          "label": "SDK",
          "status": "skip",
          "summary": "not installed or version undetectable (skipped)"
        },
        {
          "id": "sw_studio",
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
          "id": "env_system_os",
          "label": "OS",
          "status": "pass",
          "summary": "Ubuntu 26.04 (supported)"
        }
      ]
    },
    {
      "id": "device_generic",
      "label": "Generic",
      "status": "pass",
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
      "id": "device_wg1kxxxxxxxxxxx",
      "label": "wuji_glove: WG1KXXXXXXXXXXX",
      "status": "pass",
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
