# RhythmFall: Windows-native server — BPM (tempocnn) + EffNet genres + stems.
#
#   powershell -ExecutionPolicy Bypass -File worker\install_windows_server.ps1

param(
    [string]$ServerRoot = "",
    [ValidateSet("cpu", "auto", "nvidia", "amd")]
    [string]$Gpu = "auto"
)

$ErrorActionPreference = "Stop"
$Here = Split-Path -Parent $MyInvocation.MyCommand.Path

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
    $default = Join-Path (Split-Path $Here -Parent) "RhythmFallServer"
    if (-not (Test-Path $default)) {
        $default = Join-Path (Split-Path $Here -Parent) "RhythmFallServer-main"
    }
    return (Resolve-Path $default).Path
}

$Server = Resolve-ServerRoot $ServerRoot
$RunPy = Join-Path $Server "run.py"
if (-not (Test-Path $RunPy)) {
    Write-Error "run.py not found in: $Server"
}

Write-Host "[RhythmFall Windows] Server: $Server"

$py = Get-Command python -ErrorAction SilentlyContinue
if (-not $py) {
    Write-Error 'python not in PATH. Install Python 3.9-3.11 (tempocnn needs Python below 3.12).'
}
$ver = & python -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')"
$parts = $ver.Split(".")
$major = [int]$parts[0]
$minor = [int]$parts[1]
if ($major -ne 3 -or $minor -lt 9 -or $minor -ge 12) {
    Write-Warning "Python $ver - tempocnn officially supports 3.9-3.11. Continue anyway? (Ctrl+C to abort)"
    Start-Sleep -Seconds 3
}

$Venv = Join-Path $Server ".venv"
if (-not (Test-Path $Venv)) {
    Write-Host "[RhythmFall Windows] Creating venv: $Venv"
    & python -m venv $Venv
}
$VenvPy = Join-Path $Venv "Scripts\python.exe"
$VenvPip = Join-Path $Venv "Scripts\pip.exe"

Write-Host "[RhythmFall Windows] Upgrading pip..."
& $VenvPy -m pip install -U pip wheel setuptools

$Req = Join-Path $Server "requirements.txt"
if (-not (Test-Path $Req)) {
    Write-Error "Missing requirements.txt in $Server"
}

Write-Host "[RhythmFall Windows] Core stack (numpy below 2 for tempocnn/tensorflow)..."
& $VenvPip install -r $Req
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host "[RhythmFall Windows] PyTorch (CPU) for demucs..."
& $VenvPip install torch torchaudio --index-url https://download.pytorch.org/whl/cpu
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

function Install-GpuStack {
    param([string]$Mode)
    if ($Mode -eq "auto") {
        $names = @()
        try {
            $names = Get-CimInstance Win32_VideoController | ForEach-Object { $_.Name }
        } catch {
            Write-Warning "Could not detect GPU; keeping CPU torch."
            $Mode = "cpu"
        }
        if ($Mode -eq "auto") {
            $nvidia = $names | Where-Object { $_ -match "nvidia" -and $_ -notmatch "virtual" }
            $amd = $names | Where-Object { $_ -match "amd|radeon" }
            if ($nvidia) {
                Write-Host "[RhythmFall Windows] GPU auto-detect: NVIDIA -> CUDA"
                $Mode = "nvidia"
            } elseif ($amd) {
                Write-Host "[RhythmFall Windows] GPU auto-detect: AMD -> DirectML"
                $Mode = "amd"
            } else {
                Write-Host "[RhythmFall Windows] GPU auto-detect: no supported GPU, CPU"
                $Mode = "cpu"
            }
        }
    }
    if ($Mode -eq "cpu") {
        Write-Host "[RhythmFall Windows] GPU stack: CPU (reinstall CPU torch, drop CUDA/DirectML extras)..."
        & $VenvPip uninstall -y torch-directml onnxruntime-gpu onnxruntime-directml 2>$null
        & $VenvPip uninstall -y torch torchaudio onnxruntime 2>$null
        & $VenvPip install torch torchaudio --index-url https://download.pytorch.org/whl/cpu
        if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
        & $VenvPip install onnxruntime
        if ($LASTEXITCODE -ne 0) {
            Write-Warning "onnxruntime (CPU) install failed; stems may still work via demucs."
        }
        return "cpu"
    }
    if ($Mode -eq "nvidia") {
        Write-Host "[RhythmFall Windows] Installing CUDA PyTorch + onnxruntime-gpu..."
        & $VenvPip uninstall -y torch-directml onnxruntime-directml 2>$null
        & $VenvPip uninstall -y torch torchaudio onnxruntime onnxruntime-gpu 2>$null
        & $VenvPip install torch torchaudio --index-url https://download.pytorch.org/whl/cu124
        if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
        & $VenvPip install onnxruntime-gpu
        if ($LASTEXITCODE -ne 0) {
            Write-Warning "onnxruntime-gpu failed; CUDA torch may still accelerate stems."
        }
        return "nvidia"
    }
    if ($Mode -eq "amd") {
        Write-Host "[RhythmFall Windows] Installing DirectML (AMD/Intel GPU)..."
        & $VenvPip uninstall -y onnxruntime-gpu 2>$null
        & $VenvPip install torch-directml onnxruntime-directml
        if ($LASTEXITCODE -ne 0) {
            Write-Warning "DirectML install failed; stems stay on CPU."
            return "cpu"
        }
        return "amd"
    }
    return "cpu"
}

