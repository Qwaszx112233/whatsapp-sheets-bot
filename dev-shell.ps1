﻿$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

# =========================================================
# WAPB DEV SHELL
# Portable PowerShell environment for VS Code / VS Code Insiders
# - no admin rights required
# - works with portable Node + PortableGit
# - avoids blocked cmd.exe wrappers
# - clasp is optional until installed in the project
#
# IMPORTANT:
# dot-source this file so commands remain available:
#   . .\dev-shell.ps1
# =========================================================

# -------------------------
# CONFIG / CANDIDATES
# -------------------------
$ProjectRoot = $PSScriptRoot

$CandidateGitRoots = @(
    "C:\Users\User\Documents\PortableGit"
)

$CandidateNodeRoots = @(
    "C:\Users\User\Documents\node-v20.20.1-win-x64"
)

# -------------------------
# RESOLUTION HELPERS
# -------------------------
function Get-FirstExistingPath {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$Candidates
    )

    foreach ($candidate in $Candidates) {
        if ([string]::IsNullOrWhiteSpace($candidate)) {
            continue
        }

        if (Test-Path -LiteralPath $candidate) {
            return (Get-Item -LiteralPath $candidate).FullName
        }
    }

    return $null
}

function Get-FirstExistingFile {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$Candidates
    )

    foreach ($candidate in $Candidates) {
        if ([string]::IsNullOrWhiteSpace($candidate)) {
            continue
        }

        if (Test-Path -LiteralPath $candidate) {
            return (Get-Item -LiteralPath $candidate).FullName
        }
    }

    return $null
}

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

# -------------------------
# ROOT DISCOVERY
# -------------------------
$GitRoot  = Get-FirstExistingPath -Candidates $CandidateGitRoots
$NodeRoot = Get-FirstExistingPath -Candidates $CandidateNodeRoots

if (-not $GitRoot) {
    throw "PortableGit root not found. Checked: $($CandidateGitRoots -join '; ')"
}

if (-not $NodeRoot) {
    throw "Portable Node root not found. Checked: $($CandidateNodeRoots -join '; ')"
}

$GitBinDir = Join-Path $GitRoot "bin"
$GitCmdDir = Join-Path $GitRoot "cmd"

$GitExePath = Get-FirstExistingFile -Candidates @(
    (Join-Path $GitBinDir "git.exe"),
    (Join-Path $GitCmdDir "git.exe")
)

$NodeExePath = Join-Path $NodeRoot "node.exe"
$NpmCliPath  = Join-Path $NodeRoot "node_modules\npm\bin\npm-cli.js"
$NpxCliPath  = Join-Path $NodeRoot "node_modules\npm\bin\npx-cli.js"

$ManifestPath = Join-Path $ProjectRoot "appsscript.json"

Assert-FileExists -Path $GitExePath  -Label "git.exe"
Assert-FileExists -Path $NodeExePath -Label "node.exe"
Assert-FileExists -Path $NpmCliPath  -Label "npm-cli.js"
Assert-FileExists -Path $ManifestPath -Label "appsscript.json"

# -------------------------
# PATH SETUP
# -------------------------
$pathParts = New-Object System.Collections.Generic.List[string]
$pathParts.Add($NodeRoot) | Out-Null
if (Test-Path -LiteralPath $GitBinDir) { $pathParts.Add($GitBinDir) | Out-Null }
if (Test-Path -LiteralPath $GitCmdDir) { $pathParts.Add($GitCmdDir) | Out-Null }
$pathParts.Add($env:Path) | Out-Null
$env:Path = ($pathParts | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }) -join ';'

Set-Location $ProjectRoot

# -------------------------
# SAFE FULL PATHS
# -------------------------
$GitExe  = (Get-Item -LiteralPath $GitExePath).FullName
$NodeExe = (Get-Item -LiteralPath $NodeExePath).FullName
$NpmCli  = (Get-Item -LiteralPath $NpmCliPath).FullName
$NpxCli  = if (Test-Path -LiteralPath $NpxCliPath) { (Get-Item -LiteralPath $NpxCliPath).FullName } else { $null }

