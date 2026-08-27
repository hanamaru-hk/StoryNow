param(
    [switch]$ForceInstall
)

# Create/update the Python runtime used by scripts/tts_helper.py.
# Usage: powershell -ExecutionPolicy Bypass -File scripts/setup_sherpa_python.ps1
#        powershell -ExecutionPolicy Bypass -File scripts/setup_sherpa_python.ps1 -ForceInstall
$ErrorActionPreference = "Stop"

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
$sherpaDir = Join-Path $repoRoot "server\sherpa-onnx"
$venvDir = Join-Path $sherpaDir "python"
$pythonExe = Join-Path $venvDir "Scripts\python.exe"
$packages = @("sherpa-onnx==1.13.6", "soundfile==0.14.0")

if (-not (Test-Path $sherpaDir)) {
    New-Item -ItemType Directory -Force -Path $sherpaDir | Out-Null
}

if (-not (Test-Path $pythonExe)) {
    Write-Host "Creating Sherpa Python venv at $venvDir ..."
    if (Get-Command py -ErrorAction SilentlyContinue) {
        py -3 -m venv $venvDir
    } elseif (Get-Command python -ErrorAction SilentlyContinue) {
        python -m venv $venvDir
    } else {
        throw "Python was not found. Install Python 3, then rerun this script."
    }
}

Write-Host "Checking Sherpa Python packages ..."
$verify = & $pythonExe -c "import sys; import sherpa_onnx; import soundfile; print(sys.executable); print('sherpa_onnx ok'); print('soundfile ok')" 2>&1
if ($LASTEXITCODE -ne 0 -or $ForceInstall) {
    Write-Host "Installing TTS Python packages ..."
    & $pythonExe -m pip install --upgrade pip @packages
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

    Write-Host "Verifying Sherpa Python runtime ..."
    & $pythonExe -c "import sys; import sherpa_onnx; import soundfile; print(sys.executable); print('sherpa_onnx ok'); print('soundfile ok')"
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
} else {
    $verify | ForEach-Object { Write-Host $_ }
}

Write-Host "Done. TTS will use: $pythonExe"
