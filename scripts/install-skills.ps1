[CmdletBinding()]
param(
    [string]$Version = $(if ($env:VERSION) { $env:VERSION } else { "" }),
    [string]$Repo = $(if ($env:GITHUB_REPO) { $env:GITHUB_REPO } else { "wuji-technology/wuji-cli" }),
    [string]$InstallDir = $(
        $profile = if ($env:USERPROFILE) { $env:USERPROFILE } elseif ($env:HOME) { $env:HOME } else { [Environment]::GetFolderPath("UserProfile") }
        Join-Path $profile ".agents\skills"
    )
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# Ensure AppData\Local exists in isolated/gray test user profiles (prevents Volta/npm crash on missing LocalAppData)
if ($env:USERPROFILE -and -not (Test-Path (Join-Path $env:USERPROFILE "AppData\Local"))) {
    try {
        $null = New-Item -ItemType Directory -Force -Path (Join-Path $env:USERPROFILE "AppData\Local") -ErrorAction SilentlyContinue
    } catch {}
}

function Write-Info([string]$Message) {
    Write-Host "[INFO] $Message" -ForegroundColor Cyan
}

function Write-Warn([string]$Message) {
    Write-Host "[WARN] $Message" -ForegroundColor Yellow
}

function Write-Success([string]$Message) {
    Write-Host "[SUCCESS] $Message" -ForegroundColor Green
}

function Detect-SkillsAgents {
    $userProfile = if ($env:USERPROFILE) { $env:USERPROFILE } elseif ($env:HOME) { $env:HOME } else { [Environment]::GetFolderPath("UserProfile") }
    $appData = if ($env:APPDATA) { $env:APPDATA } else { Join-Path $userProfile "AppData\Roaming" }
    $agents = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)


    $profileSpecs = @{
        "aider-desk" = ".aider-desk"
        "antigravity" = ".gemini\antigravity"
        "antigravity-cli" = ".gemini\antigravity-cli"
        "astrbot" = ".astrbot"
        "augment" = ".augment"
        "bob" = ".bob"
        "cline" = ".cline"
        "codearts-agent" = ".codeartsdoer"
        "codebuddy" = ".codebuddy"
        "codemaker" = ".codemaker"
        "codestudio" = ".codestudio"
        "command-code" = ".commandcode"
        "continue" = ".continue"
        "cortex" = ".snowflake\cortex"
        "cursor" = ".cursor"
        "deepagents" = ".deepagents"
        "dexto" = ".dexto"
        "droid" = ".factory"
        "firebender" = ".firebender"
        "forgecode" = ".forge"
        "gemini-cli" = ".gemini"
        "github-copilot" = ".copilot"
        "inference-sh" = ".inferencesh"
        "jazz" = ".jazz"
        "junie" = ".junie"
        "iflow-cli" = ".iflow"
        "kilo" = ".kilocode"
        "kimi-code-cli" = ".kimi-code"
        "kiro-cli" = ".kiro"
        "kode" = ".kode"
        "lingma" = ".lingma"
        "loaf" = ".loaf"
        "mcpjam" = ".mcpjam"
        "moxby" = ".moxby"
        "mux" = ".mux"
        "openhands" = ".openhands"
        "ona" = ".ona"
        "pi" = ".pi\agent"
        "qoder" = ".qoder"
        "qoder-cn" = ".qoder-cn"
        "qwen-code" = ".qwen"
        "reasonix" = ".reasonix"
        "rovodev" = ".rovodev"
        "roo" = ".roo"
        "tabnine-cli" = ".tabnine"
        "terramind" = ".terramind"
        "tinycloud" = ".tinycloud"
        "trae" = ".trae"
        "trae-cn" = ".trae-cn"
        "warp" = ".warp"
        "windsurf" = ".codeium\windsurf"
        "zcode" = ".zcode"
        "zencoder" = ".zencoder"
        "neovate" = ".neovate"
        "pochi" = ".pochi"
        "adal" = ".adal"
    }

    foreach ($pair in $profileSpecs.GetEnumerator()) {
        $p = Join-Path $userProfile $pair.Value
        if (Test-Path -LiteralPath $p -PathType Container) {
            [void]$agents.Add($pair.Key)
        }
    }


    $appDataSpecs = @{
        "amp" = "amp"
        "devin" = "devin"
        "goose" = "goose"
        "opencode" = "opencode"
        "zed" = "zed"
    }
    foreach ($pair in $appDataSpecs.GetEnumerator()) {
        $p = Join-Path $appData $pair.Value
        if (Test-Path -LiteralPath $p -PathType Container) {
            [void]$agents.Add($pair.Key)
        }
    }


    $claudeDir = if ($env:CLAUDE_CONFIG_DIR) { $env:CLAUDE_CONFIG_DIR } else { Join-Path $userProfile ".claude" }
    if (Test-Path -LiteralPath $claudeDir -PathType Container) { [void]$agents.Add("claude-code") }

    $codexDir = if ($env:CODEX_HOME) { $env:CODEX_HOME } else { Join-Path $userProfile ".codex" }
    if (Test-Path -LiteralPath $codexDir -PathType Container) { [void]$agents.Add("codex") }

    $vibeDir = if ($env:VIBE_HOME) { $env:VIBE_HOME } else { Join-Path $userProfile ".vibe" }
    if (Test-Path -LiteralPath $vibeDir -PathType Container) { [void]$agents.Add("mistral-vibe") }

    $hermesDir = if ($env:HERMES_HOME) { $env:HERMES_HOME } else { Join-Path $userProfile ".hermes" }
    if (Test-Path -LiteralPath $hermesDir -PathType Container) { [void]$agents.Add("hermes-agent") }

    $autohandDir = if ($env:AUTOHAND_HOME) { $env:AUTOHAND_HOME } else { Join-Path $userProfile ".autohand" }
    if (Test-Path -LiteralPath $autohandDir -PathType Container) { [void]$agents.Add("autohand-code") }

    $grokDir = if ($env:GROK_HOME) { $env:GROK_HOME } else { Join-Path $userProfile ".grok" }
    if (Test-Path -LiteralPath $grokDir -PathType Container) { [void]$agents.Add("grok") }


    if (Test-Path -LiteralPath (Join-Path $userProfile ".kimi") -PathType Container) { [void]$agents.Add("kimi-code-cli") }
    if (Test-Path -LiteralPath (Join-Path $userProfile ".openclaw") -PathType Container) { [void]$agents.Add("openclaw") }

    if (Test-Path -LiteralPath ".replit" -PathType Leaf) { [void]$agents.Add("replit") }
    if (Test-Path -LiteralPath "data\skills" -PathType Container) { [void]$agents.Add("astrbot") }
    if (Test-Path -LiteralPath ".codebuddy" -PathType Container) { [void]$agents.Add("codebuddy") }
    if (Test-Path -LiteralPath ".continue" -PathType Container) { [void]$agents.Add("continue") }
    if (Test-Path -LiteralPath ".jazz" -PathType Container) { [void]$agents.Add("jazz") }

    return $agents
}

