# wuji-cli

[![Release](https://img.shields.io/github/v/release/wuji-technology/wuji-cli)](https://github.com/wuji-technology/wuji-cli/releases)

Wuji CLI is a command-line tool for Wuji devices — scan, probe connectivity, read/write parameters, subscribe to real-time topics, visualize Wuji Hand 2 and Wuji Glove data, calibrate tactile contact models, run health diagnostics, and upgrade firmware, all from the terminal.

**Get started with [Quick Start](#quick-start). For detailed documentation, please refer to [Wuji Documentation Center](https://docs.wuji.tech/docs/en/).**

## Quick Start

### Prerequisites

- Ubuntu 22.04 LTS or later
- Devices must be on the same local network (UDP) or connected via USB

### Installation

#### CLI Installation

Use the install script:

```bash
curl -fsSL https://get.wuji.tech/cli | bash
```

#### Skills Installation

use npx to install skills:

```bash
npx skills add wuji-technology/wuji-cli -g
```

Alternatively, use the install script:

```bash
curl -fsSL https://get.wuji.tech/skills | bash
```

### Verification

Run `wuji devices` to check for discovered devices:

```bash
wuji devices
```

## Usage

The examples below cover common tasks. Run `wuji <command> --help` for all options. For the full command semantics — mental model, error handling, and JSON output reference — see the [Wuji Documentation Center](https://docs.wuji.tech/docs/en/), read the [skills](skills/) directly, or [install skills](#skills-installation) for your AI agent.

```text
Usage: wuji [OPTIONS] [COMMAND]

Commands:
  devices      Scan and list devices
  ping         Probe device connectivity
  resources    List device parameters and subscribable topics
  get          Read a parameter
  set          Write a parameter
  sub          Subscribe to real-time data
  viz          Visualize live device data in a Rerun Web Viewer
  doctor       Check device and environment health
  logs         Manage device logs and diagnostics
  calib        Calibrate device sensing models
  user         Manage SDK users and calibration data bundles
  upgrade      Upgrade device firmware (--check first)
  update       Update wuji CLI to the latest release
  completions  Generate shell completion scripts

Global Options:
      --json   Output as pretty-printed JSON
      --jsonl  Output as JSON Lines (one compact JSON object per frame/record)
```

### Shell Completions

```bash
wuji completions bash > ~/.local/share/bash-completion/completions/wuji
exec bash
```

For zsh, fish, powershell, or elvish, substitute the shell name in the command above.

## Documentation

For detailed documentation, see the [Wuji Docs Center](https://docs.wuji.tech/docs/en/wuji-cli/latest/).

## Changelog

See the [release notes](https://docs.wuji.tech/docs/en/release-notes) for the version history.

## Contact

For any questions, please contact [support@wuji.tech](mailto:support@wuji.tech).

## License

[MIT](LICENSE)
