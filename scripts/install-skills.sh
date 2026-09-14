#!/bin/sh
set -u

GITHUB_REPO="${GITHUB_REPO:-wuji-technology/wuji-cli}"

# VERSION 指定要安装的 Skills 对应的 release 版本（如 2026.8.31，不带 v）。
# 空 / latest → 跟随公开仓库默认分支（main 恒为最新发版配套内容，向后兼容）。
# CLI 自更新同步（wuji update / wuji update --skills）会注入当前 CLI 版本，
# 让 Skills 与该 release tag 下的配套内容严格对齐；install-cli.sh 的 VERSION
# 会被子进程继承，首装即按 CLI 版本配套安装。
VERSION="${VERSION:-}"

BASE_URL="https://github.com/${GITHUB_REPO}"

INSTALL_DIR="$HOME/.agents/skills"
# 安装落点不变量：两种安装模式都把 Skills 装到 INSTALL_DIR（universal）——
# - npx 模式：`npx skills add <src> -g -y -a universal $AGENTS`。`universal`
#   恒在名单首位，保证 canonical ~/.agents/skills 必装；上游对显式 `-a`
#   不会自动追加 universal（`ensureUniversalAgents` 只在无 `-a` 时执行，
#   而本脚本为规避上游 #1496 必须显式 `-a`），故须手动并入。`-a` 名单里
#   其余是已探测到的 agent，`-g` 下各落其专属 globalSkillsDir（额外分发）；
# - script 模式（无 npx / WUJI_SKILLS_USE_SCRIPT=1 / npx 失败回退）：直接 cp
#   到 INSTALL_DIR，刻意不做 per-agent 分发——不重复 npx 的职责：装了各种
#   agent 却没装 npx 的用户极少，per-agent 分发只由 npx 模式负责（npx 可用时）。
# 因此不存在「只装到 agent 专属目录而 universal 缺失」的路径；`wuji update`
# 的 CLI 复检目录即 INSTALL_DIR，同步后必然收敛到同目录。

info()  { printf "\033[36m[INFO]\033[0m %s\n" "$*"; }
warn()  { printf "\033[33m[WARN]\033[0m %s\n" "$*"; }
error() { printf "\033[31m[ERROR]\033[0m %s\n" "$*" >&2; exit 1; }
success() { printf "\033[32m[SUCCESS]\033[0m %s\n" "$*"; }

need_cmd() { command -v "$1" >/dev/null 2>&1 || error "need '$1'"; }

