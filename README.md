# wuji-cli

[![Release](https://img.shields.io/github/v/release/wuji-technology/wuji-cli)](https://github.com/wuji-technology/wuji-cli/releases)

Wuji CLI is a command-line tool for Wuji devices — scan, probe connectivity, read/write parameters, subscribe to real-time topics, visualize Wuji Hand 2 and Wuji Glove data, calibrate tactile contact models, run health diagnostics, and upgrade firmware, all from the terminal.

**Get started with [Quick Start](#quick-start). For detailed documentation, please refer to [Wuji Documentation Center](https://docs.wuji.tech/docs/en/).**

## Quick Start

### Prerequisites

- **Linux**: Ubuntu 20.04 LTS or later (`x86_64`, `aarch64`)
- **macOS**: macOS 11.0 (Big Sur) or later (`arm64` Apple Silicon)
- **Windows**: Windows 10 Version 21H2 (Build 19044) or later, or Windows 11 (`x86_64`)
- Devices must be on the same local network (UDP) or connected via USB

### Installation

#### CLI Installation

**Linux / macOS (Bash / Zsh)**:

```bash
curl -fsSL https://get.wuji.tech/cli | bash
```

**Windows (PowerShell)**:

```powershell
irm https://get.wuji.tech/cli.ps1 | iex
```

#### Skills Installation

use npx to install skills:

```bash
npx skills add wuji-technology/wuji-cli -g
```

Alternatively, use the install script:

**Linux / macOS**:

```bash
curl -fsSL https://get.wuji.tech/skills | bash
```

**Windows**:

```powershell
irm https://get.wuji.tech/skills.ps1 | iex
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

Run once per shell, then restart the shell.

**Bash** (Linux, or macOS with `bash-completion@2` from Homebrew):

```bash
mkdir -p ~/.local/share/bash-completion/completions
wuji completions bash > ~/.local/share/bash-completion/completions/wuji
```

**Zsh** (macOS default):

```bash
mkdir -p ~/.zfunc
wuji completions zsh > ~/.zfunc/_wuji
```

Add these two lines to `~/.zshrc`, before the first `compinit` call:

```zsh
fpath=(~/.zfunc $fpath)
autoload -U compinit && compinit
```

**PowerShell** (Windows PowerShell 5.1 or PowerShell 7):

```powershell
$compFile = "$HOME\.wuji\completions.ps1"
wuji completions powershell | Out-File -Encoding utf8 $compFile -Force
if (-not (Test-Path $PROFILE)) {
  New-Item -ItemType File -Path $PROFILE -Force | Out-Null
}
if ((Get-Content $PROFILE) -notcontains ". `"$compFile`"") {
  Add-Content $PROFILE "`n. `"$compFile`""
}
. $compFile
```

## Documentation

For detailed documentation, see the [Wuji Docs Center](https://docs.wuji.tech/docs/en/wuji-cli/latest/).

## Changelog

See the [release notes](https://docs.wuji.tech/docs/en/release-notes) for the version history.

## Contact

For any questions, please contact [support@wuji.tech](mailto:support@wuji.tech).

## License

[MIT](LICENSE)
