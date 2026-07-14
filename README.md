# wuji-cli

[![Release](https://img.shields.io/github/v/release/wuji-technology/wuji-cli)](https://github.com/wuji-technology/wuji-cli/releases)

Wuji CLI is a command-line tool for Wuji devices — scan, probe connectivity, read/write parameters, subscribe to real-time topics, run health diagnostics, and upgrade firmware, all from the terminal.

**Get started with [Quick Start](#quick-start). For detailed documentation, please refer to [Wuji Documentation Center](https://docs.wuji.tech/en).**

## Quick Start

### Prerequisites

- Ubuntu 22.04+ 
- Devices must be on the same local network (UDP) or connected via USB

### Installation

#### CLI Installation

use the install script (Recommended):

```bash
curl -fsSL https://get.wuji.tech/cli | bash
```

Alternatively, download the latest binary from [Releases](https://github.com/wuji-technology/wuji-cli/releases), then install it:

```bash
sudo cp wuji_<version>_<arch> /usr/local/bin/wuji
sudo chmod +x /usr/local/bin/wuji 
```

#### Skills Installation

use npx to install skills:

```bash
npx skills add wuji-technology/wuji-cli
```

Alternatively, use the install script:

```bash
curl -fsSL https://get.wuji.tech/skills | bash
```

### Verification

```bash
wuji devices
```

should show the list of discovered devices.

```bash
$ wuji devices
found 2 device(s)
┌──────────────────┬───────────┬──────────┬─────────────────────┬─────────────────────┐
│ SN               ┆ Transport ┆ USB Port ┆ IP                  ┆ Address             │
╞══════════════════╪═══════════╪══════════╪═════════════════════╪═════════════════════╡
│ WG1KXXXXXXXXXXX ┆ Udp       ┆ -        ┆ 192.168.1.101:50001 ┆ 192.168.1.101:50001 │
├╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌┼╌╌╌╌╌╌╌╌╌╌╌┼╌╌╌╌╌╌╌╌╌╌┼╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌┼╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌┤
│ WG1KXXXXXXXXXXX ┆ Udp       ┆ -        ┆ 192.168.1.106:50001 ┆ 192.168.1.106:50001 │
└──────────────────┴───────────┴──────────┴─────────────────────┴─────────────────────┘
💡 run `wuji ping` to get device type and firmware version
```

## Usage

The examples below cover common tasks. Run `wuji <command> --help` for all options. For the full command semantics — mental model, error handling, and JSON output reference — see the [Wuji Documentation Center](https://docs.wuji.tech/en), read the [skills](skills/) directly, or [install skills](#skills-installation) for your AI agent.

### Device Management

```bash
wuji devices                         # List all discovered devices
wuji ping                            # Probe connectivity, report SN / firmware / IP
```

### Read / Write Parameters

```bash
wuji resources --sn <SERIAL>         # List readable parameters and subscribable topics
wuji get firmware_version --sn <SERIAL>
wuji set ip_address 192.168.1.100 --sn <SERIAL>
```

### Subscribe to Topics

```bash
wuji sub emf_poses --count 1
wuji sub tactile --count 500 --jsonl > tactile.jsonl   # Record 500 frames to a file
```

### Health Diagnostics

```bash
wuji doctor                          # Run all checks
wuji doctor -v                       # Detailed output with repair suggestions
```

### Firmware Upgrade

```bash
wuji upgrade --check                     # See which devices have firmware updates
wuji upgrade --all                       # Upgrade every device to its latest firmware
wuji upgrade --sn <SERIAL> --to 0.11.0   # Install a specific version
wuji upgrade --sn <SERIAL> --list        # List available firmware versions
```

Flashing asks for confirmation first (skip with `--yes`); downloads are verified and cached. A device already on the target version is skipped. Downgrading to an older version via `--to` or `--file` is allowed; the confirmation prompt flags it with a `⚠ DOWNGRADE` warning. Use `--force` to downgrade a device that is ahead of the latest catalog version (e.g. a development unit with unreleased firmware).

### Updating the CLI

```bash
wuji update                          # Download and install the latest release
wuji update --check                  # Check for updates without installing
```

The CLI also checks for new releases in the background, at most once every 24 hours, and shows a notice when an update is available. The check never blocks or slows down your commands. To turn the notice off, set `WUJI_NO_UPDATE_CHECK=1`.

### Scripting

Most commands accept `--json` for structured output. The exit code is 0 on success and nonzero on failure, so scripts can gate on it directly.

### Shell Completions

```bash
wuji completions bash > ~/.local/share/bash-completion/completions/wuji
exec bash
```

For zsh, fish, powershell, or elvish, substitute the shell name in the command above.

## Documentation

For detailed documentation, see the [Wuji Docs Center](https://docs.wuji.tech/docs/en/wuji-cli/latest/).

## Changelog

See [CHANGELOG.md](CHANGELOG.md) for the version history.

## Contact

For any questions, please contact [support@wuji.tech](mailto:support@wuji.tech).

## License

[MIT](LICENSE)
