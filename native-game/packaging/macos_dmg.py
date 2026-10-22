#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
"""Create and verify a drag-to-Applications disk image from a sealed app.

Source: macOS hdiutil(1), create -srcfolder, verify, attach -readonly, detach.
The input receipt proves bytes and linkage. Runtime testing remains separate.
"""
from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
import shutil
import sys
import tempfile

from macos_bundle import PackageError, run, sha
from verify_macos_bundle import verify


def mounted_check(image: Path, mount: Path, bundle_name: str, receipt: Path) -> dict:
    run("/usr/bin/hdiutil", "attach", image, "-readonly", "-nobrowse", "-mountpoint", mount)
    try:
        link = mount / "Applications"
        if not link.is_symlink() or os.readlink(link) != "/Applications":
            raise PackageError("Disk image Applications link is invalid")
        return verify(mount / bundle_name, receipt)
    finally:
        # Never force-detach a device or silently ignore a retained mount.
        run("/usr/bin/hdiutil", "detach", mount)


def publish(candidate: Path, output: Path, report: Path, result: dict) -> None:
    receipt_candidate = candidate.with_suffix(".receipt.json")
    receipt_candidate.write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    # Hard links publish without clobbering even under concurrent invocations.
    os.link(candidate, output)
    try:
        os.link(receipt_candidate, report)
    except BaseException:
        if output.samefile(candidate):
            output.unlink()
        raise


def create(bundle: Path, receipt: Path, output: Path, scratch: Path) -> dict:
    if sys.platform != "darwin":
        raise PackageError("Disk image creation requires macOS")
    report = Path(str(output) + ".receipt.json")
    if output.suffix != ".dmg" or output.exists() or report.exists():
        raise PackageError("Use a new .dmg output path with no existing receipt")
    verify(bundle, receipt)
    scratch.mkdir(parents=True, exist_ok=True)
    stage = Path(tempfile.mkdtemp(prefix="dmg-", dir=scratch))
    content, mount = stage / "content", stage / "mount"
    content.mkdir()
    mount.mkdir()
    candidate = stage / "Transartica.dmg"
    try:
        run("/usr/bin/ditto", bundle, content / bundle.name)
        (content / "Applications").symlink_to("/Applications")
        (content / "Install.txt").write_text("Drag Transartica.app to Applications, then eject this disk image.\n", encoding="utf-8")
        run("/usr/bin/hdiutil", "create", "-srcfolder", content, "-volname", "Transartica", "-fs", "HFS+", "-format", "UDZO", candidate)
        run("/usr/bin/hdiutil", "verify", candidate)
        checked = mounted_check(candidate, mount, bundle.name, receipt)
        result = {"format": "transartica-native-dmg-v1", "sha256": sha(candidate),
                  "bytes": candidate.stat().st_size, "bundle_receipt_sha256": sha(receipt),
                  "files_verified": checked["files_verified"], "runtime_tested": False,
                  "codesign_verified": True, "notarized": False}
        output.parent.mkdir(parents=True, exist_ok=True)
        publish(candidate, output, report, result)
        shutil.rmtree(stage)
        return result
    except BaseException:
        print(f"Disk image staging retained for inspection: {stage}", file=sys.stderr)
        raise


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ("bundle", "receipt", "output", "scratch"):
        parser.add_argument("--" + name, required=True, type=Path)
    args = parser.parse_args()
    try:
        print(json.dumps(create(args.bundle.resolve(), args.receipt.resolve(), args.output.resolve(), args.scratch.resolve()), indent=2))
    except (OSError, ValueError, KeyError, PackageError) as error:
        print(f"Disk image creation failed: {error}", file=sys.stderr)
        raise SystemExit(1)


if __name__ == "__main__":
    main()
