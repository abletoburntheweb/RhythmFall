# Build RhythmFallServer.exe (WSL launcher with server.ico)
param(
    [string]$ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path,
    [string]$OutExe = ""
)

$ErrorActionPreference = "Stop"
$worker = Join-Path $ProjectRoot "worker"
$cs = Join-Path $worker "RhythmFallServerLauncher.cs"
$ico = Join-Path $worker "server.ico"
$rcedit = Join-Path $ProjectRoot "RFALL\tools\rcedit.exe"

if (-not $OutExe) {
    $OutExe = Join-Path $ProjectRoot "RhythmFallServer.exe"
}

$csc = Join-Path $env:WINDIR "Microsoft.NET\Framework64\v4.0.30319\csc.exe"
if (-not (Test-Path -LiteralPath $csc)) {
    Write-Error "csc.exe not found (need .NET Framework SDK)"
}

foreach ($p in @($cs, $ico)) {
    if (-not (Test-Path -LiteralPath $p)) {
        Write-Error "Missing: $p"
    }
}

Write-Host "Building: $OutExe"
& $csc /nologo /target:exe /optimize+ `
    "/win32icon:$ico" `
    "/out:$OutExe" `
    $cs

if ($LASTEXITCODE -ne 0) {
    Write-Error "csc failed with code $LASTEXITCODE"
}

if (Test-Path -LiteralPath $rcedit) {
    & $rcedit $OutExe `
        --set-icon $ico `
        --set-version-string "FileDescription" "RhythmFall Generation Server" `
        --set-version-string "ProductName" "RhythmFall Generation Server" `
        --set-version-string "OriginalFilename" "RhythmFallServer.exe"
    if ($LASTEXITCODE -ne 0) {
        Write-Error "rcedit failed with code $LASTEXITCODE"
    }
}

Write-Host "OK: $OutExe"
Write-Host "Run from project root (needs worker\ + RhythmFallServer\)."