# detect_skills_agents — 输出空格分隔的已安装 agent 名称列表。
#
# 探测表参考自 npx skills（vercel-labs/skills 的 src/agents.ts，对照 skills@1.5.23）。
# 这张表是为了规避上游 bug 而存在的：skills CLI 在 `-g -y` 非交互路径会把
# 不支持全局安装的 project-only agent（PromptScript）无条件并入安装目标，导致
# 结尾误报 "Failed to install N"（上游 issue #1496，修复 PR #1421）。
# 上游合并修复后，这段探测与显式 `-a` 传参可以整体删掉，恢复为
# 直接 `npx --yes skills add "$GITHUB_REPO" -g -y`。
# promptscript / eve 没有 globalSkillsDir，不支持全局安装。
# universal 有全局安装目录，但 detectInstalled 恒为 false，不参与自动探测；
# 本脚本不在探测表里生成它，改由 main 组装 npx 名单时恒并入 `universal`
# （见下方调用处注释：上游显式 -a 不会自动追加 universal）。
# zenflow 与 zencoder 共享探测路径（~/.zencoder）和安装目录，表中 zencoder
# 条目等价覆盖 zenflow，不重复列出。
# cwd（当前工作区）探测与上游一致全部收录：replit / astrbot / codebuddy /
# continue / jazz 的 global 目录均为各自专属目录，不在 universal 覆盖面上。
# 上游新增或重命名 agent 时需要同步更新此表。
detect_skills_agents() {
    CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
    AGENTS=""
    _add() { case " $AGENTS " in *" $1 "*) ;; *) AGENTS="$AGENTS $1" ;; esac; }

    # $HOME 下的单路径探测
    for _spec in \
        "aider-desk:.aider-desk" \
        "antigravity:.gemini/antigravity" \
        "antigravity-cli:.gemini/antigravity-cli" \
        "astrbot:.astrbot" \
        "augment:.augment" \
        "bob:.bob" \
        "cline:.cline" \
        "codearts-agent:.codeartsdoer" \
        "codebuddy:.codebuddy" \
        "codemaker:.codemaker" \
        "codestudio:.codestudio" \
        "command-code:.commandcode" \
        "continue:.continue" \
        "cortex:.snowflake/cortex" \
        "cursor:.cursor" \
        "deepagents:.deepagents" \
        "dexto:.dexto" \
        "droid:.factory" \
        "firebender:.firebender" \
        "forgecode:.forge" \
        "gemini-cli:.gemini" \
        "github-copilot:.copilot" \
        "inference-sh:.inferencesh" \
        "jazz:.jazz" \
        "junie:.junie" \
        "iflow-cli:.iflow" \
        "kilo:.kilocode" \
        "kimi-code-cli:.kimi-code" \
        "kiro-cli:.kiro" \
        "kode:.kode" \
        "lingma:.lingma" \
        "loaf:.loaf" \
        "mcpjam:.mcpjam" \
        "moxby:.moxby" \
        "mux:.mux" \
        "openhands:.openhands" \
        "ona:.ona" \
        "pi:.pi/agent" \
        "qoder:.qoder" \
        "qoder-cn:.qoder-cn" \
        "qwen-code:.qwen" \
        "reasonix:.reasonix" \
        "rovodev:.rovodev" \
        "roo:.roo" \
        "tabnine-cli:.tabnine" \
        "terramind:.terramind" \
        "tinycloud:.tinycloud" \
        "trae:.trae" \
        "trae-cn:.trae-cn" \
        "warp:.warp" \
        "windsurf:.codeium/windsurf" \
        "zcode:.zcode" \
        "zencoder:.zencoder" \
        "neovate:.neovate" \
        "pochi:.pochi" \
        "adal:.adal"
    do
        [ -d "$HOME/${_spec#*:}" ] && _add "${_spec%%:*}"
    done

    # $CONFIG_HOME 下的探测
    for _spec in "amp:amp" "devin:devin" "goose:goose" "opencode:opencode" "zed:zed"; do
        [ -d "$CONFIG_HOME/${_spec#*:}" ] && _add "${_spec%%:*}"
    done

    # 支持环境变量覆盖的 home 目录（与上游一致）
    [ -d "${CLAUDE_CONFIG_DIR:-$HOME/.claude}" ] && _add claude-code
    { [ -d "${CODEX_HOME:-$HOME/.codex}" ] || [ -d /etc/codex ]; } && _add codex
    [ -d "${VIBE_HOME:-$HOME/.vibe}" ] && _add mistral-vibe
    [ -d "${HERMES_HOME:-$HOME/.hermes}" ] && _add hermes-agent
    [ -d "${AUTOHAND_HOME:-$HOME/.autohand}" ] && _add autohand-code
    [ -d "${GROK_HOME:-$HOME/.grok}" ] && _add grok

    # 多路径 / 特殊探测
    [ -d "$HOME/.config/crush" ] && _add crush
    { [ -d "$HOME/.openclaw" ] || [ -d "$HOME/.clawdbot" ] || [ -d "$HOME/.moltbot" ]; } && _add openclaw
    [ -d "$HOME/.kimi" ] && _add kimi-code-cli
    [ -d "$HOME/.config/kimchi" ] && _add kimchi
    { [ -d "$HOME/.minimax" ] || [ -d "/Applications/MiniMax Code.app" ]; } && _add minimax-code
    { [ -d "$HOME/.posit/assistant" ] || [ -d "$HOME/.positai" ]; } && _add posit-assistant
    [ -d "/Applications/ZCode.app" ] && _add zcode
    { [ -n "${FLATPAK_XDG_CONFIG_HOME:-}" ] && [ -d "$FLATPAK_XDG_CONFIG_HOME/zed" ]; } && _add zed
    # cwd（当前工作区）探测，与上游注册表一致：这些 agent 的 global 目录是
    # 各自专属目录（不在 universal 的 ~/.agents/skills 覆盖面上），且用户可能
    # 只在当前项目内配置——cwd 探测是覆盖该场景的唯一通道。
    [ -e .replit ] && _add replit
    [ -d data/skills ] && _add astrbot
    [ -d .codebuddy ] && _add codebuddy
    [ -d .continue ] && _add continue
    [ -d .jazz ] && _add jazz

    echo "${AGENTS# }"
}

