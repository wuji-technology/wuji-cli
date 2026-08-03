---
name: wuji-cli-calibrate
description: "Guide safe Wuji Glove calibration with the wuji CLI. Use when the user asks to run or monitor `wuji calib ik` or `wuji calib tactile`, interpret calibration progress or errors, cancel an active calibration, inspect the resulting IK model, or choose between IK and tactile calibration. Route each mode without applying IK's user-and-hand model rules to tactile's device-specific model."
---

# Wuji CLI Calibrate

Route calibration requests to the correct workflow and keep the human in the loop for physical actions and persistent model changes.

## Route the Request

- For IK calibration, follow the IK workflow in this file before executing any command.
- For tactile calibration, follow the tactile workflow in this file before executing any command.
- Keep IK and tactile semantics separate. IK publishes a model for the current SDK user and hand side; tactile calibration trains and installs a contact model for a specific glove SN.
- IK attributes the result to the user the **device** is bound to, which is resolved after connecting. If another process switches the SDK user while `wuji calib ik` is scanning or connecting, the CLI reports the switch and attributes the calibration to the bound user; if that turns out to be `Default`, it stops with exit `5` before collecting any pose. Trust the user named in the command's own output over whatever `wuji user list` says afterwards.

## Apply Shared Safety Rules

- Treat calibration as a persistent state-changing operation. Do not start it for a status, help, planning, or troubleshooting-only request.
- Before starting, state which calibration mode will run and that the human must perform the prompted physical actions. Obtain confirmation unless the user's current request already explicitly authorizes starting that mode now.
- Do not add `wuji devices` as a mandatory preflight. IK scans and connects on its own when no selector is supplied; tactile requires `--sn`. Use `wuji devices --json` only to find the requested SN or troubleshoot discovery.
- Prefer an explicit `--sn` for IK when the user has selected a device, and always provide it for tactile. Never choose one of several devices without the user identifying it.
- Keep the command attached to a streaming terminal session until it emits a terminal event and exits. Do not start a second calibration while one is active.
- On a cancellation request, send Ctrl+C once and allow the CLI to stop the SDK operation and release the device.
- Do not automatically retry a failed or cancelled calibration. Explain the failure and ask before restarting because a retry begins the physical workflow again.

## Report the Outcome

- Report the terminal status, selected device SN, model identity, and output artifact when the command provides them.
- Distinguish command failure from user cancellation. IK exit codes follow the `wuji user` convention: `0` success, `5` default-user protection, `9` cancellation, and `1` other failure. IK JSON/JSONL errors also carry a numeric `error.code`; a second Ctrl+C during tactile calibration exits immediately with code `130`.
- Never infer model ownership from device SN. Use the identity fields returned by the selected calibration mode.

## IK Calibration Workflow

Use this workflow to guide a human through `wuji calib ik` and monitor its structured progress.

### Confirm Preconditions

Before starting, confirm all of the following:

- The human intends to start IK calibration now and is ready to perform hand poses.
- The SDK is already switched to the intended named user. Check it with `wuji user show` when needed; IK calibration rejects the default user before scanning devices.
- Open the calibration pose images when visual guidance is useful: https://docs.wuji.tech/docs/zh/wuji-studio/latest/calibration
- The human understands that success publishes `left_hand.urdf` or `right_hand.urdf` for the current SDK user and hot-reloads online IK. Recalibrating the same user and hand side replaces that stable model even when a different glove is used.
- A Wuji Glove is powered and reachable over USB or the local network.

The command has no dry-run or built-in confirmation prompt. Obtain confirmation before launching it unless the user's current request explicitly says to start IK calibration now.

### Select and Start

Use no selector when the user expects the only visible glove to be calibrated:

```bash
wuji calib ik --jsonl
```

The command scans automatically. It connects the sole device, reports `no device found` for zero devices, and lists candidate SNs without connecting when several devices are found. Only after the user chooses a candidate, retry with:

```bash
wuji calib ik --sn <SN> --jsonl
```

The mutually exclusive alternatives are:

```bash
wuji calib ik --handedness left --jsonl
wuji calib ik --address 192.168.1.100:50000 --jsonl
```

Prefer `--sn`. An address target has no shared-access fallback when another program owns the direct device session. Use `--timeout-s <SECONDS>` only when the default 900-second overall deadline is unsuitable.

