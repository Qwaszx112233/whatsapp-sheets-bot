param(
    [ValidateRange(1, 3600)]
    [int]$IntervalSeconds = 3
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

# =========================================================
# WAPB SMART GAS WATCH
# Watches source files and runs clasp push on change
# =========================================================

# -------------------------
# PATHS
# -------------------------
$ProjectRoot     = $PSScriptRoot
$ClaspEntryPath  = Join-Path $ProjectRoot "node_modules\@google\clasp\build\src\index.js"
$ManifestPath    = Join-Path $ProjectRoot "appsscript.json"
$ClaspConfigPath = Join-Path $ProjectRoot ".clasp.json"

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

try {
    $NodeExe = (Get-Command node.exe -ErrorAction Stop).Source
}
catch {
    throw "node.exe not found in PATH. First run: . .\dev-shell.ps1"
}

Assert-FileExists -Path $ClaspEntryPath  -Label "clasp entry"
Assert-FileExists -Path $ManifestPath    -Label "appsscript.json"
Assert-FileExists -Path $ClaspConfigPath -Label ".clasp.json"

$NodeExe    = (Get-Item -LiteralPath $NodeExe).FullName
$ClaspEntry = (Get-Item -LiteralPath $ClaspEntryPath).FullName
$Manifest   = (Get-Item -LiteralPath $ManifestPath).FullName
$ClaspConfig = (Get-Item -LiteralPath $ClaspConfigPath).FullName

# -------------------------
# LOG HELPERS
# -------------------------
function Get-NowStamp {
    [CmdletBinding()]
    param()

    Get-Date -Format "yyyy-MM-dd HH:mm:ss"
}

function Write-Info {
    [CmdletBinding()]
    param([string]$Message)

    Write-Host "[$(Get-NowStamp)] $Message"
}

function Write-ErrorLine {
    [CmdletBinding()]
    param([string]$Message)

    Write-Host "[$(Get-NowStamp)] ERROR: $Message"
}

# -------------------------
# EXEC HELPERS
# -------------------------
function Invoke-Clasp {
    [CmdletBinding()]
    param(
        [Parameter(ValueFromRemainingArguments = $true)]
        [string[]]$Arguments
    )

    & $NodeExe $ClaspEntry @Arguments
}

# -------------------------
# SOURCE DISCOVERY
# -------------------------
function Get-TrackedFiles {
    [CmdletBinding()]
    param()

    Get-ChildItem -Path $ProjectRoot -Recurse -File |
        Where-Object {
            (
                $_.Name -eq "appsscript.json" -or
                $_.Extension -eq ".gs" -or
                $_.Extension -eq ".html"
            ) -and
            $_.FullName -notmatch "\\node_modules\\" -and
            $_.FullName -notmatch "\\\.git\\" -and
            $_.FullName -notmatch "\\dist\\" -and
            $_.FullName -notmatch "\\build\\"
        } |
        Sort-Object FullName
}

function Get-SourceHash {
    [CmdletBinding()]
    param()

    $files = Get-TrackedFiles

    if (-not $files) {
        return ""
    }

    $parts = foreach ($file in $files) {
        $hash = (Get-FileHash -Algorithm SHA256 -LiteralPath $file.FullName).Hash
        "$($file.FullName)|$hash"
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
# WATCH LOOP
# -------------------------
$lastHash = Get-SourceHash
$fileCount = @(Get-TrackedFiles).Count

Write-Host ""
Write-Host "======================================"
Write-Host " SMART GAS WATCH STARTED"
Write-Host "======================================"
Write-Host "Project   : $ProjectRoot"
Write-Host "Node      : $NodeExe"
Write-Host "Clasp     : $ClaspEntry"
Write-Host "Manifest  : $Manifest"
Write-Host "Config    : $ClaspConfig"
Write-Host "Files     : $fileCount"
Write-Host "Interval  : $IntervalSeconds sec"
Write-Host "Stop      : Ctrl + C"
Write-Host "======================================"
Write-Host ""

Write-Info "Initial source snapshot captured."

while ($true) {
    Start-Sleep -Seconds $IntervalSeconds

    try {
        $currentHash = Get-SourceHash

        if ($currentHash -eq $lastHash) {
            continue
        }

        Write-Info "Changes detected -> clasp push"
        Invoke-Clasp push

        $lastHash = Get-SourceHash
        Write-Info "Push OK"
    }
    catch {
        Write-ErrorLine "PUSH FAILED"
        Write-Host $_.Exception.Message
    }
}