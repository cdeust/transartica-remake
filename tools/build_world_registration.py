#!/usr/bin/env python3
"""MIT. Reproduce Claude6Oct measure_regions.py using Pillow12.3.0/NumPy2.5.3.

The private guide chooses the existing percentile; output contains only artwork
dark masks and artwork pixel hashes, never decoded source classes or coordinates.
This classifier establishes coarse relief placement, not forest/rock semantics.
"""
import argparse
import hashlib
import json
from pathlib import Path

import numpy as np
from PIL import Image

# source: artwork-geography-guide legend, reproduced in Claude6Oct measurement.
PALETTE = {"snow": (214, 226, 230), "forest": (45, 75, 82),
           "mount": (96, 112, 124), "water": (70, 115, 135),
           "city": (180, 155, 120)}


def guide_classes(path):
    guide = np.asarray(Image.open(path).convert("RGB").resize((160, 73), Image.Resampling.NEAREST), int)
    colors = np.array(list(PALETTE.values()))
    closest = ((guide[:, :, None, :] - colors[None, None]) ** 2).sum(-1).argmin(-1)
    return np.array(list(PALETTE))[closest]


def correlation(a, b):
    a, b = a - a.mean(), b - b.mean()
    denominator = np.sqrt((a * a).sum() * (b * b).sum())
    return float((a * b).sum() / denominator) if denominator else 0.0


def measure(index, tile_path, master, guide):
    tile = Image.open(tile_path).convert("RGBA")
    column, row = index % 4, index // 4  # source: owner's four-column/two-row grid.
    width, height = master.size
    crop = master.crop((int(column * width / 4), int(row * height / 2),
                        int((column + 1) * width / 4), int((row + 1) * height / 2)))
    crop = np.asarray(crop.resize((320, 292)), float)  # source: Claude6Oct correlation grid.
    gray = tile.convert("L")
    x0, y0, y1 = column * 40, int(row * 36.5), int((row + 1) * 36.5)  # source: Claude6Oct integer measurement crop.
    classes = guide[y0:y1, x0:x0 + 40]
    relief = (classes == "forest") | (classes == "mount")
    sample = np.asarray(gray.resize((40, y1 - y0), Image.Resampling.BOX), float)
    threshold = float(np.percentile(sample, 100 * relief.mean()))  # source: Claude6Oct equal-density darkness classifier.
    dark = sample < threshold
    iou = float((dark & relief).sum() / max(1, (dark | relief).sum()))
    chance = float(relief.mean() / (2 - relief.mean()))  # source: Claude6Oct equal-density random intersection diagnostic.
    entry = {"index": index, "size": list(tile.size), "rgba_sha256": hashlib.sha256(tile.tobytes()).hexdigest(),
             "grid_size": [40, y1 - y0], "dark_mask": "".join("1" if value else "0" for value in dark.flat),
             "threshold": threshold, "corr_master": correlation(np.asarray(gray.resize((320, 292)), float), crop),  # source: Claude6Oct correlation grid.
             "relief_iou": iou, "chance": chance}
    print(f"region{index}: corr={entry['corr_master']:.3f} relief_iou={iou:.3f} chance={chance:.3f}")
    return entry


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ("guide", "master", "regions", "output"):
        parser.add_argument(f"--{name}", required=True, type=Path)
    args = parser.parse_args()
    guide = guide_classes(args.guide)
    master = Image.open(args.master).convert("L")
    entries = [measure(index, args.regions / f"world-region-{index}.png", master, guide) for index in range(8)]
    # source: supplied Claude6Oct measurement criterion, correlation>=0.5 and IoU above chance.
    if any(entry["corr_master"] < 0.5 or entry["relief_iou"] <= entry["chance"] for entry in entries):
        raise ValueError("Regional registration criterion failed; no manifest written")
    document = {"schema": 1, "method": "Claude6Oct grayscale BOX/percentile coarse relief", "regions": entries}
    args.output.write_text(json.dumps(document, indent=2) + "\n")


if __name__ == "__main__":
    main()
