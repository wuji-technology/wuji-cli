# Changelog

All notable changes to Wuji CLI will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project uses calendar versioning (YYYY.M.D).

## [Unreleased]

## [2026.8.3]

### Added

- **Wuji Hand 2 support**: `wuji upgrade` supports firmware upgrades on second-generation hands with tactile sensors.
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

[Unreleased]: https://github.com/wuji-technology/wuji-cli/compare/v2026.8.3...HEAD
[2026.8.3]: https://github.com/wuji-technology/wuji-cli/compare/v2026.7.15...v2026.8.3
[2026.7.15]: https://github.com/wuji-technology/wuji-cli/compare/v2026.7.14...v2026.7.15
[2026.7.14]: https://github.com/wuji-technology/wuji-cli/releases/tag/v2026.7.14
