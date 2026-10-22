#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
"""Root-run only: tiny positive control and rejected authoring inputs.

Run under the existing resource guard, with an already registered empty scratch:
  python3 world_join_compose_validation.py --binary COMPOSITOR --scratch-dir DIR
No original artwork, installs, downloads or unregistered temporary directories.
"""
import argparse
import copy
from dataclasses import dataclass
import hashlib
import json
from pathlib import Path
import struct
import subprocess
import zlib


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def write_json(path, value):
    path.write_text(json.dumps(value, indent=2, allow_nan=False) + "\n")


def png(path, width, height, color):
    # PNG specification: RGBA8, filter type 0, zlib IDAT, standard chunk CRC.
    def chunk(name, payload):
        return (struct.pack(">I", len(payload)) + name + payload
                + struct.pack(">I", zlib.crc32(name + payload)))
    rgba = bytes(color) if len(color) == width * height * 4 else bytes(color) * width * height
    assert len(rgba) == width * height * 4
    rows = b"".join(b"\0" + rgba[y*width*4:(y+1)*width*4] for y in range(height))
    path.write_bytes(b"\x89PNG\r\n\x1a\n"
                     + chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0))
                     + chunk(b"IDAT", zlib.compress(rows)) + chunk(b"IEND", b""))
    return hashlib.sha256(rgba).hexdigest()


def fixture(scratch):
    artwork = scratch / "original"
    artwork.mkdir()
    scenes = []
    for i, color in enumerate(((255, 0, 0, 255), (0, 0, 255, 255))):
        image = artwork / f"region-{i}.png"
        rgba = png(image, 4, 4, color)
        scenes.append({"id": f"fixture-{i}", "registration": "region_bounds",
                       "world": [i*4, 0, 4, 4], "variants": [{"size": [4, 4],
                       "source_crop": [0, 0, 4, 4], "background": {
                           "image": image.name, "png_sha256": sha(image), "rgba_sha256": rgba}}]})
    map_sha = hashlib.sha256(b"fixture-map-identity").hexdigest()
    write_json(artwork / "manifest.json", {"schema": 1, "source_map_sha256": map_sha, "scenes": scenes})
    inventory = scratch / "inventory.json"
    write_json(inventory, {"source_map_sha256": map_sha, "dimensions": [8, 4],
                          "features": [{"kind": "town_footprint", "world": [0, 0, 1, 1],
                                        "city_records": [{"source_index": 0, "name": "FIXTURE", "anchor": [0, 0]}]}]})
    patch = scratch / "patch.png"
    png(patch, 8, 4, (0, 255, 0, 255))
    spec = {"schema": 1, "source_manifest_sha256": sha(artwork / "manifest.json"),
            "city_inventory": {"file": inventory.name, "sha256": sha(inventory)},
            "patches": [{"id": "control", "image": patch.name, "png_sha256": sha(patch),
                         "size": [8, 4], "source_crop": [0, 0, 8, 4], "world": [0, 0, 8, 4],
                         "edit_world": [2, 1, 4, 2], "feather": {"width": 1, "unit": "world",
                         "edges": ["left", "right", "top", "bottom"], "exterior_world": "opaque"}}]}
    return artwork, spec


@dataclass(frozen=True)
class ProbeExpectation:
    error: str | None = None
    occupied: bool = False


def probe(context, name, spec, expectation=ProbeExpectation()):
    binary, scratch, artwork = context
    expected, occupied = expectation.error, expectation.occupied
    manifest = scratch / f"{name}.json"
    write_json(manifest, spec)
    output = scratch / f"{name}-output"
    output.mkdir()
    if occupied:
        (output / "sentinel").write_bytes(b"preserve")
    before = {p.name: sha(p) for p in output.iterdir()}
    result = subprocess.run([str(binary), "--artwork-dir", str(artwork), "--patch-manifest", str(manifest),
                             "--output-dir", str(output)], capture_output=True, text=True, check=False)
    (scratch / f"{name}.log").write_text(result.stdout + result.stderr)
    if expected is not None:
        assert result.returncode != 0 and expected in result.stderr, (name, result.returncode, result.stderr)
        assert {p.name: sha(p) for p in output.iterdir()} == before, f"{name}: wrote rejected destination"
    else:
        assert result.returncode == 0, result.stderr
        receipt = json.loads((output / "composition-receipt.json").read_text())
        # The explicit 4x2 edit affects eight texels; the other 24 and city texel
        # remain exact. This checks fixture geometry, not the implementation formula.
        assert receipt["changed_texels"] == 8 and receipt["unchanged_outside_footprint_texels"] == 24
        assert receipt["unchanged_protected_texels"] == 1
        assert receipt["outside_footprints_exact"] and receipt["protected_bounds_exact"]
        assert not receipt["artistic_validation"] and not receipt["native_render_validation"]
        for region in receipt["regions"]:
            assert sha(output / region["file"]) == region["png_sha256"]
    return {"case": name, "exit_code": result.returncode, "passed": True}


