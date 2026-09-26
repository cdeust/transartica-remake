"""Read-only atlas measurements; does not normalize artwork or certify its quality.

Source: tasks/checkpoint-codex-2026-09-26.md requires both visible dimensions.
Measurement convention extends calibrate_vehicle_lengths.py: project solid pixel
squares onto the authored coupling axis and its perpendicular. Report raw drift,
without an invented acceptance tolerance. MIT, diagnostic project tooling.
"""
import argparse
import hashlib
import json
from pathlib import Path

import numpy as np
from PIL import Image


def dimensions(pixels: np.ndarray, axis: np.ndarray) -> tuple[float, float]:
    """Return longitudinal and transverse extents of half-covered pixel squares."""
    # Same alpha convention as tools/calibrate_vehicle_lengths.py.
    ys, xs = np.nonzero(pixels[..., 3] >= 128)
    if not len(xs) or np.linalg.norm(axis) == 0:
        raise ValueError("Empty silhouette or coincident coupling anchors")
    along = axis / np.linalg.norm(axis)
    across = np.array([-along[1], along[0]])
    # Each unit pixel square projects to a segment of width |ux| + |uy|.
    extents = []
    for direction in (along, across):
        projection = xs * direction[0] + ys * direction[1]
        extents.append(float(np.ptp(projection) + np.abs(direction).sum()))
    return extents[0], extents[1]


def audit(manifest: Path) -> dict:
    data = json.loads(manifest.read_text())
    rows = []
    for heading, sheet in data["headings"].items():
        path = manifest.parent / sheet["file"]
        pixels = np.asarray(Image.open(path).convert("RGBA"))
        digest = hashlib.sha256(path.read_bytes()).hexdigest()
        for kind, frame in sheet["vehicles"].items():
            x, y, width, height = frame["region"]
            axis = np.subtract(frame["front"], frame["rear"])
            length, breadth = dimensions(pixels[y:y + height, x:x + width], axis)
            rows.append(dict(heading=heading, kind=kind, file=sheet["file"],
                             sha256=digest, length=length, width=breadth))
    # Source: train_renderer.gd REFERENCE_HEADING = 6 (accepted east artwork).
    reference = {row["kind"]: row for row in rows if row["heading"] == "6"}
    for row in rows:
        baseline = reference[row["kind"]]
        row["length_ratio_to_east"] = row["length"] / baseline["length"]
        row["width_ratio_to_east"] = row["width"] / baseline["width"]
    return dict(units="atlas texels at common scale", alpha_min=128,
                scope="source drawings; horizontal mirrors preserve dimensions",
                verdict="measurement only, no artistic acceptance", measurements=rows)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    root = Path(__file__).resolve().parents[1]
    parser.add_argument("--manifest", type=Path,
                        default=root / "game/assets/travel/vehicles.json")
    parser.add_argument("--report", type=Path)
    args = parser.parse_args()
    report = audit(args.manifest)
    if args.report:
        args.report.write_text(json.dumps(report, indent=2) + "\n")
    for row in report["measurements"]:
        print(f"{row['heading']:>2} {row['kind']:<12} "
              f"{row['length']:.1f} x {row['width']:.1f}; ratios E "
              f"{row['length_ratio_to_east']:.3f} x {row['width_ratio_to_east']:.3f}")


if __name__ == "__main__":
    main()
