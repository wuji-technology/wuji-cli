# Changelog

All notable changes to Wuji CLI will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project uses calendar versioning (YYYY.M.D).

## [Unreleased]

## [2026.9.21]

### Added

- **Release notes and agent skills sync in `wuji update`**: `wuji update --check` now shows the release notes of the latest available version alongside the version comparison. After a successful binary upgrade, `wuji update` syncs the Wuji CLI agent skills to the matching CLI version, and a sync failure doesn't block the upgrade. `wuji update --skills` syncs skills to the current CLI version only.
- **Wuji Glove live visualization**: `wuji viz` now supports live Wuji Glove visualization.
- **Guided device support skill**: Added the `wuji-cli-support` agent skill to collect fault details and prepare a support report with available attachments.

### Changed

- **visualization**: Hand 2 visualization and runtime tactile zeroing now adapt to the connected hardware — no-tactile devices show joint pose only, while tactile-equipped hands keep the tactile view.

### Fixed

- Fixed inconsistent status wording in `wuji update` and `wuji update --check`, so both read the same for the same state.
- Fixed the one-click installer installing skills from the default branch instead of the release tag when `VERSION` pins a specific version, including runs that skip the CLI installation.
- Fixed the one-click installer skills step ending with a spurious `Failed to install N` or `PromptScript does not support global skill installation`. Skills are now installed only for the agents detected on the machine, falling back to a direct copy into `~/.agents/skills`.
- Fixed `wuji logs dump` / `export` failing with `session closed` when run against multiple devices in a single command. Every device's bundle is now exported.

## [2026.8.31]

### Added

- Added `wuji viz` live visualization for viewing Wuji Hand 2 poses and fingertip tactile data.

### Changed

- Removed `wuji calib ik` without a compatibility alias. **BREAKING**: Update scripts and automation to use `wuji calib hand-model`. Calibration behavior and tactile calibration are unchanged.
- Improved `wuji calib hand-model` with clearer step-by-step guidance, pose feedback, and result presentation throughout calibration.
- Improved `wuji user` with a clearer, more consistent terminal experience for managing profiles and moving calibration data.
- Updated `wuji calib hand-model` JSON and JSONL events to use `schema_version: 2` and `calibration: "hand_model"`. **BREAKING**: Update JSON consumers from schema version `1` and `"ik"`, and handle `legacy_hand_model_ignored` and `default_user_hand_model_disabled` values from `wuji user import`.
- Rejected invalid `wuji upgrade --file` firmware files locally with a clear error before they reach the device.

### Fixed

- Fixed Windows firmware downloads to resolve the Windows user profile without requiring the Unix-only `HOME` variable. Calibration export failures now use stable `/` separators across platforms.
- Updated the one-click installer to install agent skills in the user-global location, making them available across projects.
- Updated `wuji doctor` to report devices without a matching diagnostic recipe, such as Wuji Hand 2, as skipped instead of failed. Genuine connection or collection failures still report as failed and exit 1.
- Added support for non-UTF-8 log directory names in `wuji logs list` and `wuji logs export`.

## [2026.8.17]

### Added

- **Host environment diagnostics**: `wuji doctor` now checks host software versions, system info, and network interfaces before scanning for devices, and reports address-conflict issues found during the scan. **BREAKING**: under `--json`, the output is now organized by diagnosis layer — `env` (host environment checks) and `device` (device discovery listed as a generic entry without `sn`, plus per-device results) — replacing the old flat `system` / `devices` layout. Running with no device attached is now a normal exit (0 unless a host check fails) instead of an error.
- **Wuji logs dump**: new subcommand collecting device-side diagnostic snapshots for Wuji Hand 2 devices — scans all devices by default or targets one via `--sn`/`--address`/`--handedness`. It captures identity, fault/status, bus voltage and temperature, communication diagnostics, and Flash KV history as `<sn>_<ts>_device.json` + `<sn>_<ts>_flash.jsonl`. Field failures land in the snapshot's `failures` list without aborting. The exit code is non-zero if any device failed.
- **Device snapshots in support bundles**: `wuji logs export` now includes these device diagnostic snapshots and flash logs in the support bundle by default (under `devices/`), with no extra flag needed.
- **IK calibration recordings in support bundles**: `wuji logs export` now automatically includes IK calibration runs from `~/.wuji/calibration/recordings/` that intersect the selected local-date range, including the manifest, the full recording, and the completed step recordings.
- **Script-friendly JSON fields**: Added `missing_model_files` to `wuji user show --json` and a `detail` field on skipped component rows (reason: `incomplete_model`, `not_in_bundle`, or `not_declared_in_manifest`).

### Changed

- **Structured JSON errors**: Under `--json` / `--jsonl`, most command errors now print structured JSON to stderr, keeping stdout clean for scripts.
- **Colored error labels**: Errors in human mode print a red `error:` label (rustc style), matching the existing `warning:` label.

