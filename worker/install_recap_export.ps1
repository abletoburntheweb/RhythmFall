# RhythmFall: install Profile Recap (PNG share) toolchain into the server venv.
# Safe to re-run. The game already uses RhythmFallServer\.venv via worker\windows_python.path.
#
#   powershell -ExecutionPolicy Bypass -File worker\install_recap_export.ps1

param(
    [string]$ServerRoot = ""
)

$ErrorActionPreference = "Stop"
$Here = Split-Path -Parent $MyInvocation.MyCommand.Path
$GameRoot = Split-Path $Here -Parent

function Resolve-ServerRoot {
    param([string]$Hint)
    if ($Hint) {
        return (Resolve-Path $Hint).Path
    }
    $pathFile = Join-Path $Here "server_root.path"
    if (Test-Path $pathFile) {
        $line = (Get-Content $pathFile -Raw).Trim()
        if ($line) {
            $candidate = if ([System.IO.Path]::IsPathRooted($line)) { $line } else { Join-Path $Here $line }
            return (Resolve-Path $candidate).Path
        }
    }
    foreach ($name in @("RhythmFallServer", "RhythmFallServer-main")) {
        $candidate = Join-Path $GameRoot $name
        if (Test-Path (Join-Path $candidate "run.py")) {
            return (Resolve-Path $candidate).Path
        }
    }
    Write-Error "RhythmFallServer not found next to worker\"
}

$Server = Resolve-ServerRoot $ServerRoot
$VenvPy = Join-Path $Server ".venv\Scripts\python.exe"
$VenvPip = Join-Path $Server ".venv\Scripts\pip.exe"
if (-not (Test-Path $VenvPy)) {
    Write-Error "venv missing at $VenvPy — run worker\install_windows_server.ps1 first."
}

$RecapReq = Join-Path $GameRoot "scenes\profile\share\html\requirements.txt"
if (-not (Test-Path $RecapReq)) {
    Write-Error "Missing $RecapReq"
}

Write-Host "[RhythmFall Recap] Server venv: $Server\.venv"
& $VenvPip install -r $RecapReq
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host "[RhythmFall Recap] playwright install msedge..."
& $VenvPy -m playwright install msedge
if ($LASTEXITCODE -ne 0) {
    Write-Warning "msedge failed — trying chromium"
    & $VenvPy -m playwright install chromium
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}

Write-Host "[RhythmFall Recap] Done. In-game: Profile → Export."
