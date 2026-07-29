# Download EffNet ONNX + labels for Windows-native genre detection.
param(
    [string]$ServerRoot = ""
)

$ErrorActionPreference = "Stop"
$Here = $PSScriptRoot
if (-not $ServerRoot) {
    $pathFile = Join-Path $Here "server_root.path"
    if (Test-Path $pathFile) {
        $ServerRoot = (Get-Content $pathFile -Raw).Trim()
        if ($ServerRoot.Length -gt 0 -and [int][char]$ServerRoot[0] -eq 0xFEFF) {
            $ServerRoot = $ServerRoot.Substring(1).Trim()
        }
    }
}
if (-not $ServerRoot) {
    $ServerRoot = (Resolve-Path (Join-Path $Here "..\RhythmFallServer")).Path
}

$dest = Join-Path $ServerRoot "models\discogs-effnet"
New-Item -ItemType Directory -Force -Path $dest | Out-Null

$base = "https://essentia.upf.edu/models/music-style-classification/discogs-effnet"
$files = @(
    "discogs-effnet-bsdynamic-1.onnx",
    "discogs-effnet-bsdynamic-1.json"
)

foreach ($name in $files) {
    $out = Join-Path $dest $name
    if (Test-Path $out) {
        Write-Host "[EffNet] Already exists: $out"
        continue
    }
    $url = "$base/$name"
    Write-Host "[EffNet] Downloading $name ..."
    Invoke-WebRequest -Uri $url -OutFile $out -UseBasicParsing
    Write-Host "[EffNet] OK: $out"
}

Write-Host "[EffNet] Done. Restart RhythmFallServer.exe"
