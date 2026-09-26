#!/usr/bin/env python3
"""Normalise generated train sprites for the oblique travel scene.

Generated illustrations (image_gen) have soft alpha, no uniform pixel grid,
per-image palettes and a scale that depends on the canvas. This tool turns
each heading into a game-ready sprite that shares scale, palette and anchor
conventions with game/assets/travel/train-east.png, validates it against the
screen direction required by the travel projection, and writes a manifest
that TravelWorldView can read instead of rotating one sprite.

Run with the project-local Pillow/numpy environment (caches stay in .cache):
  UV_CACHE_DIR=$PWD/.cache/uv uv run -q --no-project --with pillow --with numpy \
      python tools/sprite_pipeline.py --help

MIT licence, new code of this project. Nothing here encodes an original rule.
"""
from __future__ import annotations

import argparse
import json
import math
import sys
from dataclasses import dataclass, asdict
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

# source: game/scripts/travel_world.gd WORLD_EAST / WORLD_SOUTH (authored projection).
WORLD_EAST = np.array([180.0, 100.0])
WORLD_SOUTH = np.array([-180.0, 100.0])
# source: game/scripts/rail_network.gd DELTAS (numeric-keypad headings).
DELTAS = {1: (-1, 1), 2: (0, 1), 3: (1, 1), 4: (-1, 0), 6: (1, 0), 7: (-1, -1), 8: (0, -1), 9: (1, -1)}
NAMES = {1: "SW", 2: "S", 3: "SE", 4: "W", 6: "E", 7: "NW", 8: "N", 9: "NE"}
# source: file names announced in output/imagegen/travel-train-headings-prompt.md.
FILE_NAMES = {1: "southwest", 2: "south", 3: "southeast", 4: "west", 6: "east", 7: "northwest", 8: "north", 9: "northeast"}
# source: output/imagegen/travel-train-headings-prompt.md, horizontal mirror pairs.
MIRROR_OF = {2: 6, 8: 4, 1: 9}
REFERENCE_HEADING = 6
ALPHA_THRESHOLD = 128  # authored: generated alpha above half coverage counts as solid.
ANGLE_TOLERANCE = math.radians(4.0)  # authored: rails are drawn on the exact axis.
LENGTH_TOLERANCE = 0.15  # authored: generated cars vary; beyond this the train visibly changes size.
THICKNESS_WARNING = 0.25  # authored heuristic: body thickness far from the reference after rescale
# usually means the generator ignored foreshortening (full-length SE/NW convoy shrunk to fit).
CONTOUR_BINS = 96  # authored: enough samples to ignore a single protruding coupler.
WHEEL_BAND = 0.06  # authored: fraction of convoy thickness counted as touching the wheel line.
MARGIN = 8  # authored: transparent border kept around the trimmed sprite.


def screen_direction(heading: int) -> np.ndarray:
    dx, dy = DELTAS[heading]
    return WORLD_EAST * dx + WORLD_SOUTH * dy


def expected_angle(heading: int) -> float:
    v = screen_direction(heading)
    return math.atan2(v[1], v[0])


def length_ratio(heading: int) -> float:
    """Screen length of one world unit along heading, relative to east."""
    dx, dy = DELTAS[heading]
    per_unit = np.linalg.norm(screen_direction(heading)) / math.hypot(dx, dy)
    return per_unit / np.linalg.norm(screen_direction(REFERENCE_HEADING))


def load_rgba(path: Path) -> np.ndarray:
    return np.asarray(Image.open(path).convert("RGBA")).copy()


def harden_alpha(rgba: np.ndarray, threshold: int = ALPHA_THRESHOLD) -> np.ndarray:
    out = rgba.copy()
    solid = out[..., 3] >= threshold
    out[..., 3] = np.where(solid, 255, 0)
    out[~solid, :3] = 0
    return out


@dataclass
class Axis:
    angle: float  # radians, oriented towards the locomotive (expected heading).
    nose: tuple[float, float]  # texel where the wheel line leaves the silhouette, front.
    tail: tuple[float, float]  # texel where the wheel line leaves the silhouette, rear.
    length: float  # silhouette extent along the axis, in texels.
    thickness: float = 0.0  # silhouette extent across the axis, in texels.


