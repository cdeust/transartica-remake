"""MIT. Semantic border checks against private CARTE evidence, never pixel copying."""
import importlib.util
import json
import unittest
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('terrain_builder', ROOT / 'tools/build_travel_terrain.py')
builder = importlib.util.module_from_spec(spec)
spec.loader.exec_module(builder)


def source_openings(resource):
    """Decode only border intervals of blue palette5..8, not artwork."""
    records = json.loads((ROOT / 'reference-private/map-resources.json').read_text())['resources']
    row = records[str(resource)]
    width, height = row['width'], row['height']
    pixels = [int(value, 16) for value in row['pixels']]
    edges = {'N': pixels[:width], 'E': pixels[width-1::width],
             'S': pixels[(height-1)*width:], 'W': pixels[::width]}
    result = {}
    for side, edge in edges.items():
        positions = [index for index, value in enumerate(edge) if value in (5,6,7,8)]
        if positions:
            result[side] = (min(positions), max(positions)+1)
    return result


def authored_openings(image):
    width, height = image.size
    edges = {'N': [image.getpixel((x,0)) for x in range(width)],
             'E': [image.getpixel((width-1,y)) for y in range(height)],
             'S': [image.getpixel((x,height-1)) for x in range(width)],
             'W': [image.getpixel((0,y)) for y in range(height)]}
    result = {}
    for side, edge in edges.items():
        positions = [index for index, (r,g,b,a) in enumerate(edge) if a and b-r == 0x82-0x42]
        if positions:
            result[side] = (min(positions), max(positions)+1)
    return result


def joined_source_pairs(data, source):
    """Original adjacent blue-border overlaps on the verified160x73 lattice."""
    from itertools import product
    # source: CARTE.FIC160x73 column-major, map-orientation-audit.md.
    for x,y in product(range(160),range(73)):
        first = data[x*73+y]
        if first not in source:
            continue
        for dx,dy,side,other_side in [(1,0,'E','W'),(0,1,'S','N')]:
            if x+dx >= 160 or y+dy >= 73:
                continue
            second = data[(x+dx)*73+y+dy]
            if second not in source or side not in source[first] or other_side not in source[second]:
                continue
            a,b = source[first][side],source[second][other_side]
            lower,upper = max(a[0],b[0]),min(a[1],b[1])
            if lower < upper:
                yield first,second,side,other_side,lower,upper


class ShorelineFidelity(unittest.TestCase):
    def test_source_connections_and_generated_assets(self):
        for resource in [*range(106,116),*range(134,141),149]:
            with self.subTest(resource=resource):
                source = source_openings(resource)
                self.assertEqual(builder.SHORE_OPENINGS[resource], source)
                expected = {side: (first*6,last*6) for side,(first,last) in source.items()}
                image = Image.open(ROOT / f'game/assets/travel/terrain/{resource}.png').convert('RGBA')
                self.assertEqual(authored_openings(image), expected)
                fresh = builder.oasis() if resource == 134 else builder.lake(resource)
                self.assertEqual(image.tobytes(), fresh.tobytes())

    def test_oasis_has_authored_vegetation_and_enclosed_pool(self):
        image = builder.oasis()
        colors = {tuple(bytes.fromhex(builder.P[key][1:])) for key in ('pine','pinehi')}
        self.assertTrue(any(pixel[:3] in colors for pixel in image.getdata()))
        self.assertEqual(authored_openings(image), {})
        self.assertTrue(any(pixel[2]-pixel[0] == 0x82-0x42 and pixel[3] for pixel in image.getdata()))

    def test_internal_edges_have_no_shore_stroke(self):
        # Paired lake108 above lake111 exposes matching full S/N openings;
        # both edges remain water, never an authored white coast separator.
        upper = builder.lake(108)
        lower = builder.lake(111)
        self.assertEqual([upper.getpixel((x,95)) for x in range(96)],
                         [lower.getpixel((x,0)) for x in range(96)])

    def test_real_source_neighbors_keep_water_connections(self):
        # source: CARTE.FIC160x73 column-major, map-orientation-audit.md.
        # Compare common border envelopes where the actual original tiles join.
        data = (ROOT / 'reference-private/CARTE.FIC').read_bytes()
        self.assertEqual(len(data), 160*73)
        codes = set(builder.SHORE_OPENINGS)
        images = {code: Image.open(ROOT / f'game/assets/travel/terrain/{code}.png').convert('RGBA') for code in codes}
        source = {code: source_openings(code) for code in codes}
        authored = {code: authored_openings(image) for code,image in images.items()}
        joined = 0
        for first,second,side,other_side,lower,upper in joined_source_pairs(data,source):
            actual_a,actual_b = authored[first][side],authored[second][other_side]
            self.assertEqual((max(actual_a[0],actual_b[0]),min(actual_a[1],actual_b[1])),(lower*6,upper*6))
            joined += 1
        self.assertGreater(joined, 0, 'source fixture must exercise actual adjacent water tiles')
        print(f'Source-neighbor water connections verified: {joined}')


if __name__ == '__main__':
    unittest.main()
