"""Neighbour support for rail glyph ports (tasks/evidence/rail-glyphs.md method),
counting neighbours in the full rail set: |code| 1-33 and 38-58 (TIME 0x0486 speed
rule and 0x14c9 curve switch treat 38-58 as track). Stations 34-37 and event tiles
are excluded. Usage: glyph_ports.py CARTE.FIC code [code...]"""
import sys
W, H = 160, 73
DIRS = {'N': (0, -1), 'NE': (1, -1), 'E': (1, 0), 'SE': (1, 1),
        'S': (0, 1), 'SW': (-1, 1), 'W': (-1, 0), 'NW': (-1, -1)}
RAIL = set(range(1, 34)) | set(range(38, 59))

def rail_neighbours(tile, x, y):
    for d, (dx, dy) in DIRS.items():
        nx, ny = x + dx, y + dy
        if 0 <= nx < W and 0 <= ny < H and tile(nx, ny) in RAIL:
            yield d

def main(path, codes):
    raw = open(path, 'rb').read()
    tile = lambda x, y: abs(raw[x * 73 + y] - 256 if raw[x * 73 + y] > 127 else raw[x * 73 + y])
    for code in codes:
        cells = [(x, y) for x in range(W) for y in range(H) if tile(x, y) == code]
        counts = {d: 0 for d in DIRS}
        for x, y in cells:
            for d in rail_neighbours(tile, x, y):
                counts[d] += 1
        seen = ' '.join(f'{d}{n}' for d, n in counts.items() if n)
        print(f'{code:3d} n={len(cells):3d} {seen}  cells={cells[:4]}')

if __name__ == '__main__':
    main(sys.argv[1], [int(c) for c in sys.argv[2:]])