# -------------------------
# OPTIONAL TOOL STATE
# -------------------------
function Update-WapbEnvState {
    [CmdletBinding()]
    param()

    $script:ClaspEntryPath  = Join-Path $ProjectRoot "node_modules\@google\clasp\build\src\index.js"
    $script:WatchScriptPath = Join-Path $ProjectRoot "watch-sync-simple.ps1"
    $script:ClaspConfigPath = Join-Path $ProjectRoot ".clasp.json"

    $script:HasNpx          = Test-Path -LiteralPath $NpxCliPath
    $script:HasClasp        = Test-Path -LiteralPath $script:ClaspEntryPath
    $script:HasWatchScript  = Test-Path -LiteralPath $script:WatchScriptPath
    $script:HasClaspConfig  = Test-Path -LiteralPath $script:ClaspConfigPath

    $script:ClaspEntry = if ($script:HasClasp) { (Get-Item -LiteralPath $script:ClaspEntryPath).FullName } else { $null }
    $script:WatchScript = if ($script:HasWatchScript) { (Get-Item -LiteralPath $script:WatchScriptPath).FullName } else { $null }
    $script:ClaspConfig = if ($script:HasClaspConfig) { (Get-Item -LiteralPath $script:ClaspConfigPath).FullName } else { $null }
}

Update-WapbEnvState

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
# PROJECT HELPERS
# -------------------------
function Test-ClaspProjectLinked {
    [CmdletBinding()]
    param()

    Refresh-WapbEnvState
    return $script:HasClaspConfig
}

function Assert-ClaspProjectLinked {
    [CmdletBinding()]
    param()

    if (-not (Test-ClaspProjectLinked)) {
        throw ".clasp.json not found: $script:ClaspConfigPath. GAS project commands require a linked Apps Script project."
    }
}

function Test-ClaspInstalled {
    [CmdletBinding()]
    param()

    Refresh-WapbEnvState
    return $script:HasClasp
}

function Assert-ClaspInstalled {
    [CmdletBinding()]
    param()

    if (-not (Test-ClaspInstalled)) {
        throw "Local clasp is not installed. Run: Install-ClaspLocal"
    }
}

function Get-ProjectRelativePath {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$BasePath,

        [Parameter(Mandatory = $true)]
        [string]$TargetPath
    )

    $baseFull = [System.IO.Path]::GetFullPath($BasePath)
    if (-not $baseFull.EndsWith([System.IO.Path]::DirectorySeparatorChar)) {
        $baseFull += [System.IO.Path]::DirectorySeparatorChar
    }

    $targetFull = [System.IO.Path]::GetFullPath($TargetPath)

    $baseUri   = New-Object System.Uri($baseFull)
    $targetUri = New-Object System.Uri($targetFull)

    $relativeUri = $baseUri.MakeRelativeUri($targetUri)
    return [System.Uri]::UnescapeDataString($relativeUri.ToString()).Replace('/', '\')
}

# -------------------------
# INTERNAL EXEC HELPERS
# -------------------------
function Invoke-ExternalNodeCommand {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$EntryFile,

        [Parameter(Mandatory = $true)]
        [string]$ToolName,

        [string[]]$Arguments = @()
    )

    & $NodeExe $EntryFile @Arguments
    $exitCode = $LASTEXITCODE

    if ($exitCode -ne 0) {
        $joinedArgs = if ($Arguments -and $Arguments.Count -gt 0) { $Arguments -join ' ' } else { '' }
        throw "$ToolName $joinedArgs failed with exit code $exitCode"
    }
}

function Invoke-ProjectGit {
    [CmdletBinding()]
    param(
        [Parameter(ValueFromRemainingArguments = $true)]
        [string[]]$Arguments = @()
    )

    & $GitExe @Arguments
    $exitCode = $LASTEXITCODE

    if ($exitCode -ne 0) {
        $joinedArgs = if ($Arguments -and $Arguments.Count -gt 0) { $Arguments -join ' ' } else { '' }
        throw "git $joinedArgs failed with exit code $exitCode"
    }
}

