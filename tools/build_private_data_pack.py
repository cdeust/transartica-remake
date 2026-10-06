#!/usr/bin/env python3
"""MIT. Build the owner's separate local data ZIP and payload-free manifest.

ZIP layout matches Godot ProjectSettings.load_resource_pack (4.5).
See tasks/evidence/public-data-pack-20261006.md. Never uploads anything.
"""
import argparse
import hashlib
import json
from pathlib import Path
import zipfile

ROOT = Path(__file__).resolve().parents[1]


def inventory():
    directory = ROOT / "game/private-data"
    files = sorted(p for p in directory.rglob("*") if p.is_file() and p.suffix != ".import")
    entries = []
    for path in files:
        if path.is_symlink():
            raise ValueError(f"Data symlink refused: {path}")
        payload = path.read_bytes()
        entries.append({"path": path.relative_to(ROOT / "game").as_posix(),
                        "size": len(payload), "sha256": hashlib.sha256(payload).hexdigest()})
    return {"format": "transartica-original-data-v1", "files": entries}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--manifest", type=Path, default=ROOT / "game/assets/interface/original-data-manifest.json")
    args = parser.parse_args()
    output = args.output.resolve()
    if not any(directory in output.parents for directory in [ROOT / ".cache", ROOT / "builds"]):
        parser.error("The private pack must stay inside project .cache/ or builds/.")
    manifest = args.manifest.resolve()
    if ROOT not in manifest.parents:
        parser.error("The manifest must stay inside this project.")
    data = inventory()
    output.parent.mkdir(parents=True, exist_ok=True)
    candidate = output.with_suffix(output.suffix + ".tmp")
    with zipfile.ZipFile(candidate, "w", compression=zipfile.ZIP_DEFLATED) as archive:
        for entry in data["files"]:
            info = zipfile.ZipInfo(entry["path"])
            info.compress_type = zipfile.ZIP_DEFLATED
            archive.writestr(info, (ROOT / "game" / entry["path"]).read_bytes())
    candidate.replace(output)
    args.manifest.parent.mkdir(parents=True, exist_ok=True)
    args.manifest.write_text(json.dumps(data, indent=2) + "\n")
    print(json.dumps({"files": len(data["files"]), "payload_bytes": sum(e["size"] for e in data["files"]),
                      "zip_bytes": output.stat().st_size, "pack": str(output),
                      "sha256": hashlib.sha256(output.read_bytes()).hexdigest()}))


if __name__ == "__main__":
    main()
