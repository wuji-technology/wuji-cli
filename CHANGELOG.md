# Changelog

All notable changes to Wuji CLI will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project uses calendar versioning (YYYY.M.D).

## [Unreleased]

## [2026.7.15]

### Fixed

- Fixed the install script exiting without installing agent skills.

## [2026.7.14]

### Added

- Device management: `wuji devices` to scan and list devices over USB/UDP (supports `--json`), `wuji ping` to probe device connectivity via full handshake (all discovered devices by default, or a specific one by SN, IP address, or handedness).
- Parameter read/write: `wuji get` and `wuji set` to read and write device parameters with typed JSON output.
- Resource discovery: `wuji resources` to list all readable/writable parameters and subscribable topics on a device.
- Data subscription: `wuji sub <topic>` to subscribe to a topic's real-time data with the `--count` option.
- Health diagnostics: `wuji doctor` checks device health, including EMF disconnection detection and tactile dead-pixel/bad-column detection (Wuji Glove only for now—more diagnostics and device types to come).
- Firmware upgrade: `wuji upgrade` upgrades device firmware from the official catalog—check which devices have updates with `--check`, upgrade one or all devices to the latest, install a specific version with `--to`, flash a local package with `--file`, and browse available versions with `--list`. Downloads are sha256-verified and cached locally. Flashing asks for confirmation (skip with `--yes`) and prints a per-device report.
- Self-update: `wuji update` downloads, verifies, and installs the latest release in place (`--check` to check only).
- Shell completions: `wuji completions <shell>` generates auto-completion scripts for bash, zsh, fish, powershell, and elvish.
- Output formatting: most commands support `--json`/`--jsonl` output modes and device selection by `--sn`, `--address`, or `--handedness`.
- Colored output: human-readable output uses consistent semantic colors for statuses, warnings, and values. Respects `NO_COLOR` and falls back to plain text on non-TTY output.

[Unreleased]: https://github.com/wuji-technology/wuji-cli/compare/v2026.7.15...HEAD
[2026.7.15]: https://github.com/wuji-technology/wuji-cli/compare/v2026.7.14...v2026.7.15
[2026.7.14]: https://github.com/wuji-technology/wuji-cli/releases/tag/v2026.7.14