function Invoke-NpmPs {
    [CmdletBinding()]
    param(
        [Parameter(ValueFromRemainingArguments = $true)]
        [string[]]$Arguments = @()
    )

    Invoke-ExternalNodeCommand -EntryFile $NpmCli -ToolName "npm" -Arguments $Arguments
}

function Invoke-NpxPs {
    [CmdletBinding()]
    param(
        [Parameter(ValueFromRemainingArguments = $true)]
        [string[]]$Arguments = @()
    )

    if (-not $NpxCli) {
        throw "npx-cli.js not found: $NpxCliPath"
    }

    Invoke-ExternalNodeCommand -EntryFile $NpxCli -ToolName "npx" -Arguments $Arguments
}

function Invoke-Clasp {
    [CmdletBinding()]
    param(
        [Parameter(ValueFromRemainingArguments = $true)]
        [string[]]$Arguments = @()
    )

    Assert-ClaspInstalled
    Invoke-ExternalNodeCommand -EntryFile $script:ClaspEntry -ToolName "clasp" -Arguments $Arguments
}

# -------------------------
# SIMPLE WRAPPERS
# -------------------------
function npmx {
    [CmdletBinding()]
    param(
        [Parameter(ValueFromRemainingArguments = $true)]
        [string[]]$Arguments = @()
    )

    Invoke-NpmPs @Arguments
}

function npxx {
    [CmdletBinding()]
    param(
        [Parameter(ValueFromRemainingArguments = $true)]
        [string[]]$Arguments = @()
    )

    Invoke-NpxPs @Arguments
}

function gitx {
    [CmdletBinding()]
    param(
        [Parameter(ValueFromRemainingArguments = $true)]
        [string[]]$Arguments = @()
    )

    Invoke-ProjectGit @Arguments
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
        $relativePath = Get-ProjectRelativePath -BasePath $ProjectRoot -TargetPath $file.FullName
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
        Invoke-NpmPs --version | Out-Null
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
        Refresh-WapbEnvState
        if (-not $script:HasClasp) {
            return $false
        }

        Invoke-Clasp --version | Out-Null
        return $true
    }
    catch {
        return $false
    }
}

# -------------------------
# SETUP COMMANDS
# -------------------------
function Install-ProjectDeps {
    [CmdletBinding()]
    param()

    Write-Info "Installing project dependencies..."
    Invoke-NpmPs install
    Refresh-WapbEnvState
    Write-Ok "Project dependencies installed."
}

function Install-ClaspLocal {
    [CmdletBinding()]
    param()

    Write-Info "Installing local clasp..."
    Invoke-NpmPs install --save-dev "@google/clasp"
    Refresh-WapbEnvState
    Write-Ok "Local clasp installed."
}

function Connect-GasProject {
    [CmdletBinding()]
    param()

    Assert-ClaspInstalled
    Invoke-Clasp login
}

function Disconnect-GasProject {
    [CmdletBinding()]
    param()

    Assert-ClaspInstalled
    Invoke-Clasp logout
}

# -------------------------
# GAS COMMANDS
# -------------------------
function Get-GasStatus {
    [CmdletBinding()]
    param()

    Assert-ClaspInstalled
    Assert-ClaspProjectLinked
    Invoke-Clasp status
}

function Invoke-GasPull {
    [CmdletBinding()]
    param()

    Assert-ClaspInstalled
    Assert-ClaspProjectLinked
    Write-Info "Pulling from Google Apps Script..."
    Invoke-Clasp pull
    $script:WapbLastKnownHash = Get-WapbSourceHash
    Write-Ok "GAS pull completed."
}

function Invoke-GasPush {
    [CmdletBinding()]
    param()

    Assert-ClaspInstalled
    Assert-ClaspProjectLinked
    Write-Info "Pushing to Google Apps Script..."
    Invoke-Clasp push
    $script:WapbLastKnownHash = Get-WapbSourceHash
    Write-Ok "GAS push completed."
}

