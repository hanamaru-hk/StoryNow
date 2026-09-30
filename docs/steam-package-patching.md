# Steam Package Path-Shortening and ComfyUI Patching

The repository's local and packaged ComfyUI runtime uses the gitignored
`s/c/` directory. The shortened names keep both development and
default Steam installation paths below the legacy Windows path limit.

## Target Layout

Set the Steamworks install directory to `SN` and package the ComfyUI portable
root as `s/c`:

```text
<SteamLibrary>/steamapps/common/SN/
├── StoryNow.exe
└── s/
    └── c/
        ├── py/python.exe
        └── ComfyUI/main.py
```

Here, `c` replaces `ComfyUI` and `py` replaces `python_embeded`. With the
ComfyUI bundle measured on 2026-09-02, its longest path under the default Steam
library becomes 247 visible characters:

```text
C:\Program Files (x86)\Steam\steamapps\common\SN\s\c\py\Lib\site-packages\torch-2.13.0+cu130.dist-info\licenses\third_party\kineto\libkineto\third_party\dynolog\third_party\prometheus-cpp\3rdparty\civetweb\src\third_party\duktape-1.8.0\LICENSE.txt
```

That leaves 12 visible characters before the classic Windows limit of 259
visible characters (`MAX_PATH` is 260 including the terminating null). Recheck
the package after every Python, PyTorch, or ComfyUI update because dependency
paths can change.

## Initial Installation or Full Runtime Replacement

1. Stop StoryNow and ComfyUI before changing the runtime.
2. Extract the official ComfyUI portable root into `s/c/`.
3. Rename `s/c/python_embeded/` to `s/c/py/`.
4. Rewrite every active ComfyUI launcher and updater reference in `s/c/` from
   `python_embeded` to `py`. This includes the root `run_*.bat` files and files
   under `update/` and `advanced/`. References in ComfyUI's `.ci/` and
   `.github/` directories are not needed at runtime; omit those directories
   from the shipped package when possible.
5. Update `s/c/ComfyUI/server.py` so its `embedded_python` check recognizes `py`,
   or accepts both `py` and `python_embeded`. Without this patch ComfyUI can
   still start, but it reports the packaged interpreter as non-embedded.
6. Confirm `scripts/image_server_manager.gd` uses `COMFYUI_DIR := "s/c"` and
   `/py/python.exe`. The Japanese TTS helper also uses `s/c/py/python.exe`.

The included `s/c/update/*.bat` scripts are patched to use `s/c/py` and can update
the existing runtime. Replacing it from a new official portable archive normally
recreates `python_embeded`; repeat the rename and patches after every full
replacement.

## Verification

Before running or uploading, search the runtime for missed hard-coded references:

```powershell
rg -n --no-ignore "python_embeded|python_embedded" c
```

Review each match. Active launchers, updater scripts, and runtime code must not
depend on the old directory. The compatibility check in `ComfyUI/server.py`
intentionally contains `python_embeded`; matches in omitted CI or
release-building files do not affect the runtime.

Measure all runtime paths from the expected Steam installation root:

```powershell
$steamRoot = 'C:\Program Files (x86)\Steam\steamapps\common\SN'
Get-ChildItem -LiteralPath c -File -Recurse -Force |
	ForEach-Object {
		$relative = $_.FullName.Substring((Resolve-Path '.').Path.Length)
		$installed = $steamRoot + $relative
		[PSCustomObject]@{ Length = $installed.Length; Path = $installed }
	} |
	Sort-Object Length -Descending |
	Select-Object -First 10
```

Keep every visible path at 259 characters or fewer. Prefer additional headroom
rather than relying on the Windows long-path policy, because every executable,
library, installer, antivirus tool, and updater touching the package would need
compatible long-path handling.

Finally, launch the build through Steam and exercise image-server start,
health check, image generation, stop, and any supported update path.

## Standalone Builder-Mode Patch

The `patch/` directory contains `StoryNowBuilderMode.msi`, a per-user Windows
Installer package that enables builder mode in an installed Steam copy. It
contains no PowerShell or batch scripts, does not download anything, and does
not request elevation. The embedded patch action reads Steam's Windows registry
locations, parses `steamapps/libraryfolders.vdf` so custom Steam libraries are
included, and looks for the exact install folder `steamapps/common/SN`.

For every installed `SN` folder found, it creates this zero-byte marker:

```text
SN/data/builder/builder
```

The install fails and makes no changes when no matching install is found.
Uninstalling the MSI removes the marker. Build sources are under `patch/source`;
its build script expects the portable WiX 3.14 tools under `build/wix314`.

The package deliberately does not attempt to disable Windows security checks.
Before public distribution, Authenticode-sign the MSI with a trusted code-
signing certificate to give Windows verifiable publisher identity and reduce
reputation warnings. An unsigned MSI downloaded from the Internet can still
trigger a Windows warning even though the package itself requests no elevation.
Pass the certificate's SHA-1 thumbprint to the build script to sign and
timestamp the MSI using the Windows SDK's SignTool:

```powershell
./patch/source/build.ps1 -CertificateThumbprint '<thumbprint>'
```

For a patch shipped as part of a Steam depot, prefer a signed Steam install
script instead: Steam exposes the exact application path as `%INSTALLDIR%` and
can run a bundled process before first launch. The standalone patch exists for
distribution outside that depot workflow.
