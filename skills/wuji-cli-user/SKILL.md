---
name: wuji-cli-user
description: "Create, switch, list, show, rename, or delete wuji SDK user profiles, and export/import calibration bundles (hand model + tactile model) between machines, all via the `wuji user` CLI. These are named calibration profiles under ~/.wuji — NOT operating-system accounts — so use this skill (never edit code or touch OS users) for any request to delete a user, switch/change the current user, rename a user, create or list users, resolve the 'default user cannot calibrate' block, or move/inspect calibration data. Deletion requires confirmation. Import creates a new profile and keeps the current profile unchanged."
compatibility: Requires Wuji CLI installed with the wuji executable available on PATH. Run `wuji update --skills` first so these skills match the installed CLI version.
metadata:
  author: wuji-technology
  version: "2026.11.23"
  requires:
    bins:
      - wuji
  cliHelp: "wuji user --help"
---

A **user profile** is a local record of one person's calibration data under `~/.wuji/sdk`. `wuji user` manages these profiles and moves calibration bundles between machines. Every subcommand is a local operation (registry + files, **no device connection**) and supports `--json`.

## Mental Model

- A profile is keyed by its **name** — this is the only identifier the user sees (there is no OS account link; the SDK's internal id is not exposed).
- Calibration is scoped per profile: the hand model is per **user + hand side**; tactile is per **device SN**.
- The **default user cannot store a calibrated hand model**. `wuji calib hand-model` refuses to run until a named profile is active. Tactile calibration is device-specific and may be stored, inspected, exported, or imported while Default is active.
- Stateless and local: no persistent connection, no device involved.

## Commands

| Command | Purpose |
| --- | --- |
| `wuji user list` | List profiles; the current one is marked `*`, `Default` is `(hand model not calibratable)`, each row shows left/right hand model calibration state |
| `wuji user show [name]` | Show a profile's description, hand model (state/file/size/time), and tactile (per SN) artifacts; defaults to the current profile |
| `wuji user create <name> [-d\|--description <text>] [--switch]` | Create a named profile with an optional description (does not switch unless `--switch`) |
| `wuji user switch [name]` | Make a profile current; omitting the name in a Human TTY opens a profile selector |
| `wuji user rename <old> <new>` | Rename; calibration data follows |
| `wuji user delete [name] [--yes]` | Delete a profile and all its calibration data; omitting the name in a Human TTY opens a profile selector |
| `wuji user export <path> [--force]` | Export the current profile's calibration bundle to a `.zip` |
| `wuji user import <path> [--preview] [--as <name>]` | Create a new profile from a bundle without switching the current profile |

Add `--help` to any subcommand for details.

## Safety (read before destructive actions)

- **`delete` is irreversible** and removes all of a profile's calibration data. In a Human TTY, omitting the name opens a selector that excludes `Default`, marks the current profile, and defaults to `Cancel operation`; after selection, the CLI prints what will be removed, suggests `wuji user export` for a backup, and asks for a default-No confirmation. Do not select a profile on the user's behalf. Do **not** pass `--yes` unless the user has explicitly authorized deleting that specific profile; `--yes` requires the name to be present. `Default` cannot be deleted.
- `import` always creates a new profile. It uses the name in the bundle unless `--as <name>` supplies another new name. It keeps the current profile and existing calibration data unchanged. Name conflicts ignore ASCII letter case. If the name exists, the command exits 2 with `reason: "object_exists"` and a `hint` on retrying with `--as`.
- Use `--preview` to inspect the source user, bundle version, and contents without creating a profile. In a Human TTY, imports also show the preview, progress, and result, and never ask for confirmation or a new name. Import doesn't accept `-y` or `--yes` in any mode.
- If import fails, the CLI removes the profile it created. If cleanup also fails, it exits 1, names the residual profile, and supplies a `wuji user delete <name> --yes` recovery command. Relay that command and obtain authorization before deleting the residual profile.
- `export` requires `--force` to overwrite an existing file in every output mode, including Human TTY. It never asks for confirmation. This includes a directory target whose generated filename already exists. Exporting a profile with no calibration data fails without writing a bundle.
- `delete` requires an explicit profile name and `--yes` outside Human TTY. Only add `--yes` after the user authorizes deleting that profile.
- **`Default` is protected**: it cannot be deleted or renamed. Deleting the current profile resets the current user to `Default` (the CLI reports this).
- Never choose among multiple profiles on the user's behalf. In a Human TTY, `wuji user switch` without a name opens a selector that includes `Default`, marks the current profile, and defaults to `Cancel operation`; let the user choose. Outside a TTY, supply the explicitly requested profile name. When a profile name is not found, run `wuji user list`, relay the available profiles, and ask which one to use.

## Calibration Workflow

First-time or default-user flow:

```bash
wuji user create alice -d "Left-hand operator" --switch    # named profile is now current
wuji calib hand-model               # calibration is allowed
```

If hand model calibration reports the default-user guidance (`create` / `switch` first), create and switch to a named profile, then retry. Tactile calibration does not require a named profile. Obtain confirmation before starting either calibration workflow (see the `wuji-cli-calib` skill).

## Exit Codes and JSON

| Code | `reason` | Meaning |
| --- | --- | --- |
| 0 | | Success (including a no-op switch to the current profile) |
| 0 | `operation_cancelled` | Cancelled at confirmation (human mode only; prints no error object) |
| 1 | `sdk_error` | Other failure, such as no calibration data to export, or an SDK error with no finer classification |
| 4 | `device_not_found` · `session_held` · `connection_lost` · `no_response` · `request_timeout` · `no_data` · `operation_in_progress` | Device or session unavailable: no matching device on the network, session held by another program, connect or request timed out, link dropped or no data, or an upgrade/calibration already running |
| 3 | `joint_offline` · `dependency_missing` | Joint offline, or a required dependency is missing |
| 2 | `access_not_supported` · `not_applicable` · `ambiguous_device` · `ambiguous_name` · `invalid_config` | Underlying SDK failure classified as a usage problem: unsupported operation, wrong device type, several candidates for the target, an ambiguous resource path, or invalid configuration. Same classification as every other command, so `reason` stays stable across commands |
| 2 | `invalid_value` | Invalid user name |
| 2 | `object_exists` | User already exists, or export target already exists (use `--force`) |
| 2 | `object_not_found` | User not found, or bundle file not found |
| 2 | `protected_object` | Default-user protection (delete/rename `Default`, or run hand model calibration as default) |
| 2 | `invalid_input_file` | Bundle invalid or incompatible version |
| 2 | `missing_yes` | `delete` without `--yes` outside an interactive terminal |
| 130 | `interrupted` | Ctrl+C at an interactive prompt (a plain exit status; on Windows the process ends with `0xC000013A`) |

With `--json`/`--jsonl`, success prints one document per command; errors print `{"error":{"code","kind","reason","message","hint"}}` on stdout, pretty-printed under `--json` and one line under `--jsonl`. Branch on `reason` (and the process exit code), not on parsing the message text.

Successful `create`, `switch`, `rename`, `delete`, and `import` results include `current_user`, the active profile after the action. Read it from the result even when the active profile stays the same. `import --preview` uses a separate preview structure without `current_user`. `rename` also reports `previous_name`, so a script can confirm which profile it just renamed.

## Examples

```bash
wuji user list --json                              # Inspect profiles + calibration state
wuji user create alice --description "Left-hand operator" --switch  # Create and activate a profile
wuji user show --json                              # Current profile's artifacts
wuji user export ./alice.zip                       # Export current profile
wuji user import ./alice.zip --preview             # Inspect a bundle without importing
wuji user import ./alice.zip                       # Create the profile named in the bundle
wuji user import ./alice.zip --as bob               # Import into a fresh profile
```