$ResolvedGpu = Install-GpuStack -Mode $Gpu
$GpuMarker = Join-Path $Server ".gpu_stack"
[System.IO.File]::WriteAllText($GpuMarker, "$ResolvedGpu", (New-Object System.Text.UTF8Encoding $false))
Write-Host "[RhythmFall Windows] Wrote GPU stack marker: $ResolvedGpu"

Write-Host "[RhythmFall Windows] audio-separator (no-deps, keep numpy 1.x)..."
& $VenvPip install audio-separator==0.41.1 --no-deps
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
& $VenvPip install "beartype>=0.18,<0.19" "diffq-fixed>=0.2" "einops" "julius" "ml_collections" "omegaconf" "onnx>=1.16,<1.19" "onnx2torch>=1.5" "pandas" "pydub" "pyyaml" "requests" "resampy>=0.4" "rotary-embedding-torch>=0.6.1,<0.7" "samplerate==0.1.0" "six" "tqdm" "librosa" "numpy>=1.23.5,<2.0"
if ($LASTEXITCODE -ne 0) {
    Write-Warning "Some audio-separator deps failed - stems may still work via demucs"
}

Write-Host "[RhythmFall Windows] optional: madmom..."
& $VenvPip install --no-build-isolation "madmom==0.16.1" "numpy>=1.23.5,<2.0"
if ($LASTEXITCODE -ne 0) {
    Write-Host "[RhythmFall Windows] madmom skipped (optional)"
}

Write-Host "[RhythmFall Windows] ADTOF drum transcription (fast-pick)..."
& $VenvPip install "pretty_midi>=0.2.10"
& $VenvPip install "git+https://github.com/xavriley/ADTOF-pytorch.git"
if ($LASTEXITCODE -ne 0) {
    Write-Warning "adtof-pytorch failed - set RFALL_DRUM_BACKEND=heuristic or retry pip install"
} else {
    Write-Host "[RhythmFall Windows] Default drum backend: adtof_fast (RFALL_DRUM_BACKEND=heuristic to disable)"
}

$ffmpeg = Get-Command ffmpeg -ErrorAction SilentlyContinue
if (-not $ffmpeg) {
    Write-Warning "ffmpeg not in PATH - demucs/stems may fail. Install ffmpeg and add to PATH."
} else {
    Write-Host "[RhythmFall Windows] ffmpeg: $($ffmpeg.Source)"
}

# Profile Recap PNG export (Playwright + Edge/Chrome). Same venv the game resolves via windows_python.path.
$GameRoot = Split-Path $Here -Parent
$RecapReq = Join-Path $GameRoot "scenes\profile\share\html\requirements.txt"
if (Test-Path $RecapReq) {
    Write-Host "[RhythmFall Windows] Profile Recap export (Playwright)..."
    & $VenvPip install -r $RecapReq
    if ($LASTEXITCODE -ne 0) {
        Write-Warning "Playwright pip install failed — Profile → Export may show E002."
    } else {
        Write-Host "[RhythmFall Windows] Installing Chromium/Edge for Playwright (msedge preferred)..."
        & $VenvPy -m playwright install msedge
        if ($LASTEXITCODE -ne 0) {
            Write-Warning "playwright install msedge failed — trying chromium..."
            & $VenvPy -m playwright install chromium
            if ($LASTEXITCODE -ne 0) {
                Write-Warning "Browser install failed — Recap export needs Edge or Chrome on the machine."
            }
        }
    }
} else {
    Write-Warning "Recap requirements missing ($RecapReq) — skipped Playwright install."
}

# Prefer relative path so worker/ copies cleanly into any install dir.
# Launcher order: RFALL_PYTHON env → <server>\.venv\Scripts\python.exe → this file.
$pyPathFile = Join-Path $Here "windows_python.path"
$relHint = "RhythmFallServer\.venv\Scripts\python.exe"
$gameRootGuess = Split-Path $Here -Parent
if ($VenvPy -and (Test-Path $VenvPy)) {
    if (Test-Path (Join-Path $gameRootGuess $relHint)) {
        [System.IO.File]::WriteAllText($pyPathFile, $relHint, (New-Object System.Text.UTF8Encoding $false))
        Write-Host "[RhythmFall Windows] Wrote relative python hint: $relHint"
    } else {
        [System.IO.File]::WriteAllText($pyPathFile, $VenvPy, (New-Object System.Text.UTF8Encoding $false))
        Write-Host "[RhythmFall Windows] Wrote absolute RFALL_PYTHON hint: $pyPathFile"
    }
} else {
    Write-Warning "venv python missing; skipped windows_python.path"
}

Write-Host ""
Write-Host "[RhythmFall Windows] Verification..."
& $VenvPy (Join-Path $Server "scripts\verify_windows_server.py")
if ($LASTEXITCODE -ne 0) {
    Write-Warning "Some checks failed - see messages above."
    exit $LASTEXITCODE
}

Write-Host ""
Write-Host "[RhythmFall Windows] Done."
Write-Host "  1) Run worker\cleanup_wsl_legacy.ps1 if old WSL models remain"
Write-Host "  2) Run RhythmFallServer.exe (Windows Python from .venv)"
Write-Host "  Optional GPU: -Gpu auto|nvidia|amd ; RFALL_GPU=auto"
