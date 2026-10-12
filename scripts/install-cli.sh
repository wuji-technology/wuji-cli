#!/bin/sh
set -u

# "latest" 在安装时通过 GitHub API 解析为最新 release
# 设 VERSION=x.y.z 可指定具体版本。
VERSION="${VERSION:-latest}"
GITHUB_REPO="${GITHUB_REPO:-wuji-technology/wuji-cli}"

BINARY_NAME="wuji"
INSTALL_DIR="${INSTALL_DIR:-$HOME/.local/bin}"

info()  { printf "\033[36m[INFO]\033[0m %s\n" "$*"; }
warn()  { printf "\033[33m[WARN]\033[0m %s\n" "$*"; }
error() { printf "\033[31m[ERROR]\033[0m %s\n" "$*" >&2; exit 1; }
success() { printf "\033[32m[SUCCESS]\033[0m %s\n" "$*"; }

need_cmd() { command -v "$1" >/dev/null 2>&1 || error "need '$1'"; }

# 在 /dev/tty 上询问，默认答案为 yes；返回 0（是）或 1（否）。
# 没有控制终端时（管道 / CI / 容器）静默返回。
prompt_yesno() {
    ( : < /dev/tty ) 2>/dev/null || return 1
    printf "\033[36m[INFO]\033[0m %s [Y/n] " "$1" > /dev/tty
    IFS= read -r _reply < /dev/tty || return 1
    case "$_reply" in
        [nN]|[nN][oO]) return 1 ;;
        *)             return 0 ;;
    esac
}

# 从公开仓下载并执行 install-skills.sh
install_skills() {
    SKILLS_URL="https://raw.githubusercontent.com/${GITHUB_REPO}/main/scripts/install-skills.sh"
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

    sh "$_tmpfile" || warn "skills installation failed, skipping"
    rm -f "$_tmpfile"
}

# 检查安装目录是否在 PATH 中，不在则追加到 shell 配置文件
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

# 探测本机对应的 release 目标三元组。
detect_target() {
    os=$(uname -s)
    arch=$(uname -m)
    case "$os:$arch" in
        Linux:x86_64|Linux:amd64)   echo "x86_64-unknown-linux-gnu" ;;
        Linux:aarch64|Linux:arm64)  echo "aarch64-unknown-linux-gnu" ;;
        Darwin:aarch64|Darwin:arm64) echo "aarch64-apple-darwin" ;;
        *) error "unsupported platform: $os/$arch" ;;
    esac
}

# 下载文件（用单行进度条替代默认的统计表输出）
download() {
    if command -v curl >/dev/null 2>&1; then
        curl -fL --progress-bar "$1" -o "$2"
    else
        wget -q --show-progress -O "$2" "$1"
    fi
}

# 取 URL 内容到 stdout（用于 GitHub API 查询）。
# api.github.com 匿名配额是 60 次/时/IP，共享 / NAT 出口很容易耗尽，表现是安装
# 直接失败、只报一句 "cannot fetch the SHA-256 digest"。GH_TOKEN / GITHUB_TOKEN
# （变量与优先级同 `wuji update`）可把配额提到 5000 次/时。请求失败时不再丢弃
# curl 的 stderr，坏因留在安装日志里可见。
fetch_url() {
    # 两个变量各自去空白后再取第一个非空值：`${GH_TOKEN:-…}` 只把空串当未设置，
    # 纯空白的 GH_TOKEN 会先被选中再被清空，回退分支永远走不到，等于丢了
    # GITHUB_TOKEN。语义与 `wuji update`（分别 trim 后取第一个非空）一致。
    _gh_token=$(printf '%s' "${GH_TOKEN:-}" | tr -d '[:space:]')
    _github_token=$(printf '%s' "${GITHUB_TOKEN:-}" | tr -d '[:space:]')
    _token="${_gh_token:-$_github_token}"
    if command -v curl >/dev/null 2>&1; then
        if [ -n "$_token" ]; then
            curl -fsSL -H "Authorization: Bearer $_token" "$1"
        else
            curl -fsSL "$1"
        fi
    else
        if [ -n "$_token" ]; then
            wget -qO- --header="Authorization: Bearer $_token" "$1"
        else
            wget -qO- "$1"
        fi
    fi
}

# 通过 GitHub releases API 把 "latest" 解析为具体版本
#（releases/latest 不会指向预发布版本，与公开仓实际提供的内容一致）。
# 输出不带 v 前缀的版本号。
resolve_latest_version() {
    api_url="https://api.github.com/repos/${GITHUB_REPO}/releases/latest"
    tag=$(fetch_url "$api_url" | awk -F'"' '/"tag_name":/ { print $4; exit }')
    [ -n "$tag" ] || error "cannot resolve the latest version from GitHub API (set VERSION=x.y.z to install a specific version; set GH_TOKEN or GITHUB_TOKEN if the anonymous rate limit is exhausted)"
    echo "${tag#v}"
}

