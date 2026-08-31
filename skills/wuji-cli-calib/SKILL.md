---
name: wuji-cli-calib
description: "Guide safe Wuji Glove calibration with the wuji CLI. Use when the user asks to run or monitor `wuji calib hand-model` or `wuji calib tactile`, interpret calibration progress or errors, cancel an active calibration, inspect the resulting hand model, or choose between hand model and tactile calibration. Route each mode without applying the hand model's user-and-hand rules to tactile's device-specific model."
---

# Wuji CLI Calib

Route calibration requests to the correct workflow and keep the human in the loop for physical actions and persistent model changes.

## Route the Request

- For hand model calibration, follow the hand model workflow in this file before executing any command.
- For tactile calibration, follow the tactile workflow in this file before executing any command.
- Keep hand model and tactile semantics separate. Hand model calibration publishes a model for the current SDK user and hand side; tactile calibration trains and installs a contact model for a specific glove SN.
- Hand model calibration attributes the result to the user the **device** is bound to, which is resolved after connecting. If another process switches the SDK user while `wuji calib hand-model` is scanning or connecting, the CLI reports the switch and attributes the calibration to the bound user; if that turns out to be `Default`, it stops with exit `5` before collecting any pose. Trust the user named in the command's own output over whatever `wuji user list` says afterwards.

## Apply Shared Safety Rules

- Treat calibration as a persistent state-changing operation. Do not start it for a status, help, planning, or troubleshooting-only request.
- Before starting, state which calibration mode will run and that the human must perform the prompted physical actions. Obtain confirmation unless the user's current request already explicitly authorizes starting that mode now.
- Do not add `wuji devices` as a mandatory preflight for the directly watched Human TTY flow. Hand model calibration scans and connects on its own when no selector is supplied. For agent-guided JSONL calibration, resolve the SN and handedness before starting so device selection, overwrite confirmation, and final identity are explicit. Tactile always requires `--sn`.
- Prefer an explicit `--sn` for hand model calibration when the user has selected a device, and always provide it for tactile. Never choose one of several devices without the user identifying it.
- Keep the command attached to a streaming terminal session until it emits a terminal event and exits. Do not start a second calibration while one is active.
- On a cancellation request, send Ctrl+C once and allow the CLI to stop the SDK operation and release the device.
- Do not automatically retry a failed or cancelled calibration. Explain the failure and ask before restarting because a retry begins the physical workflow again.

## Report the Outcome

- Report the terminal status, selected device SN, model identity, and output artifact when the command provides them.
- Distinguish command failure from user cancellation. Hand model calibration exit codes follow the `wuji user` convention: `0` success, `5` default-user protection, `9` cancellation, and `1` other failure. Hand model JSON/JSONL errors also carry a numeric `error.code`; a second Ctrl+C during tactile calibration exits immediately with code `130`.
- Never infer model ownership from device SN. Use the identity fields returned by the selected calibration mode.

## Hand Model Calibration Workflow

Use this workflow to guide a human through `wuji calib hand-model` and monitor its structured progress.

### Confirm Preconditions

Before starting, confirm all of the following:

- The human intends to start hand model calibration now and is ready to perform hand poses.
- For a directly watched Human TTY run, let the built-in prompt create or switch to the intended named user. For `--json` / `--jsonl` or redirected Human output, switch to a named user before starting; non-interactive output still rejects Default with exit `5`.
- The Human TTY flow includes fixed-size, colored left/right ANSI pose art when the terminal is at least 81 columns by 38 rows. A smaller terminal hides the art and tells the human to enlarge the window and restart calibration. The art belongs to the CLI and is not bundled with this public Skill; agent-guided JSONL runs use text instructions derived from feedback.
- The human understands that success publishes `left_hand.urdf` or `right_hand.urdf` for the current SDK user and hot-reloads the hand model for online use. Recalibrating the same user and hand side replaces that stable model even when a different glove is used.
- A Wuji Glove is powered and reachable over USB or the local network.

The Human TTY flow confirms before overwriting an existing hand URDF and defaults to No. Machine modes do not prompt, so obtain confirmation before launching `--json` / `--jsonl` unless the user's current request explicitly authorizes recalibration.

### Select and Start

For a human watching the terminal, run:

```bash
wuji calib hand-model
```

The Cliclack journey shows the current user's left/right status, offers user creation or switching, scans and lists Wuji Gloves, asks which glove to use, confirms overwrites with a vertical Yes/No selector, and renders the six live pose steps. Pose art is never resized: the CLI displays the complete fixed-size ANSI guide only when the terminal can hold the 60-column guide block and live copy. After a successful publish, `Calibration finished` shows only the user, handedness, and URDF result (with file size and local time). `User show` opens the same full profile inventory as `wuji user show`, `Recalibrate` returns directly to the user-selection entry without an extra confirmation layer, and `Finish` closes without a second success summary. The standard overwrite confirmation still runs after the next device is connected and its handedness is known.