Use `--jsonl` for agent-guided calibration because it streams progress. Use human output (`wuji calib ik`) when the user will watch the terminal directly. Do not use `--json` for live guidance because it emits only the final document.

### Guide from JSONL

Parse each stdout line as one JSON object. Expect `schema_version: 1`, `operation: "calibrate"`, and `calibration: "ik"`.

Every progress event contains `feedback` with the same calibration fields exposed to the Python callback. There is no separate `guidance` or `presentation` object. Follow the Python example's derivation rules:

- Use `step_index + 1` as the human step number. Completed poses are `step_index + 1` in `done`, otherwise `step_index`, capped at `step_total`.
- Announce a pose when `step_name` changes. For an unknown pose ID, replace underscores with spaces; do not invent physical details beyond asking the human to move into that pose and hold still.
- For `state: "waiting_movement"`, ask the human to open the palm and then move into `step_name`.
- For `state: "waiting_stable"`, ask the human to hold still. If `variance_ok` is false, say the hand is moving too much.
- For `state: "collecting"`, ask the human to keep holding; summarize `collect_elapsed` / `collect_target` or `frames_collected` without narrating every frame.
- For `state: "done"`, state that the pose is collected. If the human step number is at least `step_total`, keep waiting for the numerical solve and publish result; otherwise ask the human to open the palm before the next pose.
- Use the provided `progress` value, clamped to 0 through 1. Do not recompute it from elapsed fields.

For diagnostics, iterate the `metrics` array in source order. Convert `unit: "m"` errors to millimeters, then skip displayed errors at or below `0.0001`. Group by `finger` or `finger-finger_b`, sort group names, and relay the metric `hint`. If `constraints_ok` is false and no metric remains, ask the human to adjust the current pose. Limit repeated narration and show at most eight diagnostic lines at a time.

Avoid flooding the user. Speak when the pose or state changes, when diagnostics materially change, or when the user needs to act. The final pose may be followed by a quiet numerical solve and publish phase; keep waiting within the overall timeout and do not claim the process is stuck merely because feedback pauses.

### Handle Terminal Events

Expect exactly one terminal JSONL event:

- `event: "result"`, `status: "ok"`: report success and inspect `result.handedness`, `result.calibrated_urdf`, `result.sdk_user`, and `result.frames_per_pose` when present. Verify the reported user and hand side match the user's intent.
- `event: "error"`, `status: "failed"`: report `error.kind` and `error.message`; use any included `device` and `user` context. Exit code is `1`.
- `event: "cancelled"`, `status: "cancelled"`: report a clean user cancellation. Exit code is `9`.

Also check the process exit code. Do not treat a stream that ends without a terminal event as success.

### Cancel Safely

When the user asks to stop, send Ctrl+C once. The CLI asks the SDK operation to cancel, waits briefly for it to settle, releases the device, emits a `cancelled` event, and exits with code `9`. Keep waiting for that terminal event instead of immediately killing the process.

### Resolve Common Failures

- `default SDK user cannot run IK calibration`: ask the user to create a named user with `wuji user create <name>` and activate it with `wuji user switch <name>`, then request confirmation before retrying.
- `no device found`: check power, USB, and local-network reachability; use `wuji devices --json` only for discovery troubleshooting.
- `found N devices`: show the candidate SNs and ask the user to choose one; never select automatically.
- `IK calibration requires a connected Wuji Glove`: the selected device is the wrong type or lacks the calibration capability.
- Connection failure with `--address`: retry with `--sn` or no selector if another program may hold the device session.
- `timeout`: explain which phase or pose timed out and offer a retry or a larger `--timeout-s`; do not retry automatically.
- Disconnect during collection: restore connectivity and restart only after the user confirms.

## Tactile Calibration Workflow

Use `wuji calib tactile` to collect, train, validate, and install a contact model for one glove.

### Select and Start

```bash
wuji calib tactile --sn <SERIAL>
```

The `--sn` option is required because each glove uses its own contact model.

Use hands-off mode when the command runs from a script or CI job:

```bash
wuji calib tactile --sn <SERIAL> --non-interactive
```

`--non-interactive` accepts each prompt automatically. Press Ctrl+C to abort.
