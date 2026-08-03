---
name: wuji-cli-user
description: "Create, switch, list, show, rename, or delete wuji SDK user profiles, and export/import calibration bundles (IK URDF + tactile model) between machines, all via the `wuji user` CLI. These are named calibration profiles under ~/.wuji — NOT operating-system accounts — so use this skill (never edit code or touch OS users) for any request to delete a user, switch/change the current user, rename a user, create or list users, resolve the 'default user cannot calibrate' block, or move/inspect calibration data. delete and import are destructive; the skill covers the safe, confirmation-first way to run them."
metadata:
  author: wuji-technology
  version: "1.0"
  requires:
    bins: ["wuji"]
  cliHelp: "wuji user --help"
---

A **user profile** is a local record of one person's calibration data under `~/.wuji/sdk`. `wuji user` manages these profiles and moves calibration bundles between machines. Every subcommand is a local operation (registry + files, **no device connection**) and supports `--json`.

## Mental Model

- A profile is keyed by its **name** — this is the only identifier the user sees (there is no OS account link; the SDK's internal id is not exposed).
- Calibration is scoped per profile: IK hand-model is per **user + hand side**; tactile is per **device SN**.
- The **default user cannot be IK-calibrated**. `wuji calib ik` refuses to run until a named profile is active. Tactile calibration is device-specific and may be stored, inspected, exported, or imported while Default is active.
- Stateless and local: no persistent connection, no device involved.

## Commands

| Command | Purpose |
| --- | --- |
| `wuji user list` | List profiles; the current one is marked `*`, `Default` is `(IK not calibratable)`, each row shows left/right IK calibration state |
| `wuji user show [name]` | Show a profile's description, IK (state/file/size/time), and tactile (per SN) artifacts; defaults to the current profile |
| `wuji user create <name> [-d\|--description <text>] [--switch]` | Create a named profile with an optional description (does not switch unless `--switch`) |
| `wuji user switch <name>` | Make a profile current |
| `wuji user rename <old> <new>` | Rename; calibration data follows |
| `wuji user delete <name> [--yes]` | Delete a profile and all its calibration data (destructive) |
| `wuji user export <path> [--force]` | Export the current profile's calibration bundle to a `.zip` |
| `wuji user import <path> [--preview] [-y\|--yes] [--as <name>]` | Import a bundle into the current (or a new) profile |

Add `--help` to any subcommand for details.

## Safety (read before destructive actions)

- **`delete` is irreversible** and removes all of a profile's calibration data. By default it prints what will be removed and asks for confirmation, and suggests `wuji user export` for a backup first. Do **not** pass `--yes` unless the user has explicitly authorized deleting that specific profile. `Default` cannot be deleted.
- **`import` overwrites** the target profile's artifacts. Preview first with `--preview` (or read the interactive preview) and relay the **source user, bundle version, contents, and any conflicts** before proceeding. At an interactive conflict prompt, choose whether to overwrite the current profile or enter a new profile name; `--as <name>` selects the new-profile path up front. When the bundle comes from a different user and the target already has artifacts, the CLI backs them up under `calibration-import-backups/` before overwriting.
- **An IK-bearing bundle cannot be imported into `Default`**: `Default` cannot hold IK artifacts, so the CLI refuses (exit `5`) instead of succeeding with the IK silently dropped. Import into a named profile with `--as <name>`, or `wuji user create <name> --switch` first. A tactile-only bundle still imports into `Default` normally.
- **Import is not atomic.** If it fails partway, the profile can hold a mix of new and previous artifacts. The CLI says so, points at the backup directory when one was made, and tells the user to verify with `wuji user show <name>`. Relay that recovery path — do not retry blindly.
- **Non-interactive modes require explicit consent**: in `--json`/`--jsonl` or without a TTY, use `--preview` for a read-only import preview or `-y`/`--yes` to apply the import; `delete` only supports `--yes`. Only add a confirmation flag after confirming the user's intent — never as a default.
- **`export` never clobbers**: exporting over an existing file needs `--force` — including when the target is a **directory** and the auto-generated name collides. Exporting a profile with **no calibration data** fails and tells the user to complete a calibration first — nothing is written.
- **`Default` is protected**: it cannot be deleted or renamed. Deleting the current profile resets the current user to `Default` (the CLI reports this).
- Never choose among multiple profiles on the user's behalf. When a name is missing or ambiguous, the CLI lists available profiles — relay that and ask.

## Calibration Workflow

First-time or default-user flow:

```bash
wuji user create alice -d "Left-hand operator" --switch    # named profile is now current
wuji calib ik                       # calibration is allowed
```

If IK calibration reports the default-user guidance (`create` / `switch` first), create and switch to a named profile, then retry. Tactile calibration does not require a named profile. Obtain confirmation before starting either calibration workflow (see the `wuji-cli-calibrate` skill).

## Exit Codes and JSON

| Code | Meaning |
| --- | --- |
| 0 | Success (including a no-op switch to the current profile) |
| 2 | Invalid user name |
| 3 | User already exists |
| 4 | User not found |
| 5 | Default-user protection (delete/rename `Default`, or run IK calibration as default) |
| 6 | Bundle file not found |
| 7 | Bundle invalid or incompatible version |
| 8 | Export target already exists (use `--force`) |
| 9 | Cancelled at confirmation |

With `--json`/`--jsonl`, success prints one document per command; errors print `{"error":{"code":N,"message":...}}`. Branch on `code` (and the process exit code), not on parsing the message text.

## Examples

```bash
wuji user list --json                              # Inspect profiles + calibration state
wuji user create alice --description "Left-hand operator" --switch  # Create and activate a profile
wuji user show --json                              # Current profile's artifacts
wuji user export ./alice.zip                       # Export current profile
wuji user import ./alice.zip --preview             # Inspect a bundle without importing
wuji user import ./alice.zip                       # Preview, then confirm import
wuji user import ./alice.zip --as bob               # Import into a fresh profile
```