def measure_axis(rgba: np.ndarray, heading: int) -> Axis:
    """Principal axis of the silhouette, refined on its wheel contour.

    The wheel line is the lower contour when the axis is mostly horizontal on
    screen, and the centreline when the convoy runs towards or away from the
    viewer (vertical axis): there, rails lie under the middle of every car.
    """
    ys, xs = np.nonzero(rgba[..., 3] >= ALPHA_THRESHOLD)
    if xs.size < 64:
        raise ValueError("sprite has no opaque silhouette")
    pts = np.stack([xs, ys], 1).astype(float)
    centre = pts.mean(0)
    _, vectors = np.linalg.eigh(np.cov((pts - centre).T))
    direction = vectors[:, 1]
    wanted = screen_direction(heading)
    if direction @ wanted < 0:
        direction = -direction
    normal = np.array([-direction[1], direction[0]])
    if normal[1] < 0:
        normal = -normal
    t = (pts - centre) @ direction
    p = (pts - centre) @ normal
    use_bottom = abs(normal[1]) >= 0.5
    edges = np.linspace(t.min(), t.max(), CONTOUR_BINS + 1)
    which = np.clip(np.digitize(t, edges) - 1, 0, CONTOUR_BINS - 1)
    sample_t, sample_p = [], []
    for index in range(CONTOUR_BINS):
        mask = which == index
        if mask.sum() < 8:
            continue
        sample_t.append(t[mask].mean())
        sample_p.append(p[mask].max() if use_bottom else np.median(p[mask]))
    sample_t, sample_p = np.array(sample_t), np.array(sample_p)
    # Trimmed least squares: drop the worst quarter (couplers, cow-catcher, turret).
    keep = np.ones(sample_t.size, bool)
    for _ in range(2):
        slope, offset = np.polyfit(sample_t[keep], sample_p[keep], 1)
        residual = np.abs(sample_p - (slope * sample_t + offset))
        keep = residual <= np.percentile(residual, 75)
    slope, offset = np.polyfit(sample_t[keep], sample_p[keep], 1)
    tilt = math.atan(slope)
    axis_dir = direction * math.cos(tilt) + normal * math.sin(tilt)
    axis_dir /= np.linalg.norm(axis_dir)
    origin = centre + normal * offset
    axis_normal = np.array([-axis_dir[1], axis_dir[0]])
    along = (pts - origin) @ axis_dir
    across = (pts - origin) @ axis_normal
    # Anchors are where the silhouette itself touches the wheel line, so they stay
    # on opaque texels even when the cow-catcher or a gun overhangs the axis.
    band = max(3.0, WHEEL_BAND * (across.max() - across.min()))
    near = np.abs(across) <= band
    if near.sum() < 2:
        near = np.ones_like(near)
    touching, touching_pts = along[near], pts[near]
    # Mean of the opaque texels at each extremity: never a point outside the sprite.
    nose = touching_pts[touching >= touching.max() - 2].mean(0)
    tail = touching_pts[touching <= touching.min() + 2].mean(0)
    return Axis(
        angle=math.atan2(axis_dir[1], axis_dir[0]),
        nose=(round(float(nose[0]), 1), round(float(nose[1]), 1)),
        tail=(round(float(tail[0]), 1), round(float(tail[1]), 1)),
        length=round(float(along.max() - along.min()), 1),
        thickness=round(float(across.max() - across.min()), 1),
    )


def angle_error(measured: float, heading: int) -> float:
    return abs(math.remainder(measured - expected_angle(heading), 2 * math.pi))


