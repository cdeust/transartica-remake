"""Build the travel-view overhead atlas from Codex's 25 wagon art masters.

Source: output/imagegen/wagon-catalogue-20260926/ (catalogue.json, prompts.json
and one 1024x1536 RGBA PNG per original wagon type 1-25). The owner chose on
2026-09-26 to draw every vehicle from this catalogue, the six initial ones
included, so the whole train shares one family of proportions (tasks/todo.md,
"Decision : train en vue de dessus"). Read-only on the sources; writes
game/assets/travel/vehicles-overhead.{png,json}.

Vehicles are keyed by original wagon type (catalogue "type_id"), never by file
order (the catalogue README's rule). The kind name is the prompts.json slug
without its "-combat" suffix; the drawings for types 17 and 23 keep the
prototype's dome and turret despite the historical names MERCHANDISE and
BARRACKS (catalogue README), a remake choice, not a decoded sprite.

Clean-up, measured on all 25 masters: every master has exactly one connected
alpha>=128 body, plus 900-6100 faint pixels (alpha <= 126) scattered up to the
canvas edges although the prompts forbade shadows and glow. Alpha is kept only
within HALO_SOURCE_PX of that body; everything farther is zeroed so it neither
renders as smudges nor inflates get_used_rect() (train_renderer.gd bounds).
Alpha tops out at 254 in the masters, as in the prototype atlas: kept as drawn.

Scale: ONE factor for all 25 (integer 1/SCALE box filter in premultiplied alpha,
so transparent RGB cannot bleed into edges). No per-vehicle width or length
normalization: the renderer's invariant is a single rigid texel scale, and the
masters' drawn widths genuinely differ (258-373 source px); that spread is a
property of the art, reported, not corrected here.

Anchors (unchanged convention, not decoded): every master faces down the
canvas; front = bottom-centre and rear = top-centre of the alpha>=128 box.
"""
import json
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage

REPO = Path(__file__).resolve().parent.parent
SOURCE_DIR = REPO / "output/imagegen/wagon-catalogue-20260926"
OUT_PNG = REPO / "game/assets/travel/vehicles-overhead.png"
OUT_JSON = REPO / "game/assets/travel/vehicles-overhead.json"
SCALE = 3  # 1488 source px of locomotive -> ~496 texels, the previous atlas density.
HALO_SOURCE_PX = 3  # keeps the drawn anti-aliased edge (~1 texel after scaling).
PADDING = 4  # transparent texels between atlas regions.
COLUMNS = 13


def clean_alpha(pixels: np.ndarray) -> np.ndarray:
    alpha = pixels[..., 3]
    labels, count = ndimage.label(alpha >= 128)
    assert count >= 1, "master has no solid body"
    sizes = np.bincount(labels.ravel())
    sizes[0] = 0
    body = labels == int(sizes.argmax())
    support = ndimage.binary_dilation(body, iterations=HALO_SOURCE_PX)
    cleaned = pixels.copy()
    cleaned[..., 3] = np.where(support, alpha, 0)
    return cleaned


def solid_box(alpha: np.ndarray) -> tuple[int, int, int, int]:
    rows = np.where((alpha >= 128).any(axis=1))[0]
    cols = np.where((alpha >= 128).any(axis=0))[0]
    return int(cols.min()), int(rows.min()), int(cols.max()), int(rows.max())


def downscale(pixels: np.ndarray) -> Image.Image:
    rows = np.where(pixels[..., 3].any(axis=1))[0]
    cols = np.where(pixels[..., 3].any(axis=0))[0]
    top, left = rows.min(), cols.min()
    # Pad the crop to whole SCALE blocks so the box filter averages exact blocks.
    height = -(-(rows.max() + 1 - top) // SCALE) * SCALE
    width = -(-(cols.max() + 1 - left) // SCALE) * SCALE
    crop = np.zeros((height, width, 4), dtype=np.uint8)
    source = pixels[top:top + height, left:left + width]
    crop[:source.shape[0], :source.shape[1]] = source
    image = Image.fromarray(crop, "RGBA").convert("RGBa")
    return image.resize((width // SCALE, height // SCALE), Image.Resampling.BOX).convert("RGBA")


def main() -> None:
    catalogue = json.loads((SOURCE_DIR / "catalogue.json").read_text())
    slugs = {entry["id"]: entry["slug"] for entry in json.loads((SOURCE_DIR / "prompts.json").read_text())}
    assets = sorted(catalogue["assets"], key=lambda asset: asset["type_id"])
    assert [asset["type_id"] for asset in assets] == list(range(1, 26)), "catalogue must cover types 1-25"
    tiles = []
    for asset in assets:
        pixels = np.asarray(Image.open(SOURCE_DIR / asset["file"]).convert("RGBA"))
        tile = downscale(clean_alpha(pixels))
        kind = slugs[asset["type_id"]].removesuffix("-combat")
        tiles.append((asset, kind, tile))
    cell_w = max(tile.width for _, _, tile in tiles) + PADDING
    cell_h = max(tile.height for _, _, tile in tiles) + PADDING
    rows = -(-len(tiles) // COLUMNS)
    sheet = Image.new("RGBA", (COLUMNS * cell_w + PADDING, rows * cell_h + PADDING), (0, 0, 0, 0))
    vehicles = {}
    for index, (asset, kind, tile) in enumerate(tiles):
        x = PADDING + (index % COLUMNS) * cell_w
        y = PADDING + (index // COLUMNS) * cell_h
        sheet.paste(tile, (x, y))
        left, top, right, bottom = solid_box(np.asarray(tile)[..., 3])
        vehicles[kind] = {
            "type_id": asset["type_id"],
            "name": asset["name"],
            "source": asset["file"],
            "region": [x, y, tile.width, tile.height],
            "front": [(left + right) / 2.0, float(bottom)],
            "rear": [(left + right) / 2.0, float(top)],
            "alpha_span": bottom - top + 1,
            "solid_width": right - left + 1,
        }
    reference = vehicles["locomotive"]["alpha_span"]
    for kind, entry in vehicles.items():
        entry["length"] = round(entry["alpha_span"] / reference, 2)
        print(f"{entry['type_id']:2d} {kind:18s} span={entry['alpha_span']} width={entry['solid_width']} length={entry['length']}")
    manifest = {
        "version": 2,
        "source": "output/imagegen/wagon-catalogue-20260926 (Codex art masters, types 1-25; owner choice 2026-09-26)",
        "note": "Single rigid top-down drawing per original wagon type, rotated continuously to the projected "
                "travel direction. front=bottom-centre, rear=top-centre (tools/build_overhead_atlas.py). "
                "length = alpha_span / locomotive alpha_span, a drawn proportion, not a historical rule.",
        "file": "vehicles-overhead.png",
        "scale": f"1/{SCALE}",
        "vehicles": vehicles,
    }
    OUT_JSON.write_text(json.dumps(manifest, indent=1) + "\n")
    sheet.save(OUT_PNG, optimize=True)
    print(f"wrote {OUT_JSON} and {OUT_PNG} {sheet.size}")
    print("TYPE_TO_KIND := {" + ", ".join(f'{v["type_id"]}: "{k}"' for k, v in vehicles.items()) + "}")
    print("LENGTHS := {" + ", ".join(f'"{k}": {v["length"]}' for k, v in vehicles.items()) + "}")


if __name__ == "__main__":
    main()