function Invoke-ScriptInstall([string]$BaseUrl, [string]$Ref, [string]$TargetDir) {
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
        throw "git is required for script-based skills installation."
    }

    Write-Info "Downloading skills from $BaseUrl"
    $tempDir = Join-Path ([IO.Path]::GetTempPath()) ("wuji-skills-" + [Guid]::NewGuid().ToString("N"))
    [void][IO.Directory]::CreateDirectory($tempDir)

    try {
        $previousEap = $ErrorActionPreference
        try {
            $ErrorActionPreference = "Continue"
            if ($Ref) {
                Write-Info "Installing skills from release tag $Ref"
                & git clone --depth 1 --branch $Ref $BaseUrl $tempDir
                if ($LASTEXITCODE -ne 0) {
                    throw "Failed to clone $BaseUrl at tag $Ref (release not published?)"
                }
            } else {
                & git clone --depth 1 $BaseUrl $tempDir
                if ($LASTEXITCODE -ne 0) {
                    throw "Failed to clone $BaseUrl"
                }
            }
        } finally {
            $ErrorActionPreference = $previousEap
        }

        $sourceSkills = Join-Path $tempDir "skills"
        if (-not (Test-Path -LiteralPath $sourceSkills -PathType Container)) {
            throw "No skills\ directory in $BaseUrl"
        }

        if (-not (Test-Path -LiteralPath $TargetDir)) {
            [void][IO.Directory]::CreateDirectory($TargetDir)
        }



        Get-ChildItem -LiteralPath $sourceSkills | Copy-Item -Destination $TargetDir -Recurse -Force

        Write-Success "Installed skills to $TargetDir"
        Write-Info "If your AI agent cannot find the skills, ask it to install them from $TargetDir\wuji-*."
    } finally {
        if (Test-Path -LiteralPath $tempDir) {
            Remove-Item -LiteralPath $tempDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

try {
    $ref = ""
    if (-not [string]::IsNullOrWhiteSpace($Version) -and $Version -ne "latest") {
        if ($Version -notmatch '^\d+\.\d+\.\d+$') {
            throw "Invalid Version '$Version' (expected X.Y.Z, 'latest', or empty)."
        }
        $ref = "v$Version"
    }

    $baseUrl = "https://github.com/$Repo"

    if ($env:WUJI_SKILLS_USE_SCRIPT -eq "1") {
        Write-Info "WUJI_SKILLS_USE_SCRIPT set, using script install"
        Invoke-ScriptInstall -BaseUrl $baseUrl -Ref $ref -TargetDir $InstallDir
        return
    }

    $npxCmd = Get-Command npx -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $npxCmd) {
        Write-Info "npx not found, using script install"
        Invoke-ScriptInstall -BaseUrl $baseUrl -Ref $ref -TargetDir $InstallDir
        return
    }

    $agents = @(Detect-SkillsAgents)
    if ($agents.Count -eq 0) {
        Write-Warn "No supported agents detected, falling back to script install"
        Invoke-ScriptInstall -BaseUrl $baseUrl -Ref $ref -TargetDir $InstallDir
        return
    }

    Write-Info "Installing skills for detected agents: $($agents -join ' ')"
    $source = if ($ref) { "$Repo#$ref" } else { $Repo }


    $npxArgs = @("--yes", "skills", "add", $source, "-g", "-y", "-a", "universal") + $agents


    $npxExit = 1
    $previousEap = $ErrorActionPreference
    try {
        $ErrorActionPreference = "Continue"
        & $npxCmd.Source $npxArgs
        $npxExit = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $previousEap
    }
    if ($npxExit -eq 0) {
        return
    }

    Write-Warn "npx skills add failed, trying script install..."
    Invoke-ScriptInstall -BaseUrl $baseUrl -Ref $ref -TargetDir $InstallDir
} catch {
    Write-Host "[ERROR] $_" -ForegroundColor Red
    throw
}
