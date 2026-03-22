$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

# =========================================================
# WAPB DEV SHELL
# Canonical local terminal environment for VS Code
# Rewritten: cleaner structure, safer npm, better diagnostics
# =========================================================

# -------------------------
# CONFIG
# -------------------------
$GitPath     = "C:\Users\User\Documents\PortableGit\cmd"
$NodePath    = "C:\Users\User\OneDrive\Документи\node-v20.20.1-win-x64"
$ProjectRoot = $PSScriptRoot

# -------------------------
# PATHS
# -------------------------
$GitExePath      = Join-Path $GitPath "git.exe"
$NodeExePath     = Join-Path $NodePath "node.exe"
$NpmCliPath      = Join-Path $NodePath "node_modules\npm\bin\npm-cli.js"
$NpxCliPath      = Join-Path $NodePath "node_modules\npm\bin\npx-cli.js"
$ClaspEntryPath  = Join-Path $ProjectRoot "node_modules\@google\clasp\build\src\index.js"
$WatchScriptPath = Join-Path $ProjectRoot "watch-sync-simple.ps1"
$ManifestPath    = Join-Path $ProjectRoot "appsscript.json"
$ClaspConfigPath = Join-Path $ProjectRoot ".clasp.json"

# -------------------------
# PATH SETUP
# -------------------------
$env:Path = "$GitPath;$NodePath;$env:Path"
Set-Location $ProjectRoot

# -------------------------
# VALIDATION
# -------------------------
function Assert-FileExists {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [Parameter(Mandatory = $true)]
        [string]$Label
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "$Label not found: $Path"
    }
}

Assert-FileExists -Path $GitExePath      -Label "git.exe"
Assert-FileExists -Path $NodeExePath     -Label "node.exe"
Assert-FileExists -Path $NpmCliPath      -Label "npm-cli.js"
Assert-FileExists -Path $ClaspEntryPath  -Label "clasp entry"
Assert-FileExists -Path $ManifestPath    -Label "appsscript.json"
Assert-FileExists -Path $ClaspConfigPath -Label ".clasp.json"

# npx не делаем обязательным, потому что он не всегда нужен
$HasNpx = Test-Path -LiteralPath $NpxCliPath

# -------------------------
# SAFE FULL PATHS
# -------------------------
$GitExe      = (Get-Item -LiteralPath $GitExePath).FullName
$NodeExe     = (Get-Item -LiteralPath $NodeExePath).FullName
$NpmCli      = (Get-Item -LiteralPath $NpmCliPath).FullName
$NpxCli      = if ($HasNpx) { (Get-Item -LiteralPath $NpxCliPath).FullName } else { $null }
$ClaspEntry  = (Get-Item -LiteralPath $ClaspEntryPath).FullName
$WatchScript = if (Test-Path -LiteralPath $WatchScriptPath) { (Get-Item -LiteralPath $WatchScriptPath).FullName } else { $null }
$Manifest    = (Get-Item -LiteralPath $ManifestPath).FullName
$ClaspConfig = (Get-Item -LiteralPath $ClaspConfigPath).FullName

# -------------------------
# UI HELPERS
# -------------------------
function Write-Section {
    [CmdletBinding()]
    param([string]$Title)

    Write-Host ""
    Write-Host "=== $Title ==="
}

function Write-Info {
    [CmdletBinding()]
    param([string]$Message)

    Write-Host "[INFO] $Message"
}

function Write-Ok {
    [CmdletBinding()]
    param([string]$Message)

    Write-Host "[OK] $Message"
}

function Write-WarnLine {
    [CmdletBinding()]
    param([string]$Message)

    Write-Host "[WARN] $Message"
}

# -------------------------
# INTERNAL EXEC HELPERS
# -------------------------
function Invoke-ProjectGit {
    [CmdletBinding()]
    param(
        [Parameter(ValueFromRemainingArguments = $true)]
        [string[]]$Arguments
    )

    & $GitExe @Arguments
}

