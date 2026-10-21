#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
"""Read-only integrity/dependency check of an already moved macOS bundle.

Does not consult the checkout, Homebrew or original dependency sources in receipt.
Does not launch the game; successful verification is not runtime acceptance.
"""
import argparse
import json
from pathlib import Path
import sys
from macos_bundle import PackageError, relative, run, sha, validate_closed_macho


def verify(bundle: Path, receipt_path: Path) -> dict:
    bundle = bundle.resolve(strict=True)
    receipt = json.loads(receipt_path.read_text(encoding="utf-8"))
    if receipt.get("format") != "transartica-private-native-macos-v1" or not receipt.get("private"):
        raise PackageError("Unsupported private bundle receipt")
    observed = set()
    for path in bundle.rglob("*"):
        if path.is_symlink():
            raise PackageError(f"Unexpected bundle symlink: {path}")
        if path.is_file():
            observed.add(path.relative_to(bundle).as_posix())
    if observed != set(receipt["files"]):
        raise PackageError("Bundle file inventory differs from receipt")
    for name, expected in receipt["files"].items():
        path = bundle / relative(name)
        if path.stat().st_size != expected["bytes"] or sha(path) != expected["sha256"]:
            raise PackageError(f"Bundle integrity mismatch: {name}")
    if sys.platform != "darwin":
        raise PackageError("SHA inventory checked, but Mach-O/signature verification requires actual macOS")
    for name, expected in receipt["macho"].items():
        if validate_closed_macho(bundle / relative(name), bundle) != expected:
            raise PackageError(f"Mach-O load commands differ from receipt: {name}")
    run("/usr/bin/codesign", "--verify", "--deep", "--strict", bundle)
    return {"bundle": str(bundle), "files_verified": len(observed), "codesign_verified": True, "runtime_tested": False}


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("bundle", type=Path)
    parser.add_argument("--receipt", type=Path, help="Defaults to sibling <bundle>.receipt.json")
    args = parser.parse_args()
    try:
        print(json.dumps(verify(args.bundle, args.receipt or Path(str(args.bundle) + ".receipt.json")), indent=2))
    except (OSError, ValueError, KeyError, PackageError) as error:
        print(f"Bundle verification failed: {error}", file=sys.stderr)
        raise SystemExit(1)