def validate(rgba: np.ndarray, heading: int, axis: Axis, reference_length: float | None) -> list[str]:
    problems = []
    alpha = rgba[..., 3]
    corners = [alpha[0, 0], alpha[0, -1], alpha[-1, 0], alpha[-1, -1]]
    if max(corners) >= ALPHA_THRESHOLD or (alpha == 0).mean() < 0.3:
        problems.append("background is not transparent (opaque corners or <30% clear pixels)")
    error = angle_error(axis.angle, heading)
    if error > ANGLE_TOLERANCE:
        problems.append(
            f"axis {math.degrees(axis.angle):.1f} deg, expected {math.degrees(expected_angle(heading)):.1f} deg "
            f"for {NAMES[heading]} (error {math.degrees(error):.1f} deg)"
        )
    if reference_length:
        wanted = reference_length * length_ratio(heading)
        drift = abs(axis.length / wanted - 1.0)
        if drift > LENGTH_TOLERANCE:
            problems.append(f"length {axis.length:.0f}px, expected {wanted:.0f}px at reference scale ({drift:.0%} off)")
    return problems


def trim(rgba: np.ndarray, margin: int = MARGIN) -> tuple[np.ndarray, tuple[int, int]]:
    ys, xs = np.nonzero(rgba[..., 3])
    x0, y0 = max(int(xs.min()) - margin, 0), max(int(ys.min()) - margin, 0)
    x1, y1 = int(xs.max()) + margin + 1, int(ys.max()) + margin + 1
    pad = np.zeros((y1 - y0, x1 - x0, 4), np.uint8)
    view = rgba[y0:y1, x0:x1]
    pad[: view.shape[0], : view.shape[1]] = view
    return pad, (x0, y0)


def rescale(rgba: np.ndarray, factor: float) -> np.ndarray:
    if abs(factor - 1.0) < 1e-3:
        return rgba
    height, width = rgba.shape[:2]
    size = (max(1, round(width * factor)), max(1, round(height * factor)))
    premultiplied = rgba.astype(float)
    premultiplied[..., :3] *= premultiplied[..., 3:4] / 255.0
    image = Image.fromarray(premultiplied.clip(0, 255).astype(np.uint8), "RGBA").resize(size, Image.Resampling.LANCZOS)
    out = np.asarray(image).astype(float)
    alpha = out[..., 3:4]
    out[..., :3] = np.where(alpha > 0, out[..., :3] * 255.0 / np.maximum(alpha, 1), 0)
    return out.clip(0, 255).astype(np.uint8)