function Open-GasProject {
    [CmdletBinding()]
    param()

    Assert-ClaspInstalled
    Assert-ClaspProjectLinked
    Invoke-Clasp open-script
}

function Start-GasWatch {
    [CmdletBinding()]
    param(
        [int]$IntervalSeconds = 3
    )

    Assert-ClaspInstalled
    Assert-ClaspProjectLinked

    Refresh-WapbEnvState
    if (-not $script:WatchScript) {
        throw "watch-sync-simple.ps1 not found: $script:WatchScriptPath"
    }

    $powershellExe = Join-Path $PSHOME "powershell.exe"
    if (-not (Test-Path -LiteralPath $powershellExe)) {
        throw "powershell.exe not found under PSHOME: $PSHOME"
    }

    & $powershellExe -NoProfile -ExecutionPolicy Bypass -File $script:WatchScript -IntervalSeconds $IntervalSeconds
    $exitCode = $LASTEXITCODE

    if ($exitCode -ne 0) {
        throw "watch-sync-simple.ps1 failed with exit code $exitCode"
    }
}

function Invoke-GasPushIfChanged {
    [CmdletBinding()]
    param()

    Assert-ClaspInstalled
    Assert-ClaspProjectLinked
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
    Write-Ok "GAS push completed."
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

    Write-Info "Pushing Git..."
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

    Assert-ClaspInstalled
    Assert-ClaspProjectLinked
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

    Invoke-NpmPs --version
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

    Refresh-WapbEnvState

    Write-Section "ENVIRONMENT"
    Invoke-ProjectGit --version
    & $NodeExe -v
    if ($LASTEXITCODE -ne 0) {
        throw "node -v failed with exit code $LASTEXITCODE"
    }

    Invoke-NpmPs --version

    if ($script:HasNpx) {
        Invoke-NpxPs --version
    }
    else {
        Write-WarnLine "npx is not available."
    }

    if ($script:HasClasp) {
        Invoke-Clasp --version
    }
    else {
        Write-WarnLine "Local clasp is not installed."
    }

    Write-Section "PATHS"
    Write-Host "ProjectRoot : $ProjectRoot"
    Write-Host "GitRoot     : $GitRoot"
    Write-Host "NodeRoot    : $NodeRoot"
    Write-Host "GitExe      : $GitExe"
    Write-Host "NodeExe     : $NodeExe"
    Write-Host "NpmCli      : $NpmCli"
    Write-Host "NpxCli      : $(if ($NpxCli) { $NpxCli } else { '<not found>' })"
    Write-Host "ClaspEntry  : $(if ($script:ClaspEntry) { $script:ClaspEntry } else { '<not installed>' })"
    Write-Host "Manifest    : $ManifestPath"
    Write-Host "ClaspConfig : $(if ($script:ClaspConfig) { $script:ClaspConfig } else { '<not found>' })"
    Write-Host "WatchScript : $(if ($script:WatchScript) { $script:WatchScript } else { '<not found>' })"

    Write-Section "GIT"
    Invoke-ProjectGit status --short

    Write-Section "GAS"
    if ($script:HasClasp -and $script:HasClaspConfig) {
        Invoke-Clasp status
    }
    elseif (-not $script:HasClasp) {
        Write-WarnLine "clasp is not installed yet."
    }
    else {
        Write-WarnLine ".clasp.json not found. GAS status is unavailable."
    }

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

    Refresh-WapbEnvState

    Write-Host ""
    Write-Host "WAPB COMMANDS"
    Write-Host "-------------"
    Write-Host "LOAD THIS FILE"
    Write-Host "  . .\dev-shell.ps1"
    Write-Host ""
    Write-Host "QUICK WRAPPERS"
    Write-Host "  npmx <args>                 -> npm via node/npm-cli.js"
    Write-Host "  npxx <args>                 -> npx via node/npx-cli.js"
    Write-Host "  gitx <args>                 -> git.exe"
    Write-Host ""
    Write-Host "SETUP"
    Write-Host "  Install-ProjectDeps         -> npm install"
    Write-Host "  Install-ClaspLocal          -> npm install --save-dev @google/clasp"
    Write-Host "  Login-GasProject            -> clasp login"
    Write-Host "  Logout-GasProject           -> clasp logout"
    Write-Host ""
    Write-Host "GAS"
    Write-Host "  Get-GasStatus               -> показать статус GAS"
    Write-Host "  Invoke-GasPull              -> скачать код из Google Apps Script"
    Write-Host "  Invoke-GasPush              -> загрузить код в Google Apps Script"
    Write-Host "  Invoke-GasPushIfChanged     -> пушить в GAS только если есть изменения"
    Write-Host "  Open-GasProject             -> открыть GAS-проект в браузере"
    Write-Host "  Start-GasWatch              -> запустить watch-sync-simple.ps1"
    Write-Host ""
    Write-Host "GIT"
    Write-Host "  Get-GitStatusShort          -> короткий git status"
    Write-Host "  Save-GitChanges 'msg'       -> git add + git commit"
    Write-Host "  Sync-GitBranch 'msg'        -> git add + git commit + git push"
    Write-Host "  Invoke-DeployAll 'msg'      -> git commit + git push + gas push"
    Write-Host ""
    Write-Host "DIAGNOSTICS"
    Write-Host "  Test-ProjectHealth          -> полная проверка окружения и проекта"
    Write-Host "  Refresh-WapbEnvState        -> обновить состояние env после npm install"
    Write-Host "  Show-WapbCommands           -> показать эту справку"
    Write-Host ""
}

