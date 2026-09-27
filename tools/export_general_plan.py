"""Export the original general-plan indices into ignored private runtime data.

Source: CARTE resource192/palette196, displayed by CARTE0x1ebe, documented in
tasks/evidence/map-orientation-audit.md. This is an exact historical dataset,
not authored replacement artwork; never copy its output into public bundles.
New extractor code is MIT, as required by the project.
"""

import hashlib
import json
from itertools import chain, groupby
from pathlib import Path

from claude.visuals.alisimg import Script

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "reference-private/unpacked/carte.alis"
OUTPUT = ROOT / "reference-private/general-plan.json"
IMAGE_RESOURCE = 192  # source: CARTE composite193, drawn at script0x1ebe.
PALETTE_RESOURCE = 196  # source: CARTE ctopalet at script0x1ef0.


def encode_row(row):
    """Serialize consecutive identical indices as [palette_index, run_length]."""
    return [[index, sum(1 for _ in pixels)] for index, pixels in groupby(row)]


def decode_row(row):
    return [index for index, length in row for _ in range(length)]


def build():
    script = Script(SOURCE)
    kind, width, height, pixels = script.pixels(IMAGE_RESOURCE)
    # Source measurements: opaque chunky image, original whole-plan canvas.
    if (kind, width, height) != (2, 320, 149):
        raise ValueError("CARTE resource192 no longer matches the verified plan")
    palette = [list(color) for color in script.palette(PALETTE_RESOURCE)]
    rows = [encode_row(row) for row in pixels]
    # Independently expand the encoding before publishing any derived data.
    restored = [decode_row(row) for row in rows]
    if restored != pixels or any(len(row) != width for row in restored):
        raise ValueError("General-plan encoding changed the original indices")
    if any(index < 0 or index >= len(palette) for row in restored for index in row):
        raise ValueError("General-plan index is outside its source palette")
    return {
        "version": 1,
        "width": width,
        "height": height,
        "palette": palette,
        "rows": rows,
        "source": {
            "script": "reference-private/unpacked/carte.alis",
            "sha256": hashlib.sha256(SOURCE.read_bytes()).hexdigest(),
            "image_resource": IMAGE_RESOURCE,
            "palette_resource": PALETTE_RESOURCE,
            "indices_sha256": hashlib.sha256(bytes(chain.from_iterable(pixels))).hexdigest(),
        },
    }


if __name__ == "__main__":
    data = build()
    OUTPUT.write_text(json.dumps(data, separators=(",", ":")) + "\n")
    print(f"Private general plan: {data['width']}x{data['height']}, "
          f"{sum(len(row) for row in data['rows'])} runs -> {OUTPUT}")