def extended_cases(binary, scratch, artwork, spec):
    """Exact tiny-image expectations exercise sampling and protection boundaries."""
    results = []

    def check(name, candidate, expected):
        manifest = scratch / f"{name}.json"
        write_json(manifest, candidate)
        output = scratch / f"{name}-output"
        output.mkdir()
        result = subprocess.run([str(binary), "--artwork-dir", str(artwork),
                                 "--patch-manifest", str(manifest), "--output-dir", str(output)],
                                capture_output=True, text=True, check=False)
        (scratch / f"{name}.log").write_text(result.stdout + result.stderr)
        assert result.returncode == 0, (name, result.stderr)
        receipt = json.loads((output / "composition-receipt.json").read_text())
        for i, region in enumerate(receipt["regions"]):
            rgba = b"".join(bytes(expected[y*8+i*4+x]) for y in range(4) for x in range(4))
            assert region["rgba_sha256"] == hashlib.sha256(rgba).hexdigest(), (name, i, region)
        assert receipt["outside_footprints_exact"] and receipt["unapproved_protected_bounds_exact"]
        results.append({"case": name, "exit_code": 0, "passed": True})
        return receipt

    def patch_case(name, dimensions, pixels):
        path = scratch / f"{name}.png"
        png(path, *dimensions, b"".join(bytes(pixel) for pixel in pixels))
        candidate = copy.deepcopy(spec)
        candidate["patches"][0].update(image=path.name, png_sha256=sha(path), size=list(dimensions),
                                       source_crop=[0, 0, *dimensions], edit_world=[0, 0, 8, 4],
                                       sampling="area-v1")
        candidate["patches"][0]["feather"]["width"] = 0
        return candidate

    def reject(name, candidate, error):
        results.append(probe((binary, scratch, artwork), name, candidate, ProbeExpectation(error)))

    sampling_cases(check, patch_case)
    repaired = city_cases(check, patch_case, spec)
    rejection_cases(reject, repaired)
    return results


def sampling_cases(check, patch_case):
    # 3x3 checkerboard footprints contain four or five white pixels. The exact
    # averages round to113/142; sampling only the centre aliases to0/255.
    checker = [(255*((x+y) % 2),)*3+(255,) for y in range(12) for x in range(24)]
    candidate = patch_case("checker", (24, 12), checker)
    expected = [(113 if (x+y) % 2 == 0 else 142,)*3+(255,) for y in range(4) for x in range(8)]
    expected[0] = (255, 0, 0, 255)
    check("checker-area", candidate, expected)

    constant = [(25, 75, 125, 255)] * (24*12)
    expected = [(25, 75, 125, 255)] * 32
    expected[0] = (255, 0, 0, 255)
    check("constant-area", patch_case("constant", (24, 12), constant), expected)

    identity = [(x*20, y*40, 90, 255) for y in range(4) for x in range(8)]
    expected = identity.copy()
    expected[0] = (255, 0, 0, 255)
    check("identity-area", patch_case("identity", (8, 4), identity), expected)

    # Each destination contains one opaque green and two fully transparent red
    # columns. Green contributes85; the opaque backdrop contributes170.
    transparent = [(0, 255, 0, 255) if x % 3 == 0 else (255, 0, 0, 0) for y in range(12) for x in range(24)]
    expected = [(170, 85, 0, 255) if x < 4 else (0, 85, 170, 255) for y in range(4) for x in range(8)]
    expected[0] = (255, 0, 0, 255)
    check("alpha-area", patch_case("alpha", (24, 12), transparent), expected)

    fractional = [(255*(x % 2),)*3+(255,) for y in range(4) for x in range(20)]
    expected = [(102 if x % 4 < 2 else 153,)*3+(255,) for y in range(4) for x in range(8)]
    expected[0] = (255, 0, 0, 255)
    check("fractional-area", patch_case("fractional", (20, 4), fractional), expected)

    # Keep a strong sentinel outside the crop to detect reads past its boundary.
    cropped = [(255, 0, 255, 255) if x in (0, 21) or y in (0, 5)
               else (255*((x-1) % 2),)*3+(255,) for y in range(6) for x in range(22)]
    crop_spec = patch_case("crop", (22, 6), cropped)
    crop_spec["patches"][0]["source_crop"] = [1, 1, 20, 4]
    check("crop-area", crop_spec, expected)



