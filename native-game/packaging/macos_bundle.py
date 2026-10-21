#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
"""Prepare a private relocatable macOS .app from an already validated executable.

No build, download or launch. See README.md for source contracts and limitations.
"""
from __future__ import annotations

import argparse
from dataclasses import dataclass
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import platform
import plistlib
import re
import shutil
import subprocess
import sys
import uuid

from macos_bundle_macho import (
    LOAD_COMMANDS, SYSTEM_ROOTS, PackageError, expand_path, macho_commands, system_library,
)

HERE = Path(__file__).resolve().parent


def run(*args: str | Path) -> str:
    result = subprocess.run([str(x) for x in args], check=False, text=True, capture_output=True)
    if result.returncode:
        raise PackageError(f"Command failed ({result.returncode}): {args[0]}\n{result.stderr.strip()}")
    return result.stdout


def sha(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def read_json(path: Path):
    with path.open(encoding="utf-8") as stream:
        return json.load(stream)


def relative(name: str) -> Path:
    # public_data_pack.gd::_data_path: no traversal, separators or code replacement.
    value = PurePosixPath(name)
    if not name or "\\" in name or value.is_absolute() or any(p in ("", ".", "..") for p in name.split("/")):
        raise PackageError(f"Unsafe resource name: {name!r}")
    return Path(*value.parts)


def checked_file(path: Path) -> Path:
    if not path.is_file():
        raise PackageError(f"Required file unavailable: {path}")
    return path.resolve(strict=True)


def project_scope(repo: Path) -> Path:
    # Registered worktrees keep their disposable outputs under the same project.
    for index, part in enumerate(repo.parts):
        if part in (".claude", ".worktrees"):
            return Path(*repo.parts[:index])
    return repo


def validate_artwork_override(manifest: dict, original_artwork: dict, artwork_prefix: str):
    comparison = json.loads(json.dumps(manifest))
    if len(comparison["scenes"]) != 8 or len(original_artwork["scenes"]) != 8:
        raise PackageError("Artwork override requires the original eight scenes")
    images = set()
    for scene, original_scene in zip(comparison["scenes"], original_artwork["scenes"]):
        if len(scene["variants"]) != 1:
            raise PackageError("Artwork override requires one variant per scene")
        background = scene["variants"][0]["background"]
        images.add(background["image"])
        for field in ("png_sha256", "rgba_sha256"):
            if not re.fullmatch("[0-9a-f]{64}", background.get(field, "")):
                raise PackageError(f"Invalid override artwork hash: {field}")
            background[field] = original_scene["variants"][0]["background"][field]
    expected = {"res://" + artwork_prefix + f"region-{i:02d}.png" for i in range(8)}
    if images != expected or comparison != original_artwork:
        raise PackageError("Artwork override may change only the eight PNG identities, not registration or dependencies")


def resource_plan(repo: Path, artwork_dir: Path | None = None) -> dict[str, dict]:
    """Exact allowlist plus manifest dependencies; copies contain no import caches."""
    game = repo / "game"
    artwork_prefix = "assets/travel/artwork/world-hd/"
    artwork_root = artwork_dir.resolve(strict=True) if artwork_dir is not None else None
    if artwork_root is not None and (not artwork_root.is_dir() or not artwork_root.is_relative_to(project_scope(repo))):
        raise PackageError("Artwork override must be a directory inside the current project")

    def resource_file(name: str) -> Path:
        item = relative(name)
        if artwork_root is not None and name.startswith(artwork_prefix):
            leaf = name.removeprefix(artwork_prefix)
            if leaf != "manifest.json" and not re.fullmatch(r"region-0[0-7]\.png", leaf):
                raise PackageError(f"Unexpected artwork override resource: {name}")
            actual = checked_file(artwork_root / leaf)
            if not actual.is_relative_to(artwork_root):
                raise PackageError(f"Artwork override escapes its directory: {name}")
            return actual
        return checked_file(game / item)

    manifest = read_json(resource_file(artwork_prefix + "manifest.json"))
    if artwork_root is not None:
        original_artwork = read_json(game / artwork_prefix / "manifest.json")
        validate_artwork_override(manifest, original_artwork, artwork_prefix)
    config = read_json(HERE / "runtime-assets.json")
    selected: dict[str, dict] = {}
    private_root = (game / "private-data").resolve(strict=True)
    original = read_json(game / "assets/interface/original-data-manifest.json")
    if original.get("format") != "transartica-original-data-v1":
        raise PackageError("Original-data edition manifest unavailable")
    edition = {}
    for entry in original["files"]:
        name = entry["path"]
        relative(name)
        if not name.startswith("private-data/") or name in edition or not re.fullmatch("[0-9a-f]{64}", entry["sha256"]):
            raise PackageError("Invalid historical edition inventory")
        edition[name] = entry

    def add(name: str, source: str, expected: str | None = None):
        item = relative(name)
        actual = resource_file(name)
        trusted = private_root if item.parts[0] == "private-data" else game.resolve()
        if not actual.is_relative_to(trusted):
            # Authored asset links may point to retained project artwork, never arbitrary files.
            if not actual.is_relative_to(project_scope(repo)):
                raise PackageError(f"Resource resolves outside project: {name} -> {actual}")
        digest = sha(actual)
        entry = edition.get(name)
        if entry and (digest != entry["sha256"] or actual.stat().st_size != entry["size"]):
            raise PackageError(f"Historical edition mismatch: {name}")
        if expected and digest != expected:
            raise PackageError(f"Artwork identity mismatch: {name}")
        selected.setdefault(name, {"source": str(actual), "sha256": digest, "bytes": actual.stat().st_size,
                                   "reason": source, "edition_verified": entry is not None,
                                   "classification": "private-game-data"})

    for name in config["private_files"]:
        add("private-data/" + name, "runtime private allowlist")
    for name in config["assets"]:
        add("assets/" + name, "runtime artwork allowlist")
    for name in config["atlas_manifests"]:
        doc = read_json(game / "assets" / name)
        add((Path("assets") / relative(name).parent / relative(doc["file"])).as_posix(), name + ":file")
    for scene in manifest["scenes"]:
        if scene["registration"] != "region_bounds" or len(scene["variants"]) != 1:
            raise PackageError("Unsupported world artwork selection")
        background = scene["variants"][0]["background"]
        filename = PurePosixPath(background["image"]).name
        add("assets/travel/artwork/world-hd/" + filename, scene["id"], background["png_sha256"])
    samples = read_json(game / "private-data/audio/manifest.json")["scripts"]
    for script in config["audio_scripts"]:
        if script not in samples:
            raise PackageError(f"Missing runtime audio script: {script}")
        for sample in samples[script]["samples"].values():
            name = sample["file"]
            add(name[6:] if name.startswith("res://") else "private-data/audio/" + name, "audio samples:" + script)
    music_name = "assets/audio/orchestral/music.json" if (game / "assets/audio/orchestral/music.json").is_file() else "private-data/audio/music.json"
    add(music_name, "audio/resources.cpp soundtrack selection")
    for key, track in read_json(game / music_name)["tracks"].items():
        name = track["file"]
        add(name[6:] if name.startswith("res://") else "private-data/audio/" + name, "music cue:" + key)
    return dict(sorted(selected.items()))


def resolve_load(name: str, loader: Path, executable: Path, rpaths: list[Path]) -> Path:
    if name.startswith("@rpath/"):
        for base in rpaths:
            candidate = base / name.removeprefix("@rpath/")
            if candidate.is_file():
                return candidate.resolve(strict=True)
        raise PackageError(f"Unresolved {name} loaded by {loader}")
    return checked_file(expand_path(name, loader, executable))


def dependency_plan(executable: Path) -> dict[Path, dict]:
    root = checked_file(executable)
    architecture = set(run("/usr/bin/lipo", "-archs", root).split())
    pending = [(root, [])]
    result: dict[Path, dict] = {}
    while pending:
        source, inherited = pending.pop(0)
        if source in result:
            continue
        commands = macho_commands(run("/usr/bin/otool", "-l", source))
        available = set(run("/usr/bin/lipo", "-archs", source).split())
        if not architecture <= available:
            raise PackageError(f"Architecture mismatch in {source}: {sorted(available)}")
        local = [expand_path(name, source, root) for name in commands["rpaths"]]
        search = local + inherited
        edges = {}
        for name in commands["loads"]:
            if system_library(name):
                continue
            target = resolve_load(name, source, root, search)
            edges[name] = target
            pending.append((target, search))
        result[source] = {"commands": commands, "edges": edges, "sha256": sha(source), "architectures": sorted(available)}
    return result


def library_names(graph: dict[Path, dict], executable: Path) -> dict[Path, str]:
    names, hashes, occupied, bindings = {}, {}, {}, {}
    for source in sorted(graph, key=str):
        if source == executable:
            continue
        digest = graph[source]["sha256"]
        edges = {name: graph[target]["sha256"] for name, target in graph[source]["edges"].items()}
        if digest in hashes:
            if edges != bindings[digest]:
                raise PackageError(f"Identical Mach-O bytes resolve different dependencies: {source}")
            names[source] = hashes[digest]
            continue
        name = source.name
        if name in occupied and occupied[name] != digest:
            name = source.stem + "-" + digest[:12] + source.suffix
        occupied[name] = digest
        bindings[digest] = edges
        hashes[digest] = names[source] = name
    return names


def cellar_root(path: Path) -> Path | None:
    for parent in path.parents:
        if (parent / "INSTALL_RECEIPT.json").is_file():
            return parent
    return None


def installed_licenses(root: Path) -> list[Path]:
    return [candidate for candidate in root.iterdir()
            if candidate.is_file() and re.fullmatch(
                r"(?:LICENSE|COPYING|COPYRIGHT|LGPL[-.].+)(?:\..*)?", candidate.name, re.IGNORECASE)]


def license_plan(graph: dict[Path, dict], executable: Path, extra: dict) -> dict[str, list[Path]]:
    result = {}
    for source in graph:
        if source == executable:
            continue
        root = cellar_root(source)
        key = root.parent.name if root else source.name
        if key in result:
            continue
        supplied = extra.get(key, [])
        if not isinstance(supplied, list):
            raise PackageError(f"License map {key} must be an array of complete text paths")
        files = [checked_file(Path(name).expanduser()) for name in supplied]
        if root:
            files.extend(installed_licenses(root))
        files = sorted(set(files), key=str)
        if not files:
            raise PackageError(f"No installed license text for {key}; provide --license-map")
        if key == "freetype" and not any(p.name.upper() == "FTL.TXT" for p in files):
            raise PackageError("FreeType LICENSE.TXT refers to absent FTL.TXT; supply its complete text via --license-map")
        result[key] = files
    return result


def validate_closed_macho(path: Path, app: Path) -> dict:
    commands = macho_commands(run("/usr/bin/otool", "-l", path))
    if commands["rpaths"]:
        raise PackageError(f"Unnecessary retained rpaths in {path}")
    for name in commands["loads"]:
        if system_library(name):
            continue
        if not name.startswith("@loader_path/"):
            raise PackageError(f"External dynamic dependency remains: {path}: {name}")
        target = expand_path(name, path, app / "Contents/MacOS/Transartica").resolve(strict=True)
        if not target.is_file() or not target.is_relative_to(app.resolve()):
            raise PackageError(f"Dylib escapes bundle: {name}")
    return commands


def copy_file(source: Path, destination: Path):
    destination.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(source, destination, follow_symlinks=True)
    destination.chmod(0o755 if os.access(source, os.X_OK) else 0o644)


def publish_bundle(stage: Path, output: Path, receipt: dict) -> Path:
    """Prepare the complete receipt first; roll back the bundle on publication failure.

    Two sibling paths cannot share a single rename transaction. The candidate is
    retained on failure, including a failed rollback, for explicit recovery.
    link(2) installs the already complete receipt without replacing an existing file.
    """
    receipt_path = Path(str(output) + ".receipt.json")
    candidate = Path(str(stage) + ".receipt.json")
    if output.exists() or output.is_symlink() or receipt_path.exists() or receipt_path.is_symlink():
        raise PackageError("Refusing to replace an existing bundle or receipt")
    with candidate.open("x", encoding="utf-8") as stream:
        json.dump(receipt, stream, indent=2, sort_keys=True)
        stream.write("\n")
        stream.flush()
        os.fsync(stream.fileno())
    published = False
    try:
        stage.rename(output)
        published = True
        os.link(candidate, receipt_path)
    except Exception as error:
        if published:
            try:
                output.rename(stage)
            except OSError as rollback:
                raise PackageError(
                    f"Publication failed ({error}); bundle rollback also failed ({rollback}). "
                    f"Retained bundle: {output}; complete receipt candidate: {candidate}"
                ) from error
        raise
    # Both final outputs are complete. A cleanup failure must not undo success.
    try:
        candidate.unlink()
    except OSError as error:
        print(f"Complete redundant receipt candidate retained: {candidate}: {error}", file=sys.stderr)
    return receipt_path


@dataclass(frozen=True)
class BundlePlan:
    repo: Path
    executable: Path
    resources: dict
    graph: dict
    licenses: dict


def copy_resources(plan: BundlePlan, data: Path):
    for name, entry in plan.resources.items():
        copy_file(Path(entry["source"]), data / "game" / relative(name))
    copy_file(plan.repo / "native-game/assets/fonts/NotoSans.ttf", data / "fonts/NotoSans.ttf")
    copy_file(plan.repo / "native-game/assets/fonts/OFL.txt", data / "licenses/NotoSans-OFL.txt")
    copy_file(plan.repo / "LICENSE", data / "licenses/project-MIT.txt")
    copy_file(plan.repo / "native-game/third_party/godot-math-LICENSE.txt", data / "licenses/godot-math-MIT.txt")
    if "assets/audio/orchestral/music.json" in plan.resources:
        copy_file(plan.repo / "game/assets/audio/orchestral/LICENSE.md", data / "licenses/authored-score.md")
    for key, files in plan.licenses.items():
        for index, source in enumerate(files):
            copy_file(source, data / "licenses" / key / (str(index) + "-" + source.name))
    (data / "PRIVATE-DATA-NOTICE.txt").write_text(
        "PRIVATE LOCAL GAME BUILD. Do not publish this bundle.\n"
        "The project MIT license covers source code, not historical game data.\n"
        "Historical assets and full derived datasets remain private.\n"
        "This software is based in part on the work of the FreeType Team (https://freetype.org).\n"
        "SDL2 and other libraries are separately licensed; see licenses/.\n"
        "Ad-hoc signing is local integrity metadata, not notarization or distribution approval.\n", encoding="utf-8")
    inventory = {name: {k: v for k, v in value.items() if k != "source"} for name, value in plan.resources.items()}
    (data / "resource-inventory.json").write_text(json.dumps(inventory, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def copy_libraries(plan: BundlePlan, contents: Path):
    binary = contents / "MacOS/Transartica"
    frameworks = contents / "Frameworks"
    names = library_names(plan.graph, plan.executable)
    destinations = {plan.executable: binary}
    for source, name in names.items():
        destination = frameworks / name
        if not destination.exists():
            copy_file(source, destination)
            destination.chmod(0o755)
        destinations[source] = destination
    return names, destinations


def write_info(contents: Path, graph: dict):
    minimum = [v for record in graph.values() for v in record["commands"]["minimum"]]
    info = {"CFBundleExecutable": "Transartica", "CFBundleIdentifier": "org.transartica.native.local",
            "CFBundleName": "Transartica", "CFBundleDisplayName": "Transartica", "CFBundlePackageType": "APPL",
            "CFBundleShortVersionString": "0.1.0", "CFBundleVersion": "1", "SDL_FILESYSTEM_BASE_DIR_TYPE": "resource",
            "NSHighResolutionCapable": True}
    if minimum:
        info["LSMinimumSystemVersion"] = max(minimum, key=lambda v: tuple(map(int, v.split("."))))
    with (contents / "Info.plist").open("wb") as stream:
        plistlib.dump(info, stream, sort_keys=True)


def patch_libraries(plan: BundlePlan, names: dict, destinations: dict) -> set[Path]:
    patched = set()
    for source, record in plan.graph.items():
        destination = destinations[source]
        if destination in patched:
            continue
        command = ["/usr/bin/install_name_tool"]
        for old, target in record["edges"].items():
            new = "@loader_path/" + ("../Frameworks/" if source == plan.executable else "") + names[target]
            command += ["-change", old, new]
        if record["commands"]["id"]:
            command += ["-id", "@loader_path/" + names[source]]
        for old in record["commands"]["rpaths"]:
            command += ["-delete_rpath", old]
        if len(command) > 1:
            run(*command, destination)
        patched.add(destination)
    return patched


def sign_and_receipt(plan: BundlePlan, stage: Path, destinations: dict, patched: set[Path]) -> dict:
    binary = stage / "Contents/MacOS/Transartica"
    closed = {}
    for destination in sorted(patched):
        closed[destination.relative_to(stage).as_posix()] = validate_closed_macho(destination, stage)
    for destination in sorted(set(destinations.values()) - {binary}):
        run("/usr/bin/codesign", "--force", "--sign", "-", destination)
    run("/usr/bin/codesign", "--force", "--sign", "-", stage)
    run("/usr/bin/codesign", "--verify", "--deep", "--strict", stage)
    files = {}
    for path in sorted(stage.rglob("*")):
        if path.is_symlink():
            raise PackageError(f"Bundle still has an external link: {path}")
        if path.is_file():
            files[path.relative_to(stage).as_posix()] = {"sha256": sha(path), "bytes": path.stat().st_size}
    receipt = {"format": "transartica-private-native-macos-v1", "platform": platform.platform(),
               "source_executable_sha256": plan.graph[plan.executable]["sha256"], "architectures": plan.graph[plan.executable]["architectures"],
               "private": True, "runtime_tested": False, "codesign_verified": True, "files": files,
               "macho": closed, "dependency_sources": {str(p): r["sha256"] for p, r in plan.graph.items()}}
    return receipt


def build(plan: BundlePlan, output: Path):
    if output.suffix != ".app" or output.exists() or Path(str(output) + ".receipt.json").exists():
        raise PackageError("Output must be a new .app path with no existing receipt")
    if not output.parent.is_relative_to(project_scope(plan.repo)):
        raise PackageError("Keep bundle outputs inside the current project/worktree")
    output.parent.mkdir(parents=True, exist_ok=True)
    stage = output.parent / ("." + output.name + ".incoming-" + uuid.uuid4().hex)
    stage.mkdir()
    try:
        contents = stage / "Contents"
        binary = contents / "MacOS/Transartica"
        copy_file(plan.executable, binary)
        binary.chmod(0o755)
        copy_resources(plan, contents / "Resources")
        names, destinations = copy_libraries(plan, contents)
        write_info(contents, plan.graph)
        patched = patch_libraries(plan, names, destinations)
        receipt = sign_and_receipt(plan, stage, destinations, patched)
        receipt_path = publish_bundle(stage, output, receipt)
        files = receipt["files"]
        return {"bundle": str(output), "receipt": str(receipt_path), "files": len(files), "bytes": sum(x["bytes"] for x in files.values())}
    except Exception:
        retained = [str(path) for path in (stage, Path(str(stage) + ".receipt.json"), output,
                    Path(str(output) + ".receipt.json")) if path.exists() or path.is_symlink()]
        print("Packaging failed; existing paths retained for inspection: " + ", ".join(retained), file=sys.stderr)
        raise



def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo", type=Path, default=HERE.parents[1])
    parser.add_argument("--binary", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--artwork-dir", type=Path, help="Private in-project world-hd candidate: same manifest registration and eight PNGs")
    parser.add_argument("--license-map", type=Path, help="JSON: formula/name -> array of complete local license text paths")
    parser.add_argument("--plan", action="store_true", help="Read and hash only; do not copy, patch or sign")
    args = parser.parse_args()
    if sys.platform != "darwin":
        raise PackageError("This packager supports a real macOS host only")
    repo = args.repo.resolve(strict=True)
    executable = checked_file(args.binary)
    resources = resource_plan(repo, args.artwork_dir)
    graph = dependency_plan(executable)
    library_names(graph, executable)  # Detect conflicting duplicate-byte resolution before any copies.
    licenses = license_plan(graph, executable, read_json(args.license_map) if args.license_map else {})
    if args.plan:
        print(json.dumps({"resource_files": len(resources), "resource_bytes": sum(r["bytes"] for r in resources.values()),
                          "dynamic_libraries": [str(p) for p in graph if p != executable],
                          "licenses": {k: [str(p) for p in v] for k, v in licenses.items()},
                          "resources": resources}, indent=2, sort_keys=True))
    else:
        plan = BundlePlan(repo, executable, resources, graph, licenses)
        print(json.dumps(build(plan, args.output.resolve()), indent=2))
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (OSError, ValueError, KeyError, PackageError) as error:
        print(f"Packaging refused: {error}", file=sys.stderr)
        raise SystemExit(1)
