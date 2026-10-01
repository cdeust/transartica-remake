"""MIT. Private semantic vectors from CARTE resource192, never public pixels.
Measured source: map-orientation-audit.md and overview-authored-20261001.md.
Index10 thin olive route strokes,11 paper-compartment boundaries; blue14 has
45 filled5x3 town boxes,206 isolated route dots and ten9px symbols. Classification
uses those measured component shapes, not a blanket palette-as-terrain rule.
"""
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'reference-private/general-plan.json'
OUTPUT = ROOT / 'reference-private/overview-geometry.json'


def components(points):
    remaining = set(points)
    result = []
    while remaining:
        pending = [remaining.pop()]
        result.append(flood_component(pending, remaining))
    return result


def flood_component(pending, remaining):
    """Source: four adjacent source pixels define each measured component."""
    group = []
    while pending:
        x, y = pending.pop()
        group.append((x, y))
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            point = x + dx, y + dy
            if point in remaining:
                remaining.remove(point)
                pending.append(point)
    return group


def bounds(group):
    xs, ys = zip(*group)
    return [min(xs), min(ys), max(xs)-min(xs)+1, max(ys)-min(ys)+1]


def vectors(points):
    """Collapse contiguous collinear source strokes; no map/CARTE inference."""
    result = []
    covered = set()
    for dx, dy in ((1, 0), (0, 1), (1, 1), (-1, 1)):
        for x, y in sorted(points):
            if (x-dx, y-dy) in points or (x+dx, y+dy) not in points:
                continue
            end = x, y
            while (end[0]+dx, end[1]+dy) in points:
                covered.add(end)
                end = end[0]+dx, end[1]+dy
            covered.add(end)
            result.append([x, y, *end])
    result.extend([x, y, x, y] for x, y in sorted(points-covered))
    return result


def extract():
    raw = SOURCE.read_bytes()
    data = json.loads(raw)
    rows = [[index for index, length in row for _ in range(length)] for row in data['rows']]
    assert len(rows) == 149 and all(len(row) == 320 for row in rows)
    points = lambda colors: {(x,y) for y,row in enumerate(rows) for x,index in enumerate(row) if index in colors}
    towns, dots, symbols = [], [], []
    for group in components(points({14})):
        box = bounds(group)
        if box == [41,136,26,11]:  # measured original700Km scale cartouche.
            continue
        if len(group) == 15 and box[2:] == [5,3]: towns.append(box)
        elif len(group) == 1: dots.append(list(group[0]))
        else: symbols.append(box)
    dark = []
    for group in components(points({1,7,8,9})):
        box = bounds(group)
        if box[0] < 4 or box[1] < 4 or box == [291,104,29,27]: continue
        if box[0] <= 67 and box[0]+box[2] >= 41 and box[1] <= 147 and box[1]+box[3] >= 136: continue
        # Town/drop shadows are part of the measured blue cartouche, not new sites.
        if any(box[0] <= t[0]+t[2] and box[0]+box[2] >= t[0] and box[1] <= t[1]+t[3] and box[1]+box[3] >= t[1] for t in towns): continue
        dark.append(box)
    assert len(towns) == 45 and len(dots) == 206 and len(symbols) == 10
    return dict(version=1, width=320, height=149, source_sha256=hashlib.sha256(raw).hexdigest(),
                routes=vectors(points({10})), compartments=vectors(points({11})),
                towns=sorted(towns), dots=sorted(dots), symbols=sorted(symbols), sites=sorted(dark))


if __name__ == '__main__':
    geometry = extract()
    OUTPUT.write_text(json.dumps(geometry,separators=(',',':'))+'\n')
    print('Private overview:',len(geometry['routes']),'route vectors;',len(geometry['towns']),'towns; no RGB data')
