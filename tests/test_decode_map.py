import hashlib
import importlib.util
import json
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location("decode_map", ROOT / "tools" / "decode_map.py")
decode_map = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(decode_map)


class DecodeMapTests(unittest.TestCase):
    def test_column_major_conversion_roundtrips_every_byte(self):
        raw = bytes(range(256)) * 45 + bytes(range(160))
        raw = raw[: decode_map.SIZE]
        rows = decode_map.column_major_to_rows(raw)
        rebuilt = bytes(rows[y][x] for x in range(decode_map.WIDTH) for y in range(decode_map.HEIGHT))
        self.assertEqual(rebuilt, raw)
        self.assertEqual(rows[72][159], raw[159 * 73 + 72])

    def test_rejects_bad_input_size(self):
        with self.assertRaisesRegex(ValueError, "expected 11680"):
            decode_map.column_major_to_rows(b"short")

    def test_real_observation_matches_independent_city_oracle_when_present(self):
        raw_path = ROOT / "reference-private" / "CARTE.FIC"
        if not raw_path.exists():
            self.skipTest("private observation archive is unavailable")
        cities_path = ROOT / "data" / "villes.csv"
        self.assertEqual(hashlib.sha256(raw_path.read_bytes()).hexdigest(), decode_map.REFERENCE_SHA256)
        grid = decode_map.column_major_to_rows(raw_path.read_bytes())
        validation = decode_map.validate_cities(decode_map.read_cities(cities_path), grid)
        self.assertEqual(validation["town_count"], 44)
        self.assertEqual(validation["town_code_matches"], 43)
        self.assertEqual(validation["unmatched_tibesti"]["map_code"], 0)

    def test_decode_writes_numeric_grid_and_standalone_html(self):
        raw = bytearray(decode_map.SIZE)
        cities = ROOT / "data" / "villes.csv"
        with tempfile.TemporaryDirectory() as temp:
            input_path, output = Path(temp) / "map.bin", Path(temp) / "out"
            input_path.write_bytes(raw)
            result = decode_map.decode(input_path, cities, output)
            parsed = json.loads((output / "map.json").read_text())
            self.assertEqual(parsed["grid"], result["grid"])
            self.assertEqual(len(parsed["grid"]), 73)
            self.assertEqual(len(parsed["grid"][0]), 160)
            page = (output / "index.html").read_text()
            self.assertIn("<canvas", page)
            self.assertIn("Show all CSV town coordinates", page)
            self.assertNotIn("<div class=\"legend\">$", page)
            self.assertTrue((output / "city-validation.csv").exists())


if __name__ == "__main__":
    unittest.main()
