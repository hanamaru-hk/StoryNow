$ErrorActionPreference = "Stop"

$repository = "MiaoMint/MeloTTS-ONNX"
$revision = "7a50512ba14a067701943e18b6636a6a18e7c69a"
$sourceRoot = "https://huggingface.co/$repository/resolve/$revision/onnx_exports/ja"
$projectRoot = Split-Path -Parent $PSScriptRoot
$destination = Join-Path $projectRoot "data/sherpa-models/vits-melo-tts-ja"
$buildDirectory = Join-Path $projectRoot "build/japanese-tts-installer"
$sourceModel = Join-Path $buildDirectory "model.source.onnx"
$sourceLexicon = Join-Path $buildDirectory "lexicon.source.txt"
$toolDirectory = Join-Path $buildDirectory "python-packages"
$prepareScript = Join-Path $projectRoot "tools/prepare_japanese_tts_model.py"
$python = Join-Path $projectRoot "c/py/python.exe"
$expectedSha256 = @{
	"model.onnx" = "ec2ace54bb2343ea78a4db94f5dab01a8ad1c110b696ed8cdb50a41f67e7d657"
	"lexicon.txt" = "11dbb23cbd95433edcee914ad4de768560205b7a5cdde9f3d0f6eae9e328c531"
	"tokens.txt" = "6e8ef51206fba0b8e2630ab003d9793c0c126221139566a8a16d300293cec0a0"
	"metadata.json" = "be6f86f3753da6805852836308e7a3e3e3b405c8851939aaf996e47cc8895bad"
}

New-Item -ItemType Directory -Force -Path $destination | Out-Null
New-Item -ItemType Directory -Force -Path $buildDirectory | Out-Null

if (-not (Test-Path -LiteralPath $python)) {
	throw "ComfyUI's embedded Python was not found at $python. Install the local ComfyUI runtime first."
}

Write-Host "Downloading model.onnx..."
Invoke-WebRequest -Uri "$sourceRoot/model.onnx" -OutFile $sourceModel
Write-Host "Downloading lexicon.txt..."
Invoke-WebRequest -Uri "$sourceRoot/lexicon.txt" -OutFile $sourceLexicon
foreach ($file in @("tokens.txt", "metadata.json")) {
	Write-Host "Downloading $file..."
	Invoke-WebRequest -Uri "$sourceRoot/$file" -OutFile (Join-Path $destination $file)
}

foreach ($file in @{
	"model.onnx" = $sourceModel
	"lexicon.txt" = $sourceLexicon
	"tokens.txt" = (Join-Path $destination "tokens.txt")
	"metadata.json" = (Join-Path $destination "metadata.json")
}.GetEnumerator()) {
	$actualSha256 = (Get-FileHash -Algorithm SHA256 -LiteralPath $file.Value).Hash.ToLowerInvariant()
	if ($actualSha256 -ne $expectedSha256[$file.Key]) {
		throw "Japanese TTS checksum mismatch for $($file.Key). Expected $($expectedSha256[$file.Key]) but received $actualSha256."
	}
}

if (-not (Test-Path -LiteralPath (Join-Path $toolDirectory "onnx"))) {
	Write-Host "Installing pinned ONNX preparation tooling..."
	& $python -m pip install --disable-pip-version-check --target $toolDirectory "onnx==1.19.1"
	if ($LASTEXITCODE -ne 0) {
		throw "Failed to install ONNX preparation tooling."
	}
}

Write-Host "Applying the Sherpa 1.13.5 Japanese MeloTTS compatibility metadata..."
& $python $prepareScript $sourceModel (Join-Path $destination "model.onnx") $sourceLexicon (Join-Path $destination "lexicon.txt") $toolDirectory
if ($LASTEXITCODE -ne 0) {
	throw "Failed to prepare the Japanese TTS model."
}

Write-Host "Japanese MeloTTS model installed at $destination"