def pixelize(rgba: np.ndarray, cell: int) -> np.ndarray:
    """Impose a uniform cell x cell grid: majority alpha, mean colour of solid texels."""
    if cell <= 1:
        return rgba
    height, width = rgba.shape[:2]
    h, w = -(-height // cell) * cell, -(-width // cell) * cell
    padded = np.zeros((h, w, 4), np.uint8)
    padded[:height, :width] = rgba
    blocks = padded.reshape(h // cell, cell, w // cell, cell, 4).transpose(0, 2, 1, 3, 4).reshape(h // cell, w // cell, -1, 4)
    solid = blocks[..., 3] >= ALPHA_THRESHOLD
    count = solid.sum(-1)
    colour = (blocks[..., :3].astype(float) * solid[..., None]).sum(-2) / np.maximum(count, 1)[..., None]
    small = np.zeros((h // cell, w // cell, 4), np.uint8)
    small[..., :3] = colour.round().astype(np.uint8)
    small[..., 3] = np.where(count * 2 >= cell * cell, 255, 0)
    big = small.repeat(cell, 0).repeat(cell, 1)
    return big[:height, :width]


def extract_palette(rgba: np.ndarray, colours: int) -> list[str]:
    solid = rgba[rgba[..., 3] >= ALPHA_THRESHOLD][:, :3]
    strip = Image.fromarray(solid.reshape(1, -1, 3), "RGB")
    quantised = strip.quantize(colours, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE)
    flat = quantised.getpalette()[: colours * 3]
    used = sorted(set(np.asarray(quantised).ravel().tolist()))
    return ["#%02x%02x%02x" % tuple(flat[i * 3 : i * 3 + 3]) for i in used]


def apply_palette(rgba: np.ndarray, palette: list[str]) -> np.ndarray:
    table = np.array([[int(h[i : i + 2], 16) for i in (1, 3, 5)] for h in palette], float)
    out = rgba.copy()
    solid = out[..., 3] >= ALPHA_THRESHOLD
    pixels = out[solid][:, :3].astype(float)
    # Nearest colour in a luminance-weighted RGB space keeps dark steel ramps apart.
    weights = np.array([0.30, 0.59, 0.11]) ** 0.5
    nearest = np.empty(len(pixels), int)
    for start in range(0, len(pixels), 65536):
        chunk = pixels[start : start + 65536]
        distance = (((chunk[:, None, :] - table[None, :, :]) * weights) ** 2).sum(-1)
        nearest[start : start + 65536] = distance.argmin(1)
    out[solid, :3] = table[nearest].astype(np.uint8)
    return out


def mirror_axis(axis: Axis, width: int) -> Axis:
    flip = lambda point: (round(width - 1 - point[0], 1), point[1])
    return Axis(math.atan2(math.sin(axis.angle), -math.cos(axis.angle)), flip(axis.nose), flip(axis.tail), axis.length,
                axis.thickness)


def thickness_warning(axis: Axis, reference_thickness: float | None) -> list[str]:
    if not reference_thickness:
        return []
    drift = axis.thickness / reference_thickness - 1.0
    if abs(drift) <= THICKNESS_WARNING:
        return []
    return [f"warning: body thickness {axis.thickness:.0f}px vs reference {reference_thickness:.0f}px ({drift:+.0%}); "
            "check foreshortening on the contact sheet"]


def process(source: Path, heading: int, out: Path, reference_length: float | None, palette: list[str] | None, cell: int,
            reference_thickness: float | None = None) -> dict:
    rgba = harden_alpha(load_rgba(source))
    raw_axis = measure_axis(rgba, heading)
    problems = validate(rgba, heading, raw_axis, None)
    factor = 1.0
    if reference_length:
        factor = reference_length * length_ratio(heading) / raw_axis.length
        rgba = harden_alpha(rescale(rgba, factor))
    rgba, _ = trim(rgba)
    rgba = pixelize(rgba, cell)
    if palette:
        rgba = apply_palette(rgba, palette)
    axis = measure_axis(rgba, heading)
    problems += [p for p in validate(rgba, heading, axis, reference_length) if "transparent" not in p]
    out.parent.mkdir(parents=True, exist_ok=True)
    Image.fromarray(rgba, "RGBA").save(out)
    return {"heading": heading, "name": NAMES[heading], "source": str(source), "file": out.name,
            "size": [rgba.shape[1], rgba.shape[0]], "scale_applied": round(factor, 4), "cell": cell,
            "axis": asdict(axis), "problems": problems, "warnings": thickness_warning(axis, reference_thickness)}


def build_manifest(entries: list[dict]) -> dict:
    by_heading = {e["heading"]: e for e in entries}
    headings = {}
    for heading in sorted(DELTAS):
        if heading in by_heading:
            e = by_heading[heading]
            headings[str(heading)] = {"name": NAMES[heading], "file": e["file"], "mirrored": False,
                                      "size": e["size"], **e["axis"]}
        elif heading in MIRROR_OF and MIRROR_OF[heading] in by_heading:
            e = by_heading[MIRROR_OF[heading]]
            axis = mirror_axis(Axis(**e["axis"]), e["size"][0])
            headings[str(heading)] = {"name": NAMES[heading], "file": e["file"], "mirrored": True,
                                      "size": e["size"], **asdict(axis),
                                      "source_nose": e["axis"]["nose"], "source_tail": e["axis"]["tail"]}
    missing = [NAMES[h] for h in sorted(DELTAS) if str(h) not in headings]
    return {"generator": "tools/sprite_pipeline.py",
            "anchor_convention": "nose/tail/angle are texels of the image as displayed (after the horizontal "
                                 "mirror when mirrored=true); source_nose/source_tail are the unflipped texels "
                                 "to use with draw_set_transform(scale.x = -1)",
            "headings": headings, "missing": missing}


def contact_sheet(entries: list[dict], folder: Path, out: Path) -> None:
    thumbs = []
    for e in entries:
        image = Image.open(folder / e["file"]).convert("RGBA")
        backdrop = Image.new("RGBA", image.size, (46, 62, 72, 255))
        backdrop.alpha_composite(image)
        draw = ImageDraw.Draw(backdrop)
        draw.line([tuple(e["axis"]["tail"]), tuple(e["axis"]["nose"])], fill=(232, 196, 106, 255), width=3)
        for point, colour in ((e["axis"]["nose"], (90, 230, 120, 255)), (e["axis"]["tail"], (230, 90, 90, 255))):
            draw.ellipse([point[0] - 9, point[1] - 9, point[0] + 9, point[1] + 9], outline=colour, width=4)
        status = 'OK' if not e['problems'] else 'CHECK: ' + '; '.join(e['problems'])
        draw.text((12, 12), f"{e['name']}  {status}", fill=(255, 255, 255, 255))
        for line, warning in enumerate(e.get("warnings", [])):
            draw.text((12, 30 + 18 * line), warning, fill=(255, 210, 120, 255))
        backdrop.thumbnail((720, 720))
        thumbs.append(backdrop)
    width = sum(t.width for t in thumbs) + 16 * (len(thumbs) + 1)
    height = max(t.height for t in thumbs) + 32
    sheet = Image.new("RGBA", (width, height), (20, 26, 30, 255))
    x = 16
    for thumb in thumbs:
        sheet.alpha_composite(thumb, (x, 16))
        x += thumb.width + 16
    sheet.save(out)


def parse_job(text: str) -> tuple[int, Path]:
    heading, _, path = text.partition("=")
    key = {v: k for k, v in NAMES.items()}.get(heading.upper(), None)
    if key is None:
        raise argparse.ArgumentTypeError(f"unknown heading {heading!r}; use one of {sorted(NAMES.values())}")
    return key, Path(path)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    parser.add_argument("jobs", nargs="+", type=parse_job, help="HEADING=path.png, e.g. E=train-east.png W=train-west.png")
    parser.add_argument("--out", type=Path, required=True, help="output folder for sprites, manifest and sheet")
    parser.add_argument("--reference", type=Path, help="sprite fixing scale and palette (defaults to the E job)")
    parser.add_argument("--cell", type=int, default=1, help="uniform pixel-grid size in texels (1 keeps resolution)")
    parser.add_argument("--colours", type=int, default=0, help="shared palette size extracted from the reference (0 = off)")
    parser.add_argument("--check-only", action="store_true", help="measure and validate, write nothing")
    args = parser.parse_args(argv)
    jobs = dict(args.jobs)
    reference_path = args.reference or jobs.get(REFERENCE_HEADING)
    reference = harden_alpha(load_rgba(reference_path)) if reference_path else None
    reference_axis = measure_axis(reference, REFERENCE_HEADING) if reference is not None else None
    reference_length = reference_axis.length if reference_axis else None
    reference_thickness = reference_axis.thickness if reference_axis else None
    if args.check_only:
        failed = False
        for heading, path in jobs.items():
            rgba = harden_alpha(load_rgba(path))
            axis = measure_axis(rgba, heading)
            problems = validate(rgba, heading, axis, None)
            failed |= bool(problems)
            print(json.dumps({"name": NAMES[heading], "file": str(path), "axis": asdict(axis),
                              "length_at_reference_scale": reference_length and round(reference_length * length_ratio(heading)),
                              "problems": problems}))
        return 1 if failed else 0
    palette = extract_palette(reference, args.colours) if (reference is not None and args.colours) else None
    entries = []
    for heading, path in jobs.items():
        name = f"train-{FILE_NAMES[heading]}.png"
        entries.append(process(path, heading, args.out / name, reference_length, palette, args.cell, reference_thickness))
    manifest = build_manifest(entries)
    manifest["reference_length"] = reference_length
    manifest["palette"] = palette
    (args.out / "train-manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
    contact_sheet(entries, args.out, args.out / "contact-sheet.png")
    for e in entries:
        print(f"{e['name']}: {'OK' if not e['problems'] else 'CHECK ' + '; '.join(e['problems'])}")
        for warning in e["warnings"]:
            print(f"  {warning}")
    return 1 if any(e["problems"] for e in entries) else 0


if __name__ == "__main__":
    sys.exit(main())
