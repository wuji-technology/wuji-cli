---
name: wuji-cli-viz
description: "Visualize live Wuji Hand 2 joint and fingertip tactile data with the official Rerun Web Viewer using `wuji viz`. Use when a user wants to inspect hand pose, per-taxel forces, per-finger resultant force, force history, live visualization faults, interactive multi-hand selection, or runtime tactile zeroing."
metadata:
  author: wuji-technology
  version: "1.3"
  requires:
    bins: ["wuji"]
  cliHelp: "wuji viz --help"
---

## Start a Viewer

`viz` supports Wuji Hand 2 only. Without `--sn`, it scans for Wuji Hand 2 devices:

```bash
wuji viz
```

It connects directly when exactly one hand is found. In an interactive terminal, multiple hands open a searchable selector whose summary shows SN and Device Type. The highlighted item shows Transport and Address on separate detail lines, plus USB Port or IP only when that field is present. Only the selected hand is connected. Pressing Esc or Ctrl+C at the selector writes `Cancelled.` to stderr, exits with code 9, and does not connect or fall back to another hand. A connection failure also does not fall back.

Use `wuji viz --sn <SN>` to select a specific hand. Structured output and unattended invocations require `--sn` when multiple hands are present; they never open the selector.

The command prints the viewer URL and opens it in the default browser. It keeps the device session and viewer running until Ctrl+C.

Use `--no-open` in a headless environment or when you want to open the printed URL manually:

```bash
wuji viz --no-open
```

For a machine-readable startup report, use `--json` for formatted JSON or `--jsonl` for one compact JSON line. In an Agent or other unattended session, also use `--no-zero` unless the user has explicitly confirmed that all five fingertips are unloaded:

```bash
wuji viz --sn <SN> --no-zero --no-open --jsonl
```

After the Viewer is ready, stdout emits exactly one startup report and flushes it before the command continues running:

```json
{
  "status": "running",
  "device": {
    "sn": "WH2-...",
    "handedness": "left"
  },
  "viewer": {
    "url": "http://127.0.0.1:...",
    "lan": false
  }
}
```

Live sensor frames remain in the Rerun stream; they are not written to stdout. Progress, warnings, and errors remain on stderr. A failure before Viewer readiness leaves stdout empty and writes the normal structured error envelope to stderr. A later runtime failure keeps the startup report on stdout and writes the error envelope to stderr. Ctrl+C does not add a second structured record.

The command does not record an RRD file and does not accept `--address` or `--handedness` as device selectors.

## Control Runtime Tactile Zeroing

The command zeroes the runtime tactile baseline by default. Before a person runs the default command, they must make sure all five fingertip surfaces are completely unloaded and keep them unloaded until the terminal prints `Tactile zero: ready.`

Use `--no-zero` when zeroing is not needed:

```bash
wuji viz --no-zero
```

The command checks that all five tactile sensors report the expected model and are ready, captures their current readings as the device's runtime zero baseline, and waits until all five return to `Ready`. Subscriptions and the Viewer start only after that completes. Keep every fingertip unloaded until the terminal prints `Tactile zero: ready.`

An Agent must not infer an unloaded state from live values. Unless the user explicitly confirms that all five fingertips are unloaded, the Agent must run `wuji viz --no-zero` instead of the mutating default command. A load present during zeroing becomes part of the baseline. The operation does not write the persistent tactile model. If the command reports that zeroing may be partial, stop and report the error; do not retry without user direction.

## Read the Page

The fixed Rerun layout contains:

- a 3D Wuji Hand 2 model driven by live joint states;
- per-taxel solid force arrows on the hand;
- one resultant force arrow for each finger;
- five fingertip 3D panels;
- five resultant-force magnitude series over a rolling 60-second window.

The renderer updates at 60 Hz with the latest received state. Rerun batches those updates with a 16 ms flush window. A point force of `0.2` normalized unit or `1 N` is rendered as a 20 mm arrow. A `2 N` resultant is rendered as a 6 mm arrow on the hand and a 4 mm arrow in its fingertip panel.

The Viewer opens in Rerun's dark theme by default with a solid black 3D background.

Per-taxel forces and per-finger resultants use the same solid cylinder-and-cone arrow construction. Static base taxel points remain visible beneath the force arrows. Resultant arrows are anchored at the center of the tactile surface, not at the curved taxel array's internal centroid.

## Handle Faults

Detailed warnings and errors are printed in the terminal. The Rerun page does not add an in-panel health marker:

- after a fingertip has produced a valid frame, a fault retains that frame; check the terminal for the affected finger and reason while other streams continue updating;
- a joint-stream fault retains the last valid hand pose, if any, while fingertip panels continue updating;
- missing tactile data leaves the hand pose available;
- after a device disconnect, the viewer retains the last state and waits for Ctrl+C; the command then exits with failure.

The command does not reconnect automatically.

## Share on a Trusted LAN

By default, both the Rerun stream and Web Viewer bind to loopback. To expose them on the machine's private network address:

```bash
wuji viz --lan --no-open
```

`--lan` selects a private address on the default route. If that route points to the wrong interface, select a specific local address instead:

```bash
wuji viz --bind 10.42.0.7 --no-open
```

`--lan` and `--bind` are mutually exclusive. Non-loopback access has no authentication and no TLS. Use it only on a trusted network and share the printed URL only with intended viewers. The first version supports one active viewer page; close an old page before opening another.