# script_install — 克隆仓库并把 skills/ 复制到 ~/.agents/skills
script_install() {
    need_cmd git
    need_cmd mktemp

    info "downloading skills from $BASE_URL"

    TMP_DIR=$(mktemp -d)
    trap 'rm -rf "$TMP_DIR"' EXIT  # ensure cleanup

    if [ -n "$REF" ]; then
        info "installing skills from release tag $REF"
        git clone --depth 1 --branch "$REF" "$BASE_URL" "$TMP_DIR" \
            || error "failed to clone $BASE_URL at tag $REF (release not published?)"
    else
        git clone --depth 1 "$BASE_URL" "$TMP_DIR" || error "failed to clone $BASE_URL"
    fi
    [ -d "$TMP_DIR/skills" ] || error "no skills/ directory in $BASE_URL"

    mkdir -p "$INSTALL_DIR" || error "cannot create $INSTALL_DIR"
    cp -a "$TMP_DIR/skills/." "$INSTALL_DIR/" || error "failed to copy skills to $INSTALL_DIR"

    success "installed skills to $INSTALL_DIR"
    info "If your AI agent cannot find the skills, ask it to install them from ~/.agents/skills/wuji-*."
}

main() {
    # VERSION → release tag 名（v 前缀）。空 / latest → 空串（跟随默认分支）。
    # 其它值必须是 X.Y.Z。error 直接调用（非命令替换），无效值整脚本退出。
    # POSIX glob 的 * 可匹配任意字符且无结尾锚定，单条 [0-9]*.[0-9]*.[0-9]*
    # 会把 1.2.3x / 1x.2.3 放行；故先按字符白名单与形态拒绝（含非数字点字符、
    # 首尾点、连续点、三个及以上点），再要求恰好两点（*.*.* 即两点）。
    case "$VERSION" in
        "" | latest) REF="" ;;
        *[!0-9.]* | .* | *. | *..* | *.*.*.*)
            error "invalid VERSION '$VERSION' (expected X.Y.Z, 'latest', or empty)" ;;
        *.*.*) REF="v$VERSION" ;;
        *) error "invalid VERSION '$VERSION' (expected X.Y.Z, 'latest', or empty)" ;;
    esac

    if [ "${WUJI_SKILLS_USE_SCRIPT:-}" = "1" ]; then
        info "WUJI_SKILLS_USE_SCRIPT set, using script install"
        script_install
        return
    fi

    if ! command -v npx >/dev/null 2>&1; then
        info "npx not found, using script install"
        script_install
        return
    fi

    AGENTS="$(detect_skills_agents)"
    if [ -z "$AGENTS" ]; then
        warn "no supported agents detected, falling back to script install"
        script_install
        return
    fi

    info "installing skills for detected agents:${AGENTS}"
    # 规避上游 issue #1496：显式 -a 只装探测到的 agent，不含 PromptScript。
    # 上游修复合并后可改回不带 -a 的直接调用。
    # shellcheck disable=SC2086  # 刻意单词拆分：-a 是可变参数
    # `universal` 恒在名单首位：上游对显式 -a 不会自动追加 universal
    # （ensureUniversalAgents 只在无 -a 的自动探测路径执行），不并入则
    # 只探测到非 universal agent（如仅 claude-code）时不会落盘 CLI 复检
    # 目录 INSTALL_DIR（~/.agents/skills），`wuji update --skills` 复检失败。
    # -a 之后的多个名字会被上游贪婪收进同一 agent 列表（直到下一个 - 开头
    # 的参数），故 `-a universal $AGENTS` 语义 = [universal, ...探测结果]。
    # VERSION 指定时用 owner/repo#vX.Y.Z 形式让 npx skills 检出该 release tag
    SOURCE="$GITHUB_REPO${REF:+#${REF}}"
    if npx --yes skills add "$SOURCE" -g -y -a universal $AGENTS; then
        return
    fi
    warn "npx skills add failed, trying script install..."
    script_install
}

main