### Fixed

- **Unknown resource paths**: `wuji get` with an unknown resource path now errors clearly instead of silently returning success without a value.
- **Incomplete tactile models reported**: `wuji user export`, `import`, `import --preview`, and `show` now list an incomplete tactile model (missing `contact.safetensors`, `contact.npz`, or `contact.json`) as skipped, naming the device SN and missing files, instead of dropping it silently. Exporting only a partial model no longer claims there is no calibration data — the error names the device and files and points to `wuji calib tactile`.
- **`--json` always reports `current_user`**: `wuji user create` / `switch` / `rename` / `delete` under `--json` now always report the resulting `current_user` (`rename` also reports `previous_name`), so scripts don't need a follow-up `user list`.

## [2026.8.3]

### Added

- **Wuji Hand 2 support**: `wuji upgrade` supports firmware upgrades on Wuji Hand 2 with tactile sensors.
- **Tactile calibration**: `wuji calib tactile` collects, trains, verifies, and installs a contact model for Wuji Glove, with a `--non-interactive` mode for hands-off runs.
- **Hand-model calibration**: `wuji calib ik` guides device selection, live pose, and reference images, then saves and hot-reloads the completed model for the active profile. It builds a hand model that matches your physical hand, so pinches, four-finger bends, and other gestures produce expected output on your Wuji Glove.
- **User profiles**: `wuji user` manages calibration profiles for Wuji Glove, creating, describing, switching, listing, showing, renaming, and deleting profiles, and importing or exporting their IK and tactile calibration data. Results are stored per profile and per hand, so gloves on the same hand share one result under the same profile.
- **Logging**: `wuji logs` provides a command group (`path`, `list`, `export`) for log directory discovery, file listing, and support-bundle export. It collects host-side logs (from the SDK, Studio, and similar tools) into a bundle you can send with your device SN to `support@wuji.tech`.
- **Agent skills**: new agent skills were added to cover each of the commands above — profile management, calibration, and logs.

### Changed

- **BREAKING**: Unified device type display names to lowercase snake_case. `wuji upgrade --type` now requires snake_case values (e.g. `wuji_glove` instead of `"Wuji Glove"`). Affects `ping`'s Device Type column, `doctor` report headers, `upgrade --check` output, help examples, and all documentation.

## [2026.7.15]

### Fixed

- Fixed the install script exiting without installing agent skills.

## [2026.7.14]

### Added

- Device management: `wuji devices` to scan and list devices over USB/UDP (supports `--json`), `wuji ping` to probe device connectivity via full handshake (all discovered devices by default, or a specific one by SN, IP address, or handedness).
- Parameter read/write: `wuji get` and `wuji set` to read and write device parameters with typed JSON output.
- Resource discovery: `wuji resources` to list all readable/writable parameters and subscribable topics on a device.
- Data subscription: `wuji sub <topic>` to subscribe to a topic's real-time data with the `--count` option.
- Health diagnostics: `wuji doctor` checks device health, including EMF disconnection detection and tactile dead-pixel/bad-column detection (wuji_glove only for now—more diagnostics and device types to come).
- Firmware upgrade: `wuji upgrade` upgrades device firmware from the official catalog—check which devices have updates with `--check`, upgrade one or all devices to the latest, install a specific version with `--to`, flash a local package with `--file`, and browse available versions with `--list`. Downloads are sha256-verified and cached locally. Flashing asks for confirmation (skip with `--yes`) and prints a per-device report.
- Self-update: `wuji update` downloads, verifies, and installs the latest release in place (`--check` to check only).
- Shell completions: `wuji completions <shell>` generates auto-completion scripts for bash, zsh, fish, powershell, and elvish.
- Output formatting: most commands support `--json`/`--jsonl` output modes and device selection by `--sn`, `--address`, or `--handedness`.
- Colored output: human-readable output uses consistent semantic colors for statuses, warnings, and values. Respects `NO_COLOR` and falls back to plain text on non-TTY output.

[Unreleased]: https://github.com/wuji-technology/wuji-cli/compare/v2026.9.21...HEAD
[2026.9.21]: https://github.com/wuji-technology/wuji-cli/compare/v2026.8.31...v2026.9.21
[2026.8.31]: https://github.com/wuji-technology/wuji-cli/compare/v2026.8.17...v2026.8.31
[2026.8.17]: https://github.com/wuji-technology/wuji-cli/compare/v2026.8.3...v2026.8.17
[2026.8.3]: https://github.com/wuji-technology/wuji-cli/compare/v2026.7.15...v2026.8.3
[2026.7.15]: https://github.com/wuji-technology/wuji-cli/compare/v2026.7.14...v2026.7.15
[2026.7.14]: https://github.com/wuji-technology/wuji-cli/releases/tag/v2026.7.14
