#!/bin/sh
set -u

GITHUB_REPO="${GITHUB_REPO:-wuji-technology/wuji-cli}"

BASE_URL="https://github.com/${GITHUB_REPO}"

INSTALL_DIR="$HOME/.agents/skills"

info()  { printf "\033[36m[INFO]\033[0m %s\n" "$*"; }
error() { printf "\033[31m[ERROR]\033[0m %s\n" "$*" >&2; exit 1; }
success() { printf "\033[32m[SUCCESS]\033[0m %s\n" "$*"; }

need_cmd() { command -v "$1" >/dev/null 2>&1 || error "need '$1'"; }

need_cmd git
need_cmd mktemp

info "downloading skills from $BASE_URL"

TMP_DIR=$(mktemp -d)

trap 'rm -rf "$TMP_DIR"' EXIT  # ensure cleanup

git clone --depth 1 "$BASE_URL" "$TMP_DIR" || error "failed to clone $BASE_URL"
[ -d "$TMP_DIR/skills" ] || error "no skills/ directory in $BASE_URL"

mkdir -p "$INSTALL_DIR" || error "cannot create $INSTALL_DIR"
cp -a "$TMP_DIR/skills/." "$INSTALL_DIR/" || error "failed to copy skills to $INSTALL_DIR"

success "installed skills to $INSTALL_DIR"