For agent-guided calibration, perform this preflight before starting the state-changing command:

1. Run `wuji user show --json`. Stop if the current user is Default. If the selected hand is already calibrated, obtain overwrite confirmation unless the current request explicitly authorizes recalibration.
2. Use an SN already selected by the human. Otherwise run `wuji devices --json`; use the sole Wuji Glove or ask the human to choose when several are visible.
3. Run `wuji get hand_side --sn <SN> --json` and retain `value` as `left` or `right`. Stop if it is missing or invalid.
4. Start the same device in a persistent streaming terminal:

```bash
wuji calib hand-model --sn <SN> --jsonl
```

Machine modes do not prompt. Keep the process attached, poll it frequently, and continue until one terminal event arrives and the process exits. Do not run another device command while calibration owns the device.

For redirected automation that does not guide a human visually, a selector may still be omitted:

```bash
wuji calib hand-model --jsonl
```

The command scans automatically. It connects the sole device, reports `no device found` for zero devices, and lists candidate SNs without connecting when several devices are found. Only after the user chooses a candidate, retry with:

```bash
wuji calib hand-model --sn <SN> --jsonl
```

The mutually exclusive alternatives are:

```bash
wuji calib hand-model --handedness left --jsonl
wuji calib hand-model --address 192.168.1.100:50000 --jsonl
```

Prefer `--sn`. An address target has no shared-access fallback when another program owns the direct device session. Use `--timeout-s <SECONDS>` only when the default 900-second overall deadline is unsuitable.

Use `--jsonl` for agent-guided calibration because it streams progress. Use human output (`wuji calib hand-model`) when the user will watch the terminal directly. Do not use `--json` for live guidance because it emits only the final document.

### Guide from JSONL

Parse each stdout line as one JSON object. Expect `schema_version: 2`, `operation: "calibrate"`, and `calibration: "hand_model"`.

Every progress event contains `feedback` with the same calibration fields exposed to the Python callback. There is no separate `guidance` or `presentation` object. Follow the Python example's derivation rules:

- Use `step_index + 1` as the human step number. Completed poses are `step_index + 1` in `done`, otherwise `step_index`, capped at `step_total`.
- When `step_name` first appears or changes, announce the pose once and use these exact actions: `pinch_index` → touch thumb tip to index fingertip; `pinch_middle` → touch thumb tip to middle fingertip; `pinch_ring` → touch thumb tip to ring fingertip; `pinch_pinky` → touch thumb tip to pinky fingertip; `four_finger_bend_90` → bend the four fingers about 90 degrees; `flat_open` → straighten every finger with the palm flat and wrist still. Send the text action immediately and keep polling; do not wait for acknowledgement because the device detects the physical pose directly. For an unknown pose ID, replace underscores with spaces and ask the human to move into that pose and hold still. This public Skill carries no pose-image assets; do not invent or reconstruct pose art.
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
- `event: "error"`, `status: "failed"`: report `error.kind`, `error.code`, and `error.message`; use any included `device` and `user` context. The process exit code matches `error.code` (`1` or `5`). A pose collection timeout after 120 seconds ends the entire calibration run; the CLI does not retry that pose.
- `event: "cancelled"`, `status: "cancelled"`: report a clean user cancellation. Exit code is `9`.

Also check the process exit code. Do not treat a stream that ends without a terminal event as success.

### Cancel Safely

When the user asks to stop, send Ctrl+C once. The CLI asks the SDK operation to cancel, waits briefly for it to settle, releases the device, emits a `cancelled` event, and exits with code `9`. Keep waiting for that terminal event instead of immediately killing the process.

### Resolve Common Failures

- `the default SDK user cannot run hand model calibration`: ask the user to create a named user with `wuji user create <name>` and activate it with `wuji user switch <name>`, then request confirmation before retrying.
- `no device found`: check power, USB, and local-network reachability; use `wuji devices --json` only for discovery troubleshooting.
- `found N devices`: show the candidate SNs and ask the user to choose one; never select automatically.
- `hand model calibration requires a connected Wuji Glove`: the selected device is the wrong type or lacks the calibration capability.
- Connection failure with `--address`: retry with `--sn` or no selector if another program may hold the device session.
- Pose timeout / `0x4101`: the current pose did not pass within 120 seconds and the whole run failed. Ask the human to adjust the pose or review the tutorial, then request confirmation before running the command again. `--timeout-s` is the separate overall command deadline and does not change the SDK's 120-second per-pose limit.
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
