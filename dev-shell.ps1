$ErrorActionPreference = "Stop"

# =========================
# PATH SETUP
# =========================
$GitPath  = "C:\Users\User\Documents\PortableGit\cmd"
$NodePath = "C:\Users\User\OneDrive\Документи\node-v20.20.1-win-x64"

$env:Path = "$GitPath;$NodePath;$env:Path"

# =========================
# PROJECT PATHS
# =========================
$ProjectRoot = $PSScriptRoot
$NpmCli = Join-Path $NodePath "node_modules\npm\bin\npm-cli.js"
$ClaspEntry = Join-Path $ProjectRoot "node_modules\@google\clasp\build\src\index.js"

Set-Location $ProjectRoot

# =========================
# BASIC CHECKS
# =========================
if (-not (Test-Path (Join-Path $GitPath "git.exe"))) {
    throw "git.exe not found: $GitPath\git.exe"
}

if (-not (Test-Path (Join-Path $NodePath "node.exe"))) {
    throw "node.exe not found: $NodePath\node.exe"
}

if (-not (Test-Path $NpmCli)) {
    throw "npm-cli.js not found: $NpmCli"
}

if (-not (Test-Path $ClaspEntry)) {
    throw "clasp entry not found: $ClaspEntry"
}

# =========================
# FUNCTIONS
# =========================
function npmps {
    node $NpmCli @args
}

function clasp {
    node $ClaspEntry @args
}

function gas-status {
    clasp status
}

function gas-pull {
    clasp pull
}

function gas-push {
    clasp push
}

function gas-watch {
    Set-ExecutionPolicy -Scope Process Bypass
    .\watch-sync-simple.ps1
}

function git-status-short {
    git status --short
}

function git-save {
    param(
        [string]$Message = "update"
    )
    git add .
    git commit -m $Message
}

function git-sync {
    param(
        [string]$Message = "update"
    )
    git add .
    git commit -m $Message
    git push
}

function project-health {
    Write-Host ""
    Write-Host "=== ENVIRONMENT ==="
    git --version
    node -v
    npmps -v
    clasp --version
    Write-Host ""
    Write-Host "=== GIT STATUS ==="
    git status --short
    Write-Host ""
    Write-Host "=== GAS STATUS ==="
    clasp status
    Write-Host ""
}

# =========================
# NPM CONFIG
# =========================
npmps config set script-shell powershell.exe | Out-Null

# =========================
# READY MESSAGE
# =========================
Write-Host ""
Write-Host "Environment loaded."
Write-Host "Project root: $ProjectRoot"
Write-Host ""
Write-Host "Available commands:"
Write-Host "  npmps -v"
Write-Host "  clasp --version"
Write-Host "  gas-status"
Write-Host "  gas-pull"
Write-Host "  gas-push"
Write-Host "  gas-watch"
Write-Host "  git-status-short"
Write-Host "  git-save ""message"""
Write-Host "  git-sync ""message"""
Write-Host "  project-health"
Write-Host ""