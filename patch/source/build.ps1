[CmdletBinding()]
param(
	[string] $WixBin = (Join-Path $PSScriptRoot '..\..\build\wix314'),
	[string] $CertificateThumbprint = '',
	[string] $TimestampUrl = 'http://timestamp.digicert.com'
)

$ErrorActionPreference = 'Stop'

$csc = Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
$candle = Join-Path $WixBin 'candle.exe'
$light = Join-Path $WixBin 'light.exe'
$objDirectory = Join-Path $PSScriptRoot '..\..\build\builder-patch-obj'
$patchDirectory = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$builderExe = Join-Path $objDirectory 'BuilderPatch.exe'
$wixObject = Join-Path $objDirectory 'StoryNowBuilderMode.wixobj'
$msi = Join-Path $patchDirectory 'StoryNowBuilderMode.msi'
$licenseRtf = Join-Path $PSScriptRoot 'license.rtf'

foreach ($tool in @($csc, $candle, $light)) {
	if (-not (Test-Path -LiteralPath $tool -PathType Leaf)) {
		throw "Required build tool not found: $tool"
	}
}

[void] (New-Item -ItemType Directory -Path $objDirectory -Force)

& $csc /nologo /target:winexe /optimize+ /out:$builderExe (Join-Path $PSScriptRoot 'BuilderPatch.cs')
if ($LASTEXITCODE -ne 0) {
	throw "C# compiler failed with exit code $LASTEXITCODE."
}

& $candle -nologo "-dBuilderPatchExe=$builderExe" "-dLicenseRtf=$licenseRtf" -out $wixObject (Join-Path $PSScriptRoot 'StoryNowBuilderMode.wxs')
if ($LASTEXITCODE -ne 0) {
	throw "WiX compiler failed with exit code $LASTEXITCODE."
}

& $light -nologo -ext (Join-Path $WixBin 'WixUIExtension.dll') -out $msi $wixObject
if ($LASTEXITCODE -ne 0) {
	throw "WiX linker failed with exit code $LASTEXITCODE."
}

if (-not [string]::IsNullOrWhiteSpace($CertificateThumbprint)) {
	$signTool = Get-ChildItem -Path 'C:\Program Files (x86)\Windows Kits\10\bin' `
		-Filter 'signtool.exe' -Recurse -ErrorAction SilentlyContinue |
		Where-Object { $_.FullName -match '\\x64\\signtool\.exe$' } |
		Sort-Object FullName -Descending |
		Select-Object -First 1
	if ($null -eq $signTool) {
		throw 'SignTool was not found in the Windows SDK.'
	}

	& $signTool.FullName sign /sha1 $CertificateThumbprint /fd SHA256 /tr $TimestampUrl /td SHA256 $msi
	if ($LASTEXITCODE -ne 0) {
		throw "MSI signing failed with exit code $LASTEXITCODE."
	}
}

Write-Output $msi
