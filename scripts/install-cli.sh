#!/bin/sh
set -u

# "latest" resolves to the newest release via the GitHub API at install time
# set VERSION=x.y.z to pin a specific version.
VERSION="${VERSION:-latest}"
GITHUB_REPO="${GITHUB_REPO:-wuji-technology/wuji-cli}"

BINARY_NAME="wuji"
INSTALL_DIR="${INSTALL_DIR:-$HOME/.local/bin}"

info()  { printf "\033[36m[INFO]\033[0m %s\n" "$*"; }
warn()  { printf "\033[33m[WARN]\033[0m %s\n" "$*"; }
error() { printf "\033[31m[ERROR]\033[0m %s\n" "$*" >&2; exit 1; }
success() { printf "\033[32m[SUCCESS]\033[0m %s\n" "$*"; }

need_cmd() { command -v "$1" >/dev/null 2>&1 || error "need '$1'"; }

# Prompt on /dev/tty with a default-yes answer; returns 0 (yes) or 1 (no).
# Silent when there is no controlling terminal (pipe / CI / container).
prompt_yesno() {
    ( : < /dev/tty ) 2>/dev/null || return 1
    printf "\033[36m[INFO]\033[0m %s [Y/n] " "$1" > /dev/tty
    IFS= read -r _reply < /dev/tty || return 1
    case "$_reply" in
        [nN]|[nN][oO]) return 1 ;;
        *)             return 0 ;;
    esac
}

# Install Agent skills — prefer npx (unless WUJI_SKILLS_USE_SCRIPT=1), fallback to install-skills.sh
install_skills() {
    SKILLS_URL="https://raw.githubusercontent.com/${GITHUB_REPO}/main/scripts/install-skills.sh"
    if [ "${WUJI_SKILLS_USE_SCRIPT:-}" = "1" ]; then
        info "WUJI_SKILLS_USE_SCRIPT set, using install-skills.sh"
        fallback_install_skills
    elif command -v npx >/dev/null 2>&1; then
        info "using npx to install skills"
        npx -y skills add "${GITHUB_REPO}" || {
            warn "npx skills add failed, trying install-skills.sh..."
            fallback_install_skills
        }
    else
        info "using install-skills.sh to install skills"
        fallback_install_skills
    fi
}

fallback_install_skills() {
    _tmpfile=$(mktemp) || { warn "cannot create temp file"; return; }

    if command -v curl >/dev/null 2>&1; then
        curl -fsSL -o "$_tmpfile" "$SKILLS_URL" || { warn "skills download failed, skipping"; rm -f "$_tmpfile"; return; }
    elif command -v wget >/dev/null 2>&1; then
        wget -qO "$_tmpfile" "$SKILLS_URL" || { warn "skills download failed, skipping"; rm -f "$_tmpfile"; return; }
    else
        rm -f "$_tmpfile"
        warn "need curl or wget to install skills, skipping"
        return
    fi

    [ -s "$_tmpfile" ] || { warn "skills download empty, skipping"; rm -f "$_tmpfile"; return; }

    if sh "$_tmpfile"; then
        info "If your AI agent cannot find Skills, tell it to check ~/.agents/skills/wuji-*"
    else
        warn "skills installation failed, skipping"
    fi
    rm -f "$_tmpfile"
}

# Check if install dir is in PATH, append to shell config if not
ensure_path() {
    case ":$PATH:" in
        *:"$1":*) ;;
        *)
            line="export PATH=\"$1:\$PATH\""
            for rc in ".bashrc" ".zshrc" ".profile"; do
                rcfile="$HOME/$rc"
                [ -f "$rcfile" ] && ! grep -qxF "$line" "$rcfile" && echo "$line" >> "$rcfile"
            done
            info "added $1 to PATH (~/.bashrc, ~/.zshrc, etc.)"
            info "run 'source ~/.bashrc' or restart your shell to apply"
            ;;
    esac
}

# Detect system architecture
detect_arch() {
    arch=$(uname -m)
    case "$arch" in
        x86_64|amd64)  echo "amd64" ;;
        aarch64|arm64) echo "arm64" ;;
        *) error "unsupported arch: $arch" ;;
    esac
}

# Download file (single-line progress bar instead of the raw stats table)
download() {
    if command -v curl >/dev/null 2>&1; then
        curl -fL --progress-bar "$1" -o "$2"
    else
        wget -q --show-progress -O "$2" "$1"
    fi
}

# Fetch a URL to stdout (for API queries)
fetch_url() {
    if command -v curl >/dev/null 2>&1; then
        curl -fsL "$1" 2>/dev/null
    else
        wget -qO- "$1" 2>/dev/null
    fi
}

