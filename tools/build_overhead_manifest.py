"""Build game/assets/travel/vehicles-overhead.json from the Codex overhead prototype.

Source: output/imagegen/vehicles-overhead-prototype-v2.{png,json}, the art the
owner accepted on 2026-09-26 (tasks/todo.md, "Decision : train en vue de
dessus"). Read-only on the source atlas; writes only the derived manifest and
the copied sheet PNG under game/assets/travel/.

Anchor convention (owner-facing limitation, not decoded from any original
data): every vehicle in this atlas is drawn nose-down. The locomotive's
cowcatcher, the tender's coupling ladder, the observation dome and the
armored car's cannon all sit at the BOTTOM edge of their region; the coupling
end that faces the rest of the consist (cab, coal bin, doorway) sits at the
TOP. "front" is defined as bottom-centre of the region, "rear" as top-centre,
for every vehicle uniformly. This has not been checked against any source for
which way an observation dome or a cannon should face in the original game;
tasks/lessons.md already flags this as open ("valider aussi le sens physique
des extremites asymetriques"). Treat front/rear here as a rendering axis, not
a fidelity claim.

Length measurement: alpha >= 128 bounding box within each region (same
convention as tools/audit_vehicle_dimensions.py). Measured, printed below:
every vehicle's alpha bbox spans close to the full region height (482-506px
of a ~485-506px region) even though the generation prompt asked for
differentiated lengths (460/345/354/359/405/368px, tasks/todo.md still lists
this as unresolved). The manifest therefore encodes near-uniform LENGTHS
ratios (0.95-1.0), not the prompt's target ratios: that is what the delivered
art actually shows, and inventing a different ratio the pixels do not
contain would be a fabricated rule. Flagged in tasks/todo.md as art to redo.
"""
import json
from pathlib import Path

import numpy as np
from PIL import Image

REPO = Path(__file__).resolve().parent.parent
SOURCE_PNG = REPO / "output/imagegen/vehicles-overhead-prototype-v2.png"
SOURCE_JSON = REPO / "output/imagegen/vehicles-overhead-prototype-v2.json"
OUT_PNG = REPO / "game/assets/travel/vehicles-overhead.png"
OUT_JSON = REPO / "game/assets/travel/vehicles-overhead.json"


def alpha_span(pixels: np.ndarray, region: list[int]) -> tuple[int, int, int, int]:
    x, y, w, h = region
    sub = pixels[y:y + h, x:x + w, 3]
    rows = np.where((sub >= 128).any(axis=1))[0]
    cols = np.where((sub >= 128).any(axis=0))[0]
    top, bottom = int(rows.min()), int(rows.max())
    left, right = int(cols.min()), int(cols.max())
    return left, top, right, bottom


def main() -> None:
    entries = json.loads(SOURCE_JSON.read_text())
    pixels = np.asarray(Image.open(SOURCE_PNG).convert("RGBA"))
    vehicles = {}
    for entry in entries:
        kind = entry["kind"]
        region = entry["region"]
        left, top, right, bottom = alpha_span(pixels, region)
        span = bottom - top + 1
        print(f"{kind}: region_h={region[3]} alpha_span_h={span}")
        # Front/rear in region-relative pixel coordinates (train_renderer.gd
        # subtracts region.position to keep atlas-frame anchors local, same
        # convention as the pre-existing vehicles.json).
        front = [(left + right) / 2.0, float(bottom)]
        rear = [(left + right) / 2.0, float(top)]
        vehicles[kind] = {"region": region, "front": front, "rear": rear, "alpha_span": span}
    manifest = {
        "version": 1,
        "source": "output/imagegen/vehicles-overhead-prototype-v2.png,"
                   "vehicles-overhead-prototype-v2.json (owner-accepted overhead prototype, 2026-09-26)",
        "note": "Single rigid top-down drawing per vehicle; rotated continuously to the "
                "projected travel direction, never swapped or mirrored per heading. "
                "front=bottom-centre, rear=top-centre of each region (see module docstring).",
        "file": "vehicles-overhead.png",
        "vehicles": vehicles,
    }
    OUT_JSON.write_text(json.dumps(manifest, indent=1) + "\n")
    OUT_PNG.write_bytes(SOURCE_PNG.read_bytes())
    print(f"wrote {OUT_JSON}")
    print(f"wrote {OUT_PNG}")


if __name__ == "__main__":
    main()