function Invoke-NpmPs {
    [CmdletBinding()]
    param(
        [Parameter(ValueFromRemainingArguments = $true)]
        [string[]]$Arguments
    )

    & $NodeExe $NpmCli @Arguments
}

function Invoke-NpxPs {
    [CmdletBinding()]
    param(
        [Parameter(ValueFromRemainingArguments = $true)]
        [string[]]$Arguments
    )

    if (-not $HasNpx) {
        throw "npx-cli.js not found: $NpxCliPath"
    }

    & $NodeExe $NpxCli @Arguments
}

function Invoke-Clasp {
    [CmdletBinding()]
    param(
        [Parameter(ValueFromRemainingArguments = $true)]
        [string[]]$Arguments
    )

    & $NodeExe $ClaspEntry @Arguments
}

# -------------------------
# SOURCE FILES / HASH
# -------------------------
function Get-WapbTrackedSourceFiles {
    [CmdletBinding()]
    param()

    Get-ChildItem -Path $ProjectRoot -Recurse -File |
        Where-Object {
            $_.FullName -notmatch '\\node_modules\\' -and
            $_.FullName -notmatch '\\\.git\\' -and
            $_.FullName -notmatch '\\dist\\' -and
            $_.FullName -notmatch '\\build\\' -and
            (
                $_.Name -eq 'appsscript.json' -or
                $_.Extension -in @('.gs', '.html')
            )
        } |
        Sort-Object FullName
}

function Get-WapbSourceHash {
    [CmdletBinding()]
    param()

    $files = Get-WapbTrackedSourceFiles

    if (-not $files) {
        return ""
    }

    $parts = foreach ($file in $files) {
        $hash = (Get-FileHash -Algorithm SHA256 -LiteralPath $file.FullName).Hash
        $relativePath = [System.IO.Path]::GetRelativePath($ProjectRoot, $file.FullName)
        "$relativePath|$hash"
    }

    $joined = $parts -join "`n"
    $bytes  = [System.Text.Encoding]::UTF8.GetBytes($joined)
    $sha    = [System.Security.Cryptography.SHA256]::Create()

    try {
        ($sha.ComputeHash($bytes) | ForEach-Object { $_.ToString("x2") }) -join ""
    }
    finally {
        $sha.Dispose()
    }
}

# -------------------------
# AVAILABILITY CHECKS
# -------------------------
function Test-GitAvailable {
    [CmdletBinding()]
    param()

    try {
        Invoke-ProjectGit --version | Out-Null
        return $true
    }
    catch {
        return $false
    }
}

function Test-NpmAvailable {
    [CmdletBinding()]
    param()

    try {
        Invoke-NpmPs -v | Out-Null
        return $true
    }
    catch {
        return $false
    }
}

function Test-ClaspAvailable {
    [CmdletBinding()]
    param()

    try {
        Invoke-Clasp --version | Out-Null
        return $true
    }
    catch {
        return $false
    }
}

# -------------------------
# GAS COMMANDS
# -------------------------
function Get-GasStatus {
    [CmdletBinding()]
    param()

    Invoke-Clasp status
}

function Invoke-GasPull {
    [CmdletBinding()]
    param()

    Write-Info "Pulling from Google Apps Script..."
    Invoke-Clasp pull
    $script:WapbLastKnownHash = Get-WapbSourceHash
    Write-Ok "GAS pull completed."
}

function Invoke-GasPush {
    [CmdletBinding()]
    param()

    Write-Info "Pushing to Google Apps Script..."
    Invoke-Clasp push
    $script:WapbLastKnownHash = Get-WapbSourceHash
    Write-Ok "GAS push completed."
}

function Open-GasProject {
    [CmdletBinding()]
    param()

    Invoke-Clasp open
}

function Start-GasWatch {
    [CmdletBinding()]
    param(
        [int]$IntervalSeconds = 3
    )

    if (-not $WatchScript) {
        throw "watch-sync-simple.ps1 not found: $WatchScriptPath"
    }

    Set-ExecutionPolicy -Scope Process Bypass -Force
    & $WatchScript -IntervalSeconds $IntervalSeconds
}

