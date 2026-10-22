#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
"""Stage the native resource closure beside a build or installed executable."""
from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
import shutil
import sys
import uuid

from macos_bundle import PackageError, checked_file, relative, resource_plan, sha


def ancillary_files(repo: Path, resources: dict) -> dict[str, Path]:
    files = {
        "fonts/NotoSans.ttf": repo / "native-game/assets/fonts/NotoSans.ttf",
        "licenses/NotoSans-OFL.txt": repo / "native-game/assets/fonts/OFL.txt",
        "licenses/project-MIT.txt": repo / "LICENSE",
        "licenses/godot-math-MIT.txt": repo / "native-game/third_party/godot-math-LICENSE.txt",
        "RESOURCE-NOTICE.txt": repo / "native-game/packaging/RESOURCE-NOTICE.txt",
    }
    if "assets/audio/orchestral/music.json" in resources:
        files["licenses/authored-score.md"] = repo / "game/assets/audio/orchestral/LICENSE.md"
    return files


def stage_plan(repo: Path) -> dict:
    resources = resource_plan(repo)
    result = {"game/" + name: dict(entry) for name, entry in resources.items()}
    for name, source in ancillary_files(repo, resources).items():
        source = checked_file(source)
        result[name] = {"source": str(source), "sha256": sha(source), "bytes": source.stat().st_size,
                        "classification": "font-or-license"}
    for entry in result.values():
        if not Path(entry["source"]).is_relative_to(repo):
            raise PackageError(f"Runtime source outside checkout: {entry['source']}")
    return dict(sorted(result.items()))


def destination_path(output: Path, name: str) -> Path:
    destination = output / relative(name)
    if destination.is_symlink() or not destination.resolve().is_relative_to(output):
        raise PackageError(f"Runtime destination escapes its directory: {name}")
    return destination


def copy_changed(entry: dict, destination: Path) -> bool:
    if destination.is_file() and sha(destination) == entry["sha256"]:
        return False
    destination.parent.mkdir(parents=True, exist_ok=True)
    candidate = destination.with_name("." + destination.name + ".incoming-" + uuid.uuid4().hex)
    try:
        shutil.copyfile(entry["source"], candidate)
        if sha(candidate) != entry["sha256"]:
            raise PackageError(f"Runtime source changed during staging: {entry['source']}")
        candidate.chmod(0o644)
        os.replace(candidate, destination)
    finally:
        candidate.unlink(missing_ok=True)
    return True


def prune_previous(output: Path, previous: dict, current: dict):
    for name in previous.keys() - current.keys():
        path = destination_path(output, name)
        if path.is_file():
            path.unlink()


def synchronize(selected: dict, output: Path) -> dict:
    if output.is_symlink():
        raise PackageError("Runtime output must not be a symlink")
    output = output.resolve()
    if any(Path(entry["source"]).is_relative_to(output) for entry in selected.values()):
        raise PackageError("Runtime output overlaps source resources")
    inventory = destination_path(output, "resource-inventory.json")
    previous = json.loads(inventory.read_text()) if inventory.is_file() else {}
    public = {name: {key: value for key, value in entry.items() if key != "source"}
              for name, entry in selected.items()}
    changed = sum(copy_changed(entry, destination_path(output, name)) for name, entry in selected.items())
    prune_previous(output, previous, public)
    candidate = inventory.with_name(".resource-inventory-" + uuid.uuid4().hex + ".json")
    try:
        candidate.write_text(json.dumps(public, indent=2, sort_keys=True) + "\n", encoding="utf-8")
        os.replace(candidate, inventory)
    finally:
        candidate.unlink(missing_ok=True)
    return {"files": len(selected), "copied": changed, "output": str(output)}


def stage(repo: Path, output: Path) -> dict:
    selected = stage_plan(repo.resolve(strict=True))
    return synchronize(selected, output)


def install_staged(source: Path, output: Path) -> dict:
    source = source.resolve(strict=True)
    inventory = destination_path(source, "resource-inventory.json")
    selected = json.loads(inventory.read_text())
    if not isinstance(selected, dict) or not selected:
        raise PackageError("Runtime inventory must contain resource entries")
    for name, entry in selected.items():
        actual = checked_file(destination_path(source, name))
        if actual.stat().st_size != entry["bytes"] or sha(actual) != entry["sha256"]:
            raise PackageError(f"Staged resource identity mismatch: {name}")
        entry["source"] = str(actual)
    return synchronize(selected, output)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    source = parser.add_mutually_exclusive_group(required=True)
    source.add_argument("--repo", type=Path)
    source.add_argument("--from-staged", type=Path)
    parser.add_argument("--output", required=True, type=Path)
    args = parser.parse_args()
    try:
        result = install_staged(args.from_staged, args.output) if args.from_staged else stage(args.repo, args.output)
        print(json.dumps(result, sort_keys=True))
        return 0
    except (OSError, ValueError, KeyError, PackageError) as error:
        print(f"Runtime staging failed: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
