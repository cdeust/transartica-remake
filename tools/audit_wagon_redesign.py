"""Measure source PNGs without modifying them. Source: tasks/wagon-redesign.md."""

import hashlib
import json
from pathlib import Path
from statistics import median

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
OLD = ROOT / "output/imagegen/wagon-catalogue-20260926"
NEW = ROOT / "output/imagegen/wagon-redesign-20260926"
INITIAL = {1, 2, 3, 17, 21, 23}  # source: game/scripts/train_wagons.gd::INITIAL
SOLID_ALPHA = 128  # source: tools/build_overhead_atlas.py::solid_box


def measure(path):
    with Image.open(path) as image:
        image.load()
        assert image.mode == "RGBA" and image.size == (1024, 1536), path
        alpha = image.getchannel("A")
        solid = alpha.point(lambda value: 255 if value >= SOLID_ALPHA else 0)
        left, top, right, bottom = solid.getbbox()
        # The middle half excludes end couplers while sampling both roof and rails.
        start = top + (bottom - top) // 4
        end = bottom - (bottom - top) // 4
        widths = []
        for row in range(start, end):
            box = solid.crop((0, row, image.width, row + 1)).getbbox()
            assert box is not None, (path, row)
            widths.append(box[2] - box[0])
        corners = [(0, 0), (1023, 0), (0, 1535), (1023, 1535)]
        corner_alpha = [alpha.getpixel(point) for point in corners]
        return {
            "sha256": hashlib.sha256(path.read_bytes()).hexdigest(),
            "bytes": path.stat().st_size,
            "solid_bbox": [left, top, right, bottom],
            "solid_width": right - left,
            "solid_length": bottom - top,
            "middle_half_median_width": median(widths),
            "corner_alpha": corner_alpha,
            "transparent_corners": all(value == 0 for value in corner_alpha),
        }


def main():
    assets = json.loads((OLD / "catalogue.json").read_text())["assets"]
    before = {a["type_id"]: measure(OLD / a["file"]) for a in assets}
    reference_widths = [before[i]["solid_width"] for i in INITIAL]
    reference_lengths = [before[i]["solid_length"] for i in INITIAL]
    report = {
        "alpha_threshold": SOLID_ALPHA,
        "reference_ids": sorted(INITIAL),
        "reference_width_range": [min(reference_widths), max(reference_widths)],
        "reference_length_range": [min(reference_lengths), max(reference_lengths)],
        "assets": [],
    }
    for asset in assets:
        type_id = asset["type_id"]
        path = OLD / asset["file"] if type_id in INITIAL else NEW / asset["file"]
        after = measure(path)
        assert min(reference_widths) <= after["solid_width"] <= max(reference_widths), (
            path
        )
        assert (
            min(reference_lengths) <= after["solid_length"] <= max(reference_lengths)
        ), path
        report["assets"].append(
            {
                "type_id": type_id,
                "name": asset["name"],
                "file": str(path.relative_to(ROOT)),
                "redesigned": type_id not in INITIAL,
                "before": before[type_id],
                "after": after,
            }
        )
    print(json.dumps(report, indent=2))


if __name__ == "__main__":
    main()