function Invoke-GasPushIfChanged {
    [CmdletBinding()]
    param()

    $currentHash = Get-WapbSourceHash

    if (-not $script:WapbLastKnownHash) {
        $script:WapbLastKnownHash = $currentHash
        Write-Info "Initial source hash captured. Push skipped."
        return
    }

    if ($currentHash -eq $script:WapbLastKnownHash) {
        Write-Info "No source changes detected."
        return
    }

    Write-Info "Changes detected. Pushing to Google Apps Script..."
    Invoke-Clasp push
    $script:WapbLastKnownHash = Get-WapbSourceHash
    Write-Ok "Push completed."
}

# -------------------------
# GIT COMMANDS
# -------------------------
function Get-GitStatusShort {
    [CmdletBinding()]
    param()

    Invoke-ProjectGit status --short
}

function Save-GitChanges {
    [CmdletBinding()]
    param(
        [string]$Message = "update"
    )

    Invoke-ProjectGit add .

    $pending = Invoke-ProjectGit status --short
    if (-not $pending) {
        Write-Info "No changes to commit."
        return
    }

    Invoke-ProjectGit commit -m $Message
    Write-Ok "Git commit created."
}

function Sync-GitBranch {
    [CmdletBinding()]
    param(
        [string]$Message = "update"
    )

    Invoke-ProjectGit add .

    $pending = Invoke-ProjectGit status --short
    if ($pending) {
        Invoke-ProjectGit commit -m $Message
        Write-Ok "Git commit created."
    }
    else {
        Write-Info "No changes to commit."
    }

    Invoke-ProjectGit push
    Write-Ok "Git push completed."
}

# -------------------------
# FULL WORKFLOW
# -------------------------
function Invoke-DeployAll {
    [CmdletBinding()]
    param(
        [string]$Message = "update"
    )

    Write-Section "DEPLOY ALL"

    Save-GitChanges -Message $Message

    Write-Info "Pushing Git..."
    Invoke-ProjectGit push

    Write-Info "Pushing GAS..."
    Invoke-Clasp push

    $script:WapbLastKnownHash = Get-WapbSourceHash
    Write-Ok "Deploy completed."
}

# -------------------------
# NPM / NPX COMMANDS
# -------------------------
function Get-NpmVersion {
    [CmdletBinding()]
    param()

    Invoke-NpmPs -v
}

function Get-NpxVersion {
    [CmdletBinding()]
    param()

    Invoke-NpxPs --version
}

# -------------------------
# HEALTH CHECK
# -------------------------
function Test-ProjectHealth {
    [CmdletBinding()]
    param()

    Write-Section "ENVIRONMENT"
    Invoke-ProjectGit --version
    & $NodeExe -v
    Invoke-NpmPs -v
    Invoke-Clasp --version

    if ($HasNpx) {
        Invoke-NpxPs --version
    }
    else {
        Write-WarnLine "npx is not available."
    }

    Write-Section "PATHS"
    Write-Host "ProjectRoot : $ProjectRoot"
    Write-Host "GitExe      : $GitExe"
    Write-Host "NodeExe     : $NodeExe"
    Write-Host "NpmCli      : $NpmCli"
    Write-Host "NpxCli      : $(if ($NpxCli) { $NpxCli } else { '<not found>' })"
    Write-Host "ClaspEntry  : $ClaspEntry"
    Write-Host "Manifest    : $Manifest"
    Write-Host "ClaspConfig : $ClaspConfig"
    Write-Host "WatchScript : $(if ($WatchScript) { $WatchScript } else { '<not found>' })"

    Write-Section "GIT"
    Invoke-ProjectGit status --short

    Write-Section "GAS"
    Invoke-Clasp status

    Write-Section "SOURCE FILES"
    Get-WapbTrackedSourceFiles | Select-Object -ExpandProperty FullName

    Write-Section "SOURCE HASH"
    Write-Host (Get-WapbSourceHash)

    Write-Host ""
}