# -------------------------
# SHORT ALIASES
# -------------------------
Set-Alias npm              Invoke-NpmPs
Set-Alias npmps            Invoke-NpmPs
if ($NpxCli) { Set-Alias npx Invoke-NpxPs }
if (Test-ClaspInstalled) { Set-Alias clasp Invoke-Clasp }

Set-Alias gas-status       Get-GasStatus
Set-Alias gas-pull         Invoke-GasPull
Set-Alias gas-push         Invoke-GasPush
Set-Alias gas-push-smart   Invoke-GasPushIfChanged
Set-Alias gas-open         Open-GasProject
Set-Alias gas-watch        Start-GasWatch
Set-Alias gas-login        Login-GasProject
Set-Alias gas-logout       Logout-GasProject
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
Write-Host "Node   : $NodeRoot"
Write-Host "Git    : $GitRoot"
Write-Host ""

if ($MyInvocation.InvocationName -ne '.') {
    Write-WarnLine "Run this file with dot-sourcing, otherwise commands will disappear after script exits:"
    Write-Host "  . .\dev-shell.ps1"
    Write-Host ""
}

Write-Host "Quick wrappers:"
Write-Host "  npmx <args>"
Write-Host "  npxx <args>"
Write-Host "  gitx <args>"
Write-Host ""

Write-Host "Canonical commands:"
Write-Host "  Install-ProjectDeps"
Write-Host "  Install-ClaspLocal"
Write-Host "  Login-GasProject"
Write-Host "  Logout-GasProject"
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
Write-Host "  gas-login"
Write-Host "  gas-logout"
Write-Host "  git-status-short"
Write-Host "  git-save 'msg'"
Write-Host "  git-sync 'msg'"
Write-Host "  deploy-all 'msg'"
Write-Host "  project-health"
Write-Host "  wapb-help"
Write-Host "  npm --version"
if ($NpxCli) {
    Write-Host "  npx --version"
}
if (Test-ClaspInstalled) {
    Write-Host "  clasp --version"
}
Write-Host ""

if (-not (Test-ClaspInstalled)) {
    Write-WarnLine "Local clasp is not installed yet. Run: Install-ClaspLocal"
    Write-Host ""
}

if (-not (Test-ClaspProjectLinked)) {
    Write-WarnLine ".clasp.json not found. Git/npm commands work, but GAS project commands are disabled until project linking."
    Write-Host ""
}

Write-Host "======================================"
Write-Host ""