# Resolve "latest" to a concrete version via the GitHub releases API
# (releases/latest never points at a prerelease, matching what the
# public repo actually serves). Prints the version without the leading v.
resolve_latest_version() {
    api_url="https://api.github.com/repos/${GITHUB_REPO}/releases/latest"
    tag=$(fetch_url "$api_url" | awk -F'"' '/"tag_name":/ { print $4; exit }')
    [ -n "$tag" ] || error "cannot resolve the latest version from GitHub API (set VERSION=x.y.z to install a specific version)"
    echo "${tag#v}"
}

# Verify the downloaded binary against the sha256 digest that GitHub
# publishes for each release asset (same trust anchor as `wuji update`).
# Cannot fetch the expected digest → warn and continue (HTTPS already
# protects the transport); digest fetched but mismatched → hard fail.
verify_sha256() {
    file="$1"
    asset="$2"

    if ! command -v sha256sum >/dev/null 2>&1; then
        warn "sha256sum not found, skipping checksum verification"
        return 0
    fi

    api_url="https://api.github.com/repos/${GITHUB_REPO}/releases/tags/v${VERSION}"
    # Asset objects list "name" before "digest"; scan line by line and take
    # the digest of the matching asset. The release-level "name" resets the
    # flag, and no other nested object carries a "name" field.
    expected=$(fetch_url "$api_url" | awk -v asset="$asset" '
        /"name":/ { in_asset = index($0, "\"" asset "\"") > 0 }
        in_asset && /"digest":/ {
            if (match($0, /sha256:[0-9a-f]+/)) {
                hex = substr($0, RSTART + 7, RLENGTH - 7)
                if (length(hex) == 64) print hex
            }
            exit
        }')

    if [ -z "$expected" ]; then
        warn "cannot fetch checksum from GitHub API, skipping verification"
        return 0
    fi

    actual=$(sha256sum "$file" | awk '{print $1}')
    if [ "$actual" != "$expected" ]; then
        error "sha256 mismatch for $asset: expected $expected, got $actual (corrupted download, please retry the installation)"
    fi
    info "sha256 verified: $actual"
}

main() {

    # Check prerequisites
    need_cmd uname
    need_cmd mktemp
    if ! command -v curl >/dev/null 2>&1 && ! command -v wget >/dev/null 2>&1; then
        error "need curl or wget"
    fi

    # Detect architecture
    ARCH=$(detect_arch) || exit 1

    DEST="${INSTALL_DIR}/${BINARY_NAME}"

    if [ "${WUJI_SKIP_CLI:-}" != "1" ]; then
        # Resolve "latest" to a concrete version (error inside the command
        # substitution only exits the subshell, hence the explicit || exit)
        if [ "$VERSION" = "latest" ]; then
            VERSION=$(resolve_latest_version) || exit 1
            info "latest version: $VERSION"
        fi

        URL="https://github.com/${GITHUB_REPO}/releases/download/v${VERSION}/${BINARY_NAME}_${VERSION}_${ARCH}"

        TMP_DIR=$(mktemp -d)
        trap 'rm -rf "$TMP_DIR"' EXIT  # ensure cleanup
        TMPFILE="$TMP_DIR/$BINARY_NAME"

        info "downloading $URL to $TMPFILE"

        download "$URL" "$TMPFILE" || error "download failed, please try again later"

        verify_sha256 "$TMPFILE" "${BINARY_NAME}_${VERSION}_${ARCH}"

        # Install binary
        mkdir -p "$INSTALL_DIR" || error "cannot create $INSTALL_DIR"
        chmod +x "$TMPFILE"

        info "installing $TMPFILE to $DEST"

        mv "$TMPFILE" "$DEST" || error "cannot install to $DEST (is $INSTALL_DIR writable?)"

        echo ""
        success "wuji-cli installed to $DEST"
        success "run 'wuji --help' to get started"

        # Ensure install dir is in PATH. Must not modify PATH beforehand,
        # or the check would always pass and rc files would never be updated.
        ensure_path "$INSTALL_DIR"
    else
        info "WUJI_SKIP_CLI set, skipping CLI installation"
    fi

    # ── Optional: Agent Skills Installation ──
    echo ""
    if [ "${WUJI_SKIP_SKILLS:-}" = "1" ]; then
        info "WUJI_SKIP_SKILLS set, skipping skills installation"
    elif prompt_yesno "Install Wuji CLI Agent skills?"; then
        install_skills
    else
        info "Skipped. Install skills later via:"
        info "  npx skills add ${GITHUB_REPO}"
        info "  curl -fsSL https://raw.githubusercontent.com/${GITHUB_REPO}/main/scripts/install-skills.sh | sh"
    fi

    echo ""
    info "Setup complete"
    echo ""
}

main