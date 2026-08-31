[CmdletBinding()]
param(
    [string]$Version = $(if ($env:VERSION) { $env:VERSION } else { "latest" }),
    [string]$InstallDir = $env:INSTALL_DIR
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

$repo = if ($env:GITHUB_REPO) { $env:GITHUB_REPO } else { "wuji-technology/wuji-cli" }
$userAgent = "wuji-cli-installer"
$lock = $null
$tempDir = $null
$pending = $null
$backup = $null

function Write-Info([string]$Message) {
    Write-Host "[INFO] $Message" -ForegroundColor Cyan
}

function Write-Success([string]$Message) {
    Write-Host "[SUCCESS] $Message" -ForegroundColor Green
}

function Add-ToUserPath([string]$Directory) {
    $normalized = [IO.Path]::GetFullPath($Directory).TrimEnd('\')
    $userPath = [Environment]::GetEnvironmentVariable("Path", "User")
    $entries = @($userPath -split ';' | Where-Object { $_ })
    $exists = $entries | Where-Object {
        [string]::Equals(
            [IO.Path]::GetFullPath($_).TrimEnd('\'),
            $normalized,
            [StringComparison]::OrdinalIgnoreCase
        )
    }

    if (-not $exists) {
        $newPath = if ($userPath) { "$userPath;$Directory" } else { $Directory }
        [Environment]::SetEnvironmentVariable("Path", $newPath, "User")
        Write-Info "Added $Directory to the user PATH."
    }

    $sessionEntries = @($env:Path -split ';' | Where-Object { $_ })
    $inSession = $sessionEntries | Where-Object {
        [string]::Equals(
            [IO.Path]::GetFullPath($_).TrimEnd('\'),
            $normalized,
            [StringComparison]::OrdinalIgnoreCase
        )
    }
    if (-not $inSession) {
        $env:Path = "$Directory;$env:Path"
    }
}

try {
    if (-not $InstallDir) {
        if (-not $env:LOCALAPPDATA) {
            throw "LOCALAPPDATA is not set; cannot choose a user installation directory."
        }
        $InstallDir = Join-Path $env:LOCALAPPDATA "Programs\Wuji\bin"
    }

    $nativeArch = if ($env:PROCESSOR_ARCHITEW6432) {
        $env:PROCESSOR_ARCHITEW6432
    } else {
        $env:PROCESSOR_ARCHITECTURE
    }
    if ($nativeArch -ne "AMD64") {
        throw "Unsupported Windows architecture: $nativeArch (only x86_64 is supported)."
    }

    $headers = @{ "User-Agent" = $userAgent }
    if ($Version -eq "latest") {
        $apiUrl = "https://api.github.com/repos/$repo/releases/latest"
    } else {
        $Version = $Version.TrimStart('v')
        $apiUrl = "https://api.github.com/repos/$repo/releases/tags/v$Version"
    }

    Write-Info "Resolving Wuji CLI $Version..."
    $release = Invoke-RestMethod -Uri $apiUrl -Headers $headers
    $resolvedVersion = ([string]$release.tag_name).TrimStart('v')
    $assetName = "wuji_${resolvedVersion}_x86_64-pc-windows-msvc.zip"
    $assets = @($release.assets | Where-Object { $_.name -eq $assetName })
    if ($assets.Count -ne 1) {
        throw "Release v$resolvedVersion does not contain $assetName."
    }
    $asset = $assets[0]

    $digestProperty = $asset.PSObject.Properties["digest"]
    if (-not $digestProperty -or -not ([string]$digestProperty.Value).StartsWith("sha256:")) {
        throw "Release asset $assetName does not publish a SHA-256 digest."
    }
    $expectedHash = ([string]$digestProperty.Value).Substring(7).ToLowerInvariant()

    $tempDir = Join-Path ([IO.Path]::GetTempPath()) ("wuji-install-" + [Guid]::NewGuid().ToString("N"))
    $extractDir = Join-Path $tempDir "extract"
    $archive = Join-Path $tempDir $assetName
    New-Item -ItemType Directory -Path $extractDir -Force | Out-Null

    Write-Info "Downloading $assetName..."
    Invoke-WebRequest -UseBasicParsing -Uri $asset.browser_download_url -Headers $headers -OutFile $archive

    $actualHash = (Get-FileHash -LiteralPath $archive -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($actualHash -ne $expectedHash) {
        throw "SHA-256 mismatch for $assetName. Expected $expectedHash, got $actualHash."
    }
    Write-Info "SHA-256 verified: $actualHash"

    Expand-Archive -LiteralPath $archive -DestinationPath $extractDir
    $binary = Join-Path $extractDir "wuji.exe"
    $files = @(Get-ChildItem -LiteralPath $extractDir -File -Recurse)
    if ($files.Count -ne 1 -or -not [string]::Equals(
        $files[0].FullName,
        $binary,
        [StringComparison]::OrdinalIgnoreCase
    )) {
        throw "$assetName must contain exactly one root-level wuji.exe."
    }

    $versionOutput = (& $binary --version 2>&1) -join " "
    $versionExitCode = $LASTEXITCODE
    $versionTokens = @($versionOutput -split '\s+' | Where-Object { $_ })
    $reportedVersion = if ($versionTokens.Count -gt 0) { $versionTokens[-1] } else { $null }
    if ($versionExitCode -ne 0 -or $reportedVersion -ne $resolvedVersion) {
        throw "Downloaded wuji.exe failed version validation for v$resolvedVersion."
    }

    New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null
    $lockPath = Join-Path $InstallDir ".install.lock"
    try {
        $lock = [IO.File]::Open(
            $lockPath,
            [IO.FileMode]::OpenOrCreate,
            [IO.FileAccess]::ReadWrite,
            [IO.FileShare]::None
        )
    } catch {
        throw "Another Wuji CLI install or update is using $InstallDir."
    }

    $destination = Join-Path $InstallDir "wuji.exe"
    $pending = Join-Path $InstallDir (".wuji-install-" + [Guid]::NewGuid().ToString("N") + ".exe")
    $backup = Join-Path $InstallDir ".wuji-install-backup.exe"
    Copy-Item -LiteralPath $binary -Destination $pending

    if (Test-Path -LiteralPath $destination) {
        if (Test-Path -LiteralPath $backup) {
            Remove-Item -LiteralPath $backup -Force
        }
        Move-Item -LiteralPath $destination -Destination $backup
    }

    try {
        Move-Item -LiteralPath $pending -Destination $destination
        $pending = $null
        $installedVersion = (& $destination --version 2>&1) -join " "
        $installedVersionExitCode = $LASTEXITCODE
        $installedVersionTokens = @($installedVersion -split '\s+' | Where-Object { $_ })
        $reportedInstalledVersion = if ($installedVersionTokens.Count -gt 0) {
            $installedVersionTokens[-1]
        } else {
            $null
        }
        if ($installedVersionExitCode -ne 0 -or $reportedInstalledVersion -ne $resolvedVersion) {
            throw "Installed wuji.exe failed version validation."
        }
    } catch {
        if (Test-Path -LiteralPath $backup) {
            if (Test-Path -LiteralPath $destination) {
                Remove-Item -LiteralPath $destination -Force
            }
            Move-Item -LiteralPath $backup -Destination $destination
            $backup = $null
        }
        throw
    }

    if (Test-Path -LiteralPath $backup) {
        Remove-Item -LiteralPath $backup -Force
        $backup = $null
    }

    Add-ToUserPath $InstallDir
    Write-Success "Wuji CLI v$resolvedVersion installed to $destination"
    Write-Info "Open a new terminal, then run 'wuji --help' to get started."
} finally {
    if ($lock) {
        $lock.Dispose()
    }
    if ($pending -and (Test-Path -LiteralPath $pending)) {
        Remove-Item -LiteralPath $pending -Force
    }
    if ($tempDir -and (Test-Path -LiteralPath $tempDir)) {
        Remove-Item -LiteralPath $tempDir -Recurse -Force
    }
}