# -------------------------
# HELP
# -------------------------
function Show-WapbCommands {
    [CmdletBinding()]
    param()

    Write-Host ""
    Write-Host "WAPB COMMANDS"
    Write-Host "-------------"
    Write-Host "gas-status            -> показать статус GAS"
    Write-Host "gas-pull              -> скачать код из Google Apps Script"
    Write-Host "gas-push              -> загрузить код в Google Apps Script"
    Write-Host "gas-push-smart        -> пушить в GAS только если есть изменения"
    Write-Host "gas-open              -> открыть GAS-проект в браузере"
    Write-Host "gas-watch             -> запустить watch-sync-simple.ps1"
    Write-Host "git-status-short      -> короткий git status"
    Write-Host "git-save 'msg'        -> git add + git commit"
    Write-Host "git-sync 'msg'        -> git add + git commit + git push"
    Write-Host "deploy-all 'msg'      -> git commit + git push + gas push"
    Write-Host "project-health        -> полная проверка окружения и проекта"
    Write-Host "npm -v                -> версия npm через node/npm-cli.js"
    Write-Host "npx --version         -> версия npx через node/npx-cli.js"
    Write-Host "wapb-help             -> показать эту справку"
    Write-Host ""
}

# -------------------------
# SHORT ALIASES
# -------------------------
Set-Alias npm              Invoke-NpmPs
Set-Alias npmps            Invoke-NpmPs
if ($HasNpx) { Set-Alias npx Invoke-NpxPs }

Set-Alias clasp            Invoke-Clasp
Set-Alias gas-status       Get-GasStatus
Set-Alias gas-pull         Invoke-GasPull
Set-Alias gas-push         Invoke-GasPush
Set-Alias gas-push-smart   Invoke-GasPushIfChanged
Set-Alias gas-open         Open-GasProject
Set-Alias gas-watch        Start-GasWatch
Set-Alias git-status-short Get-GitStatusShort
Set-Alias git-save         Save-GitChanges
Set-Alias git-sync         Sync-GitBranch
Set-Alias deploy-all       Invoke-DeployAll
Set-Alias project-health   Test-ProjectHealth
Set-Alias wapb-help        Show-WapbCommands

# -------------------------
# INIT STATE
# -------------------------
$script:WapbLastKnownHash = Get-WapbSourceHash

# -------------------------
# READY BANNER
# -------------------------
Write-Host ""
Write-Host "======================================"
Write-Host " WAPB DEV ENV LOADED"
Write-Host "======================================"
Write-Host ""
Write-Host "Project: $ProjectRoot"
Write-Host ""

Write-Host "Canonical commands:"
Write-Host "  Get-GasStatus"
Write-Host "  Invoke-GasPull"
Write-Host "  Invoke-GasPush"
Write-Host "  Invoke-GasPushIfChanged"
Write-Host "  Open-GasProject"
Write-Host "  Start-GasWatch"
Write-Host "  Get-GitStatusShort"
Write-Host "  Save-GitChanges 'msg'"
Write-Host "  Sync-GitBranch 'msg'"
Write-Host "  Invoke-DeployAll 'msg'"
Write-Host "  Test-ProjectHealth"
Write-Host "  Show-WapbCommands"
Write-Host ""

Write-Host "Short aliases:"
Write-Host "  gas-status"
Write-Host "  gas-pull"
Write-Host "  gas-push"
Write-Host "  gas-push-smart"
Write-Host "  gas-open"
Write-Host "  gas-watch"
Write-Host "  git-status-short"
Write-Host "  git-save 'msg'"
Write-Host "  git-sync 'msg'"
Write-Host "  Invoke-DeployAll 'msg'"
Write-Host "  project-health"
Write-Host "  wapb-help"
Write-Host "  npm -v"
if ($HasNpx) {
    Write-Host "  npx --version"
}
Write-Host ""
Write-Host "======================================"
Write-Host ""