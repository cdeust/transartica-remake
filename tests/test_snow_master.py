"""MIT. Authored image identity and immutable build behavior, not visual approval."""
import hashlib
import importlib.util
from pathlib import Path
import unittest
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("terrain_builder", ROOT / "tools/build_travel_terrain.py")
builder = importlib.util.module_from_spec(spec)
spec.loader.exec_module(builder)


class SnowMasterTest(unittest.TestCase):
    def test_committed_master_identity(self):
        path = builder.verify_snow_master()
        self.assertEqual(hashlib.sha256(path.read_bytes()).hexdigest(), builder.SNOW_MASTER_SHA256)
        with Image.open(path) as image:
            # source: actual image_gen output dimensions and fully opaque pixels.
            self.assertEqual(image.size, (1254, 1254))
            self.assertEqual(image.convert("RGBA").getextrema()[3], (255,255))
        candidate = ROOT / "output/imagegen/world-map-20261004/snow-master-v2-candidate.png"
        if candidate.exists():
            self.assertEqual(path.read_bytes(), candidate.read_bytes())

    def test_runtime_uses_documented_master(self):
        source = (ROOT / "game/scripts/travel_world.gd").read_text()
        self.assertIn('const ICE_FIELD_PATH := "res://assets/travel/terrain/snow-master.png"', source)


if __name__ == "__main__":
    unittest.main()
