# Remove WSL-only models and disable WSL flag. Safe for Windows-native installs.
param(
    [string]$ServerRoot = "",
    [switch]$WhatIf
)

$ErrorActionPreference = "Stop"
$Here = Split-Path -Parent $MyInvocation.MyCommand.Path

function Resolve-ServerRoot {
    param([string]$Hint)
    if ($Hint) { return (Resolve-Path $Hint).Path }
    $pathFile = Join-Path $Here "server_root.path"
    if (Test-Path $pathFile) {
        $line = (Get-Content $pathFile -Raw).Trim()
        if ($line) {
            $candidate = if ([System.IO.Path]::IsPathRooted($line)) { $line } else { Join-Path $Here $line }
            return (Resolve-Path $candidate).Path
        }
    }
    $default = Join-Path (Split-Path $Here -Parent) "RhythmFallServer"
    if (-not (Test-Path $default)) {
        $default = Join-Path (Split-Path $Here -Parent) "RhythmFallServer-main"
    }
    return (Resolve-Path $default).Path
}

$Server = Resolve-ServerRoot $ServerRoot
$Models = Join-Path $Server "models"
$Root = Split-Path $Here -Parent

$removeDirs = @(
    (Join-Path $Models "deeptemp-k16"),
    (Join-Path $Models "genre_discogs400-discogs-maest-10s-pw-1")
)

Write-Host "[RhythmFall] Server: $Server"
foreach ($dir in $removeDirs) {
    if (Test-Path $dir) {
        if ($WhatIf) {
            Write-Host "[WhatIf] Remove directory: $dir"
        } else {
            Remove-Item -Recurse -Force $dir
            Write-Host "[Removed] $dir"
        }
    } else {
        Write-Host "[Skip] not found: $dir"
    }
}

foreach ($flag in @("use_wsl.flag", "use_wsl.flag.off")) {
    $flagPath = Join-Path $Here $flag
    if (Test-Path $flagPath) {
        if ($WhatIf) {
            Write-Host "[WhatIf] Remove file: $flagPath"
        } else {
            Remove-Item -Force $flagPath
            Write-Host "[Removed] $flagPath"
        }
    }
}

Write-Host ""
Write-Host "Keep: models/discogs-effnet/, kuielab_a_drums.onnx, mdx_model_data.json"
Write-Host "See docs/WINDOWS_MODELS.txt"
