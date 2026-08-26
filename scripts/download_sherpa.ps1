# Download latest portable sherpa-onnx and put inside server folder
# Usage: powershell -ExecutionPolicy Bypass -File scripts/download_sherpa.ps1
$ErrorActionPreference = "Stop"

$version = "v1.13.5"
$variant = "win-x64-shared-MD-Release"
$url = "https://github.com/k2-fsa/sherpa-onnx/releases/download/$version/sherpa-onnx-$version-$variant.tar.bz2"
$serverDir = Join-Path $PSScriptRoot ".." | Join-Path -ChildPath "server"
$sherpaDest = Join-Path $serverDir "sherpa-onnx"
$tmpArchive = Join-Path $env:TEMP "sherpa-onnx-$version-$variant.tar.bz2"
$tmpExtract = Join-Path $env:TEMP "sherpa-extract-$version"

Write-Host "Downloading sherpa-onnx $version ($variant) from $url ..."
if (Test-Path $tmpArchive) { Remove-Item $tmpArchive -Force }
# Use curl.exe for reliability
& "C:\Windows\System32\curl.exe" -L -o $tmpArchive $url --progress-bar
if (-not (Test-Path $tmpArchive) -or (Get-Item $tmpArchive).Length -lt 1000) {
    Write-Host "curl failed, trying Invoke-WebRequest..."
    Invoke-WebRequest -Uri $url -OutFile $tmpArchive -UseBasicParsing
}

Write-Host "Extracting to $tmpExtract ..."
if (Test-Path $tmpExtract) { Remove-Item $tmpExtract -Recurse -Force }
New-Item -ItemType Directory -Path $tmpExtract | Out-Null
# Windows 11 has tar, fallback to 7z if needed
try {
    tar -xf $tmpArchive -C $tmpExtract
} catch {
    Write-Host "tar failed, trying 7z ..."
    & 7z x $tmpArchive -o"$tmpExtract" -y | Out-Null
    $innerTar = Get-ChildItem $tmpExtract -Filter "*.tar" | Select-Object -First 1
    if ($innerTar) { tar -xf $innerTar.FullName -C $tmpExtract }
}

$srcRoot = Get-ChildItem $tmpExtract -Directory | Select-Object -First 1
if (-not $srcRoot) { throw "Failed to find extracted sherpa directory" }
Write-Host "Found source: $($srcRoot.FullName)"

# Ensure dest exists
if (-not (Test-Path $sherpaDest)) { New-Item -ItemType Directory -Path $sherpaDest | Out-Null }

# Preserve models folder
$preserveModels = Join-Path $sherpaDest "models"
$backupModels = $null
if (Test-Path $preserveModels) {
    $backupModels = Join-Path $env:TEMP "sherpa-models-backup"
    if (Test-Path $backupModels) { Remove-Item $backupModels -Recurse -Force }
    Copy-Item $preserveModels $backupModels -Recurse
}

Write-Host "Copying to $sherpaDest ..."
# Copy bin, lib, include, etc. Overwrite
Copy-Item (Join-Path $srcRoot.FullName "bin") $sherpaDest -Recurse -Force
Copy-Item (Join-Path $srcRoot.FullName "lib") $sherpaDest -Recurse -Force
if (Test-Path (Join-Path $srcRoot.FullName "include")) {
    Copy-Item (Join-Path $srcRoot.FullName "include") $sherpaDest -Recurse -Force
}
# Copy other files at root if needed
Get-ChildItem $srcRoot.FullName -File | ForEach-Object { Copy-Item $_.FullName $sherpaDest -Force }

if ($backupModels -and (Test-Path $backupModels)) {
    if (-not (Test-Path $preserveModels)) { New-Item -ItemType Directory -Path $preserveModels | Out-Null }
    # Restore models that are not already present? Keep all models from backup if dest models empty
    # Simple: if dest models was overwritten, merge backup
    $backupFiles = Get-ChildItem $backupModels -Directory
    foreach ($d in $backupFiles) {
        $destSub = Join-Path $preserveModels $d.Name
        if (-not (Test-Path $destSub)) { Copy-Item $d.FullName $destSub -Recurse }
    }
    Remove-Item $backupModels -Recurse -Force
}

Write-Host "Cleaning temp..."
Remove-Item $tmpArchive -Force -ErrorAction SilentlyContinue
Remove-Item $tmpExtract -Recurse -Force -ErrorAction SilentlyContinue

Write-Host "Done. Verify: $sherpaDest/bin/sherpa-onnx-offline-tts.exe"
if (Test-Path (Join-Path $sherpaDest "bin/sherpa-onnx-offline-tts.exe")) {
    Write-Host "OK - sherpa-onnx-offline-tts.exe present"
    & (Join-Path $sherpaDest "bin/sherpa-onnx-offline-tts.exe") --help | Select-Object -First 20
} else {
    Write-Warning "sherpa-onnx-offline-tts.exe not found after extraction!"
}