# 用 GitHub 给每个 release 资产发布的 sha256 digest 校验下载的压缩包
#（与 `wuji update` 同一个信任锚）。
verify_sha256() {
    file="$1"
    asset="$2"

    api_url="https://api.github.com/repos/${GITHUB_REPO}/releases/tags/v${VERSION}"
    # 资产对象里 "name" 出现在 "digest" 之前；逐行扫描取匹配资产的 digest。
    # release 这一层的 "name" 会重置标记，其它嵌套对象都不含 "name" 字段。
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
        error "cannot fetch the SHA-256 digest for $asset from GitHub API (set GH_TOKEN or GITHUB_TOKEN if the anonymous rate limit is exhausted)"
    fi

    if command -v sha256sum >/dev/null 2>&1; then
        actual=$(sha256sum "$file" | awk '{print $1}')
    elif command -v shasum >/dev/null 2>&1; then
        actual=$(shasum -a 256 "$file" | awk '{print $1}')
    else
        error "need sha256sum or shasum to verify $asset"
    fi
    if [ "$actual" != "$expected" ]; then
        error "sha256 mismatch for $asset: expected $expected, got $actual (corrupted download, please retry the installation)"
    fi
    info "sha256 verified: $actual"
}

main() {

    # 检查依赖命令
    need_cmd uname
    need_cmd mktemp
    need_cmd tar
    if ! command -v curl >/dev/null 2>&1 && ! command -v wget >/dev/null 2>&1; then
        error "need curl or wget"
    fi

    # 探测确切的 release 目标（OS + 架构）。
    TARGET=$(detect_target) || exit 1

    DEST="${INSTALL_DIR}/${BINARY_NAME}"

    # 把 "latest" 解析为具体版本（命令替换里的 error 只退出子 shell，
    # 所以这里显式写 || exit）。
    # 放在 WUJI_SKIP_CLI 分支之前解析，skills 这一步才会同样被 pin 住。
    # 两步都关掉时跳过：没有需要 pin 的东西，而匿名 GitHub API 请求会在
    # 网络故障或配额耗尽时把整条安装判失败，本可以什么都不做。
    if [ "${WUJI_SKIP_CLI:-}" != "1" ] || [ "${WUJI_SKIP_SKILLS:-}" != "1" ]; then
        if [ "$VERSION" = "latest" ]; then
            VERSION=$(resolve_latest_version) || exit 1
            info "latest version: $VERSION"
        fi
    fi
    # skills 这步以子进程方式运行 install-skills.sh：把解析出的版本 export 出去，
    # 让 skills 从对应的 release tag 安装，而不是公开仓的默认分支。
    # export 必须留在 WUJI_SKIP_CLI 分支之外——否则只装 skills 的那次运行会装到
    # 未 pin 的内容，用户传的 VERSION=x.y.z 也会被忽略。
    export VERSION

    if [ "${WUJI_SKIP_CLI:-}" != "1" ]; then
        ASSET="${BINARY_NAME}_${VERSION}_${TARGET}.tar.gz"
        URL="https://github.com/${GITHUB_REPO}/releases/download/v${VERSION}/${ASSET}"

        TMP_DIR=$(mktemp -d)
        trap 'rm -rf "$TMP_DIR"' EXIT  # 确保退出时清理
        TMPFILE="$TMP_DIR/$ASSET"
        EXTRACT_DIR="$TMP_DIR/extract"

        info "downloading $URL to $TMPFILE"

        download "$URL" "$TMPFILE" || error "download failed, please try again later"

        verify_sha256 "$TMPFILE" "$ASSET"

        entries=$(tar -tzf "$TMPFILE") || error "cannot read $ASSET"
        [ "$entries" = "$BINARY_NAME" ] || error "$ASSET must contain exactly one root-level $BINARY_NAME"
        mkdir -p "$EXTRACT_DIR" || error "cannot create extraction directory"
        EXTRACTED="$EXTRACT_DIR/$BINARY_NAME"
        tar -xOzf "$TMPFILE" > "$EXTRACTED" || error "cannot extract $ASSET"
        [ -f "$EXTRACTED" ] || error "$ASSET does not contain a regular $BINARY_NAME binary"

        # 校验版本后安装二进制
        chmod +x "$EXTRACTED"
        reported_version=$("$EXTRACTED" --version 2>/dev/null | awk 'END {print $NF}')
        [ "$reported_version" = "$VERSION" ] || error "$BINARY_NAME reports version '${reported_version:-<missing>}', expected '$VERSION'"

        mkdir -p "$INSTALL_DIR" || error "cannot create $INSTALL_DIR"

        info "installing $EXTRACTED to $DEST"

        mv "$EXTRACTED" "$DEST" || error "cannot install to $DEST (is $INSTALL_DIR writable?)"

        echo ""
        success "wuji-cli installed to $DEST"
        success "run 'wuji --help' to get started"

        # 确保安装目录在 PATH 中。检查前不能先改 PATH，否则检查恒真、
        # rc 文件永远不会被写入。
        ensure_path "$INSTALL_DIR"
    else
        info "WUJI_SKIP_CLI set, skipping CLI installation"
    fi

    # ── 可选：安装 Agent Skills ──
    echo ""
    if [ "${WUJI_SKIP_SKILLS:-}" = "1" ]; then
        info "WUJI_SKIP_SKILLS set, skipping skills installation"
    elif prompt_yesno "Install Wuji CLI Agent skills?"; then
        install_skills
    else
        info "Skipped. Install skills later via:"
        info "  npx skills add ${GITHUB_REPO} -g"
        info "  curl -fsSL https://raw.githubusercontent.com/${GITHUB_REPO}/main/scripts/install-skills.sh | sh"
    fi

    echo ""
    info "Setup complete"
    echo ""
}

main
