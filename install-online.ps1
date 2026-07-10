

[CmdletBinding()]
param(
        [string] $Repo = "yosrihadi/ChatGpt-Rtl",
    [string] $Branch = "v0.1.9"
)

 
$ErrorActionPreference = "Stop"

function Write-Info { param([string] $Message) Write-Host "  [*] $Message" }
function Write-Ok   { param([string] $Message) Write-Host "  [+] $Message" -ForegroundColor Green }
function Write-Step { param([string] $Message) Write-Host ""; Write-Host "==> $Message" -ForegroundColor Cyan }


Write-Host ""
Write-Host "============================================================"
Write-Host "  RT-AI Chatgpt RTL Patch - Online Uninstaller"
Write-Host "  www.fb.com/yosrihadi"
Write-Host "============================================================"

if (-not (Get-Command node.exe -ErrorAction SilentlyContinue)) {
    throw "Node.js is not installed. Install it from https://nodejs.org/ and rerun."
}

$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("chatgpt-rtl-rt-ai-" + [guid]::NewGuid().ToString("N"))
$zipPath = Join-Path $tempRoot "source.zip"
$extractDir = Join-Path $tempRoot "extract"

try {
    New-Item -ItemType Directory -Path $tempRoot | Out-Null
    New-Item -ItemType Directory -Path $extractDir | Out-Null

    # Treat a value that looks like a semver tag (e.g. v0.1.2) as a tag ref.
    # Anything else (main, dev, feature/x) goes through refs/heads/.
    if ($Branch -match '^v\d+\.') {
        $zipUrl = "https://codeload.github.com/$Repo/zip/refs/tags/$Branch"
    } else {
        $zipUrl = "https://codeload.github.com/$Repo/zip/refs/heads/$Branch"
    }
    Write-Step "Downloading $zipUrl"
    Invoke-WebRequest -Uri $zipUrl -OutFile $zipPath -UseBasicParsing
    Write-Ok "Downloaded to $zipPath"

    Write-Step "Extracting"
    Expand-Archive -LiteralPath $zipPath -DestinationPath $extractDir -Force
    $sourceDir = Get-ChildItem -LiteralPath $extractDir -Directory | Select-Object -First 1
    if (-not $sourceDir) { throw "Could not locate extracted source directory." }
    Write-Ok "Extracted to $($sourceDir.FullName)"

    $patcher = Join-Path $sourceDir.FullName "patch.ps1"
    if (-not (Test-Path -LiteralPath $patcher)) {
        throw "patch.ps1 not found in the downloaded source."
    }

    Write-Step "Running installer"
    # Spawn a child PowerShell with explicit -ExecutionPolicy Bypass so the
    # one-line installer works even when the user's session policy is
    # Restricted (the default on many Windows installs). This sidesteps the
    # "cannot be loaded because running scripts is disabled" error without
    # asking users to change any system-wide policy.
    $psExe = (Get-Process -Id $PID).Path
    if (-not $psExe) { $psExe = "powershell.exe" }
    & $psExe -NoProfile -ExecutionPolicy Bypass -File $patcher -Install
    if ($LASTEXITCODE -ne 0) {
        throw "Installer exited with code $LASTEXITCODE."
    }
} finally {
    if (Test-Path -LiteralPath $tempRoot) {
        Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
}
