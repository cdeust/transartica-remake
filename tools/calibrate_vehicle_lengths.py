"""Measure sprite silhouettes without modifying image pixels.

Source: tasks/screen-length-contract.md, owner's constant screen-length rule.
"""
import argparse
import json
from pathlib import Path

import numpy as np
from PIL import Image


def measure(sheet, frame):
    x, y, width, height = frame["region"]
    ys, xs = np.nonzero(sheet[y:y + height, x:x + width, 3] >= 128)
    axis = np.array(frame["front"], dtype=float) - frame["rear"]
    axis /= np.linalg.norm(axis)
    projected = xs * axis[0] + ys * axis[1]
    # Include the support of each unit pixel square, rather than just its center.
    return float(projected.max() - projected.min() + np.abs(axis).sum())


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--write", action="store_true")
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[1]
    manifest = root / "game/assets/travel/vehicles.json"
    data = json.loads(manifest.read_text())
    lengths = {}
    for heading, atlas in data["headings"].items():
        sheet = np.array(Image.open(manifest.parent / atlas["file"]).convert("RGBA"))
        for kind, frame in atlas["vehicles"].items():
            length = measure(sheet, frame)
            lengths[heading, kind] = length
            if args.write:
                frame["visual_length"] = length
            elif abs(frame.get("visual_length", 0) - length) > 0.01:
                raise SystemExit(f"Stale silhouette measurement: {heading}/{kind}")
    if args.write:
        manifest.write_text(json.dumps(data, indent=2) + "\n")
    for kind in data["headings"]["6"]["vehicles"]:
        reference = lengths["6", kind]
        print(kind, "reference texels", round(reference, 3), "factors", {
            h: round(reference / lengths[h, kind], 4) for h in data["headings"]
        })
    print("PASS: 30 source silhouettes measured from PNG alpha; mirrors preserve extent")


if __name__ == "__main__":
    main()