def city_cases(check, patch_case, spec):
    repaired = patch_case("repair", (24, 12), [(25, 75, 125, 255)] * (24*12))
    repair = {"feature_index": 0, "city_source_index": 0, "city_name": "FIXTURE",
              "anchor": [0, 0], "reason": "Synthetic authorized city repair."}
    repaired["patches"][0]["city_repairs"] = [repair]
    receipt = check("authorized-city", repaired, [(25, 75, 125, 255)] * 32)
    assert receipt["repaired_city_texels"] == 1 and not receipt["protected_bounds_exact"]
    blocked = copy.deepcopy(repaired)
    blocked["protected_world"] = [{"id": "absolute", "world": [0, 0, 1, 1]}]
    expected = [(25, 75, 125, 255)] * 32
    expected[0] = (255, 0, 0, 255)
    receipt = check("explicit-protection-wins", blocked, expected)
    assert receipt["repaired_city_texels"] == 0 and receipt["protected_bounds_exact"]

    later = copy.deepcopy(repaired)
    second = copy.deepcopy(spec["patches"][0])
    second.update(id="later-unapproved", edit_world=[0, 0, 8, 4])
    second["feather"]["width"] = 0
    later["patches"].append(second)
    expected = [(0, 255, 0, 255)] * 32
    expected[0] = (25, 75, 125, 255)
    check("repair-not-inherited", later, expected)

    return repaired


def rejection_cases(reject, repaired):
    for name, key, value, error in (
        ("repair-bad-feature", "feature_index", 99, "Unknown/duplicate city repair"),
        ("repair-bad-source", "city_source_index", 1, "City repair identity mismatch"),
        ("repair-bad-name", "city_name", "WRONG", "City repair identity mismatch"),
        ("repair-bad-anchor", "anchor", [1, 0], "City repair identity mismatch"),
        ("repair-empty-reason", "reason", " ", "Empty city repair reason"),
    ):
        invalid = copy.deepcopy(repaired)
        invalid["patches"][0]["city_repairs"][0][key] = value
        reject(name, invalid, error)
    duplicate = copy.deepcopy(repaired)
    duplicate["patches"][0]["city_repairs"].append(copy.deepcopy(repaired["patches"][0]["city_repairs"][0]))
    reject("duplicate-repair", duplicate, "Unknown/duplicate city repair")
    unrelated = copy.deepcopy(repaired)
    unrelated["patches"][0]["edit_world"] = [2, 1, 4, 2]
    reject("unrelated-repair", unrelated, "City repair outside patch edit")
    bad_mode = copy.deepcopy(repaired)
    bad_mode["patches"][0]["sampling"] = "unknown"
    reject("unknown-sampling", bad_mode, "Unknown patch sampling")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--binary", required=True, type=Path)
    parser.add_argument("--scratch-dir", required=True, type=Path)
    args = parser.parse_args()
    assert args.binary.is_file() and args.scratch_dir.is_dir() and not any(args.scratch_dir.iterdir())
    artwork, spec = fixture(args.scratch_dir)
    originals = {p: sha(p) for p in artwork.iterdir()}
    results = [probe((args.binary.resolve(), args.scratch_dir, artwork), "positive", spec)]
    for name, field, value, error in (
        ("bad-source-hash", "source_manifest_sha256", "0"*64, "SHA256 mismatch"),
        ("bad-patch-hash", "png_sha256", "0"*64, "SHA256 mismatch"),
        ("crop-outside-png", "source_crop", [0, 0, 9, 4], "PNG dimensions/crop mismatch"),
        ("edit-outside-world", "edit_world", [7, 1, 4, 2], "Patch/edit outside source world"),
        ("parent-traversal", "image", "../patch.png", "Parent traversal"),
    ):
        invalid = copy.deepcopy(spec)
        (invalid if field == "source_manifest_sha256" else invalid["patches"][0])[field] = value
        results.append(probe((args.binary.resolve(), args.scratch_dir, artwork), name, invalid, ProbeExpectation(error)))
    results.append(probe((args.binary.resolve(), args.scratch_dir, artwork), "occupied-destination", spec,
                         ProbeExpectation("empty existing output directory", occupied=True)))
    results.extend(extended_cases(args.binary.resolve(), args.scratch_dir, artwork, spec))
    assert all(sha(path) == digest for path, digest in originals.items()), "Original resources changed"
    write_json(args.scratch_dir / "validation-results.json", results)
    print(f"world_join_compose validation: {len(results)} cases passed; originals unchanged")


if __name__ == "__main__":
    main()
