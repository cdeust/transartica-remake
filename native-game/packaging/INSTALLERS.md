# Native installers

The Windows installer installs the C++ executable and its complete resources in
the current user's local Programs directory. It creates a Start menu shortcut
and provides an uninstaller. Saves use SDL's user preference directory, outside
the installation, and are retained by uninstall. No separate data download occurs.

`native-windows-delivery.yml` builds on Windows Server 2025 with MSYS2 UCRT64.
Actions are pinned to revisions. The resolved compiler and package versions are
retained in the delivery artifact; the rolling package repository means this is
a repeatable procedure, not a claim of byte-for-byte rebuild determinism.

The DLL closure comes from GNU objdump's PE imports. It includes transitive
non-system DLLs from the selected UCRT64 installation. Every copied library must
have an owning pacman package and installed license texts. Windows API set
contracts are resolved by the Windows loader with the System32 search scope.
Missing DLLs or license texts fail packaging.

The workflow uses Inno Setup to generate `Transartica-setup.exe`, silently
installs that executable into a fresh directory, verifies every installed file
against its hash, and launches the installed game from another working directory
with a system-only PATH. The SDL renderer must initialize, the music cursor must
advance, and the process must exit normally. The uninstaller must then remove
the executable. Hosted Windows audio uses SDL's dummy driver; the receipt records
that this does not prove physical audio or gameplay input. CTest separately runs
the native game and save archive regression suites on Windows.

Only a successful run of this workflow establishes Windows execution. The
workflow's presence and the local Python unit tests do not establish it. The
artifact includes the installer and logs even after a failure, so check the job
result and `windows-smoke/receipt.json` before distributing it.

The manual `publish-native-installer.yml` workflow can transfer a verified
installer directly from Actions to an existing draft release. It requires the
source run ID, its full source commit SHA, and the draft release tag. For the
final nine-cue soundtrack build:

```sh
gh workflow run publish-native-installer.yml --ref main \
  -f source_run=39862770188 \
  -f expected_sha=3953e35fa11f34fb0e8f7875f9754d2e0d007973 \
  -f release_tag=native-v0.1.0
```

The publisher requires a successful `Native Windows installer` run from the
same repository and the exact supplied commit. It checks the downloaded ZIP's
size and SHA256 against GitHub's artifact metadata, the installer against its
Windows installation receipt, and all nine music hashes plus the music manifest
against that source commit. It also checks the final title's frame count and
advancing playback in the Windows log. Downloaded artifact code is never run.

Only `Transartica-setup.exe` is uploaded. An existing installer asset or a public
release causes refusal. Other release assets remain intact; the release stays
draft. The remote asset's size and SHA256 must match after upload. The small
`native-installer-publication-<run-id>` Actions artifact preserves
`publication.json`, the package and installation receipts, runtime logs and
CTest output. A successful publication receipt includes `release_asset`;
receipts without that field record verification before upload, not publication.
The original Windows limits still apply: hosted dummy audio and startup checks
do not establish physical listening or gameplay input.

For macOS, first build and validate the app using the existing bundle procedure
in [README.md](README.md). Then run, using new output paths:

```sh
python3 -B native-game/packaging/macos_dmg.py \
  --bundle output/Transartica.app \
  --receipt output/Transartica.app.receipt.json \
  --output output/Transartica-macOS-arm64.dmg \
  --scratch disk-hygiene-OWNED/installers
```

The disk image contains the app and an Applications link. The creator verifies
the input bundle, builds a compressed HFS+ image, verifies the image checksum,
mounts it read-only, and verifies every app file and its signature from the
mounted image. It detaches without force. On failure, its exact staging path is
printed and retained for inspection. Existing destinations are never replaced.
Image publication is rolled back if receipt publication fails. The output and
scratch must reside on the same filesystem because publication uses hard links.

This script does not notarize or obtain a Developer ID certificate. The package
signature and download trust status must be reported according to the actual
identity used by the app packager. An ad-hoc signature alone does not establish
Gatekeeper acceptance after downloading. The published app must also be copied
out of the mounted image and launched before recording installation acceptance.

## Verification commands

```sh
python3 -B -m unittest discover -s native-game/packaging -p 'test_*installer*.py'
```

`test_installers.py` covers dependency recursion, unsafe import names, absent
dependencies, package license requirements, resource staging delegation, API
contract handle release, destination preservation, mounted verification, detach
on failure, and receipt publication rollback. Real Windows installation and
macOS image creation remain host integration checks.

## Platform sources

- [MSYS2 CI documentation](https://www.msys2.org/docs/ci/)
- [Windows runner software inventory](https://github.com/actions/runner-images/blob/main/images/windows/Windows2025-Readme.md)
- [Inno Setup command line](https://jrsoftware.org/ishelp/topic_setupcmdline.htm)
- [Inno Setup privilege mode](https://jrsoftware.org/ishelp/topic_setup_privilegesrequired.htm)
- [Inno Setup architecture selection](https://jrsoftware.org/ishelp/topic_setup_architecturesallowed.htm)
- [Windows API set contracts](https://learn.microsoft.com/en-us/windows/win32/apiindex/windows-apisets)
- [LoadLibraryExW search flags](https://learn.microsoft.com/en-us/windows/win32/api/libloaderapi/nf-libloaderapi-loadlibraryexw)
- Installed macOS `hdiutil(1)` manual, `create`, `verify`, `attach`, and `detach`.
- SDL2 `SDL_main.h`: define `SDL_MAIN_HANDLED` for an application-owned entry
  point and call `SDL_SetMainReady` before device initialization.
