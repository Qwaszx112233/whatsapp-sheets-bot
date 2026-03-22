$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

# =========================================================
# WAPB DEV SHELL
# Canonical local terminal environment for VS Code
# Cleaned: safer command execution, honest diagnostics,
# fixed deploy alias, fixed git-sync, optional .clasp.json,
# PowerShell 5.1 compatible relative paths
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

function Test-ClaspProjectLinked {
    [CmdletBinding()]
    param()

    return (Test-Path -LiteralPath $ClaspConfigPath)
}

function Assert-ClaspProjectLinked {
    [CmdletBinding()]
    param()

    if (-not (Test-ClaspProjectLinked)) {
        throw ".clasp.json not found: $ClaspConfigPath. GAS project commands require a linked Apps Script project."
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

Assert-FileExists -Path $GitExePath      -Label "git.exe"
Assert-FileExists -Path $NodeExePath     -Label "node.exe"
Assert-FileExists -Path $NpmCliPath      -Label "npm-cli.js"
Assert-FileExists -Path $ClaspEntryPath  -Label "clasp entry"
Assert-FileExists -Path $ManifestPath    -Label "appsscript.json"

# npx необязателен
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
$ClaspConfig = if (Test-ClaspProjectLinked) { (Get-Item -LiteralPath $ClaspConfigPath).FullName } else { $null }

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

    if (-not $HasNpx) {
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

    Invoke-ExternalNodeCommand -EntryFile $ClaspEntry -ToolName "clasp" -Arguments $Arguments
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

    Assert-ClaspProjectLinked
    Invoke-Clasp status
}

function Invoke-GasPull {
    [CmdletBinding()]
    param()

    Assert-ClaspProjectLinked
    Write-Info "Pulling from Google Apps Script..."
    Invoke-Clasp pull
    $script:WapbLastKnownHash = Get-WapbSourceHash
    Write-Ok "GAS pull completed."
}

function Invoke-GasPush {
    [CmdletBinding()]
    param()

    Assert-ClaspProjectLinked
    Write-Info "Pushing to Google Apps Script..."
    Invoke-Clasp push
    $script:WapbLastKnownHash = Get-WapbSourceHash
    Write-Ok "GAS push completed."
}

function Open-GasProject {
    [CmdletBinding()]
    param()

    Assert-ClaspProjectLinked
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
    $exitCode = $LASTEXITCODE

    if ($exitCode -ne 0) {
        throw "watch-sync-simple.ps1 failed with exit code $exitCode"
    }
}

function Invoke-GasPushIfChanged {
    [CmdletBinding()]
    param()

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

    Write-Section "ENVIRONMENT"
    Invoke-ProjectGit --version
    & $NodeExe -v
    if ($LASTEXITCODE -ne 0) {
        throw "node -v failed with exit code $LASTEXITCODE"
    }

    Invoke-NpmPs --version
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
    Write-Host "ClaspConfig : $(if ($ClaspConfig) { $ClaspConfig } else { '<not found>' })"
    Write-Host "WatchScript : $(if ($WatchScript) { $WatchScript } else { '<not found>' })"

    Write-Section "GIT"
    Invoke-ProjectGit status --short

    Write-Section "GAS"
    if (Test-ClaspProjectLinked) {
        Invoke-Clasp status
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
    Write-Host "npm --version         -> версия npm через node/npm-cli.js"
    Write-Host "npx --version         -> версия npx через node/npx-cli.js"
    Write-Host "clasp --version       -> проверить версию clasp"
    Write-Host "clasp login           -> логин в clasp"
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
Write-Host "  deploy-all 'msg'"
Write-Host "  project-health"
Write-Host "  wapb-help"
Write-Host "  npm --version"
Write-Host "  clasp --version"
if ($HasNpx) {
    Write-Host "  npx --version"
}
Write-Host ""

if (-not (Test-ClaspProjectLinked)) {
    Write-WarnLine ".clasp.json not found. Git/npm commands work, global clasp commands work, but GAS project commands are disabled until project linking."
    Write-Host ""
}

Write-Host "======================================"
Write-Host ""