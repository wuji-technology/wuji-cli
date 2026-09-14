---
name: wuji-cli-record
description: "Use this skill to record an already running Wuji Glove to Hand 2 teleoperation session, inspect managed recording history, or export a selected recording into a support bundle with the wuji CLI. Do not use it to start teleoperation or publish control commands."
metadata:
  author: wuji-technology
  version: "2026.9.14"
  cliHelp: "wuji record --help"
compatibility: Requires the wuji CLI binary.
---

## Mental Model

`wuji record teleop` is a foreground, read-only observer. Start the existing Glove to Hand 2 teleoperation program first, then run recording in a second terminal. The recorder attaches to the owner's shared device sessions and never publishes commands or takes over a disconnected device.

The managed MCAP contains the fixed teleoperation preset: Glove `emf_poses` and `hand_skeleton`, global `tf` and `tf_static`, Hand 2 `joint_command` and `joint_states`, plus `joint_diagnostics` when available.

## Record Teleoperation

```bash
# Unique active Glove + Hand 2 pair
wuji record teleop

# Select an explicit pair when multiple devices are active
wuji record teleop --glove <GLOVE_SN> --hand <HAND_SN>
```

Stop recording with `Ctrl+C`, or send exactly one `SIGTERM` with `kill <PID>`; then wait for the final `stopped` report. Do not send another `Ctrl+C` or `SIGTERM`, cancel the command, or kill the process while the MCAP is finalizing. A second signal during finalization forces an exit with code 130 and may leave an unfinalized partial recording. The CLI normally finalizes MCAP, updates the manifest, detaches both read-only sessions, and leaves the teleoperation owner running. `kill -9` cannot be handled and may leave an interrupted, unfinalized file.

Human TTY terminals receive a compact heartbeat at 5 Hz. Non-TTY Human output appends one every 30 seconds. `--json` emits only the final report; `--jsonl` emits `started`, periodic `progress`, and final `stopped` records.

## History and Export

```bash
wuji record list
wuji record list --days 7
wuji record list --json

wuji logs export --recording <RUN_ID> -o support.zip
```

Runs are stored under `~/.wuji/recordings/<RUN_ID>/` as `manifest.json` and `recording.mcap`. `logs export` includes recordings only when explicitly selected with repeatable `--recording`; date filtering never adds them automatically.

## Safety and Privacy

- MCAP and its manifest contain raw motion/control data and are not redacted.
- The files remain local until the user explicitly exports or shares them.
- Telemetry does not upload MCAP. Recording duration is reported only after a successful recording stop.
- A healthy recording is complete when the user presses Ctrl+C or when teleoperation itself ends. Human output includes status, duration, size, output path, and next-step commands for reviewing or exporting recordings; structured output retains additional fields.

## Common Errors

| Error | Action |
|---|---|
| `no active teleoperation session found` | Start teleoperation and confirm both devices are visible with `wuji devices`. |
| `multiple ... devices found` | Pass both `--glove <SN>` and `--hand <SN>`. |
| `failed to attach` | Ensure the teleoperation owner enables device sharing. Do not close it to let the recorder take ownership. |
| Required channel unavailable | Check that the owner, device firmware, SDK user profile, and hand model match the teleoperation setup. |
| Recording is `partial` | Read the warning lines after the four-line summary. If `recording.complete` is `true`, the finalized MCAP remains available; if it is `false`, treat the file as potentially unfinalized and do not assume it is readable. |
