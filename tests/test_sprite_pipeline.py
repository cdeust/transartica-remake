import importlib.util
import json
import math
import sys
import tempfile
import unittest
from pathlib import Path

try:
    import numpy as np
    from PIL import Image, ImageDraw
except ImportError:  # Run through uv, see tools/sprite_pipeline.py docstring.
    np = None

ROOT = Path(__file__).resolve().parents[1]


def load_pipeline():
    spec = importlib.util.spec_from_file_location("sprite_pipeline", ROOT / "tools" / "sprite_pipeline.py")
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module  # dataclasses resolve annotations through sys.modules.
    spec.loader.exec_module(module)
    return module


def synthetic_train(angle, length=900, canvas=(1536, 1024), background=(0, 0, 0, 0)):
    """Six boxes on one axis, with a tall 'funnel' on the front car and a halo fringe."""
    image = Image.new("RGBA", canvas, background)
    draw = ImageDraw.Draw(image)
    centre = np.array(canvas, float) / 2
    axis = np.array([math.cos(angle), math.sin(angle)])
    up = np.array([0.0, -1.0])
    car = length / 6
    for index in range(6):
        start = centre + axis * (index * car - length / 2)
        end = start + axis * (car * 0.92)
        height = 140 if index == 5 else 90
        polygon = [tuple(start), tuple(end), tuple(end + up * height), tuple(start + up * height)]
        draw.polygon(polygon, fill=(40 + index * 20, 60, 80, 255))
    draw.line([tuple(centre - axis * length / 2), tuple(centre + axis * length / 2)], fill=(200, 200, 200, 60), width=5)
    return np.asarray(image).copy()


@unittest.skipIf(np is None, "Pillow/numpy missing: run through uv (see tools/sprite_pipeline.py)")
class SpritePipelineTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.sp = load_pipeline()

    def test_expected_screen_directions_follow_travel_projection(self):
        sp = self.sp
        self.assertAlmostEqual(math.degrees(sp.expected_angle(6)), 29.05, places=1)
        self.assertAlmostEqual(math.degrees(sp.expected_angle(3)), 90.0, places=6)
        self.assertAlmostEqual(math.degrees(sp.expected_angle(9)), 0.0, places=6)
        self.assertAlmostEqual(sp.length_ratio(9), 360 / math.sqrt(2) / math.hypot(180, 100), places=6)
        self.assertLess(sp.length_ratio(3), 0.7)

    def test_measures_axis_of_synthetic_convoys(self):
        sp = self.sp
        for heading in (6, 9, 4):
            angle = sp.expected_angle(heading)
            rgba = sp.harden_alpha(synthetic_train(angle))
            axis = sp.measure_axis(rgba, heading)
            self.assertLess(sp.angle_error(axis.angle, heading), math.radians(1.5), heading)
            self.assertEqual(sp.validate(rgba, heading, axis, None), [])
            self.assertGreater(rgba[round(axis.nose[1]) - 2 : round(axis.nose[1]) + 3,
                                    round(axis.nose[0]) - 2 : round(axis.nose[0]) + 3, 3].max(), 0)

    def test_rejects_wrong_orientation_and_opaque_background(self):
        sp = self.sp
        rgba = sp.harden_alpha(synthetic_train(sp.expected_angle(9)))
        axis = sp.measure_axis(rgba, 6)
        self.assertTrue(any("expected 29.1 deg" in p for p in sp.validate(rgba, 6, axis, None)))
        opaque = sp.harden_alpha(synthetic_train(sp.expected_angle(6), background=(255, 255, 255, 255)))
        problems = sp.validate(opaque, 6, axis, None)
        self.assertTrue(any("transparent" in p for p in problems))

    def test_harden_alpha_removes_halo(self):
        rgba = self.sp.harden_alpha(synthetic_train(0.3))
        self.assertTrue(set(np.unique(rgba[..., 3]).tolist()) <= {0, 255})
        self.assertFalse(rgba[rgba[..., 3] == 0][:, :3].any())

    def test_pixelize_produces_uniform_cells(self):
        rgba = self.sp.harden_alpha(synthetic_train(0.5))[:512, :768]
        grid = self.sp.pixelize(rgba, 4)
        blocks = grid.reshape(128, 4, 192, 4, 4)
        self.assertTrue((blocks == blocks[:, :1, :, :1]).all())

    def test_palette_is_shared(self):
        sp = self.sp
        reference = sp.harden_alpha(synthetic_train(0.5))
        palette = sp.extract_palette(reference, 4)
        other = sp.apply_palette(sp.harden_alpha(synthetic_train(1.0)), palette)
        used = {"#%02x%02x%02x" % tuple(c) for c in other[other[..., 3] == 255][:, :3]}
        self.assertTrue(used <= set(palette))

    def test_warns_when_body_thickness_drifts(self):
        sp = self.sp
        axis = sp.Axis(0.0, (1.0, 1.0), (0.0, 1.0), 100.0, 60.0)
        self.assertEqual(sp.thickness_warning(axis, 70.0), [])
        self.assertIn("foreshortening", sp.thickness_warning(axis, 100.0)[0])

    def test_mirror_maps_east_to_south(self):
        sp = self.sp
        axis = sp.Axis(sp.expected_angle(6), (1400.0, 900.0), (30.0, 140.0), 1700.0)
        mirrored = sp.mirror_axis(axis, 1536)
        self.assertLess(sp.angle_error(mirrored.angle, 2), 1e-9)
        self.assertEqual(mirrored.nose, (135.0, 900.0))

    def test_cli_normalises_scale_and_writes_manifest(self):
        sp = self.sp
        with tempfile.TemporaryDirectory(dir=ROOT / ".cache") as folder:
            folder = Path(folder)
            Image.fromarray(synthetic_train(sp.expected_angle(6), 1000)).save(folder / "e.png")
            Image.fromarray(synthetic_train(sp.expected_angle(9), 700)).save(folder / "ne.png")
            status = sp.main(["E=" + str(folder / "e.png"), "NE=" + str(folder / "ne.png"), "--out", str(folder / "out")])
            self.assertEqual(status, 0)
            manifest = json.loads((folder / "out" / "train-manifest.json").read_text())
            self.assertEqual(manifest["headings"]["1"]["mirrored"], True)
            self.assertEqual(manifest["headings"]["2"]["file"], "train-east.png")
            self.assertIn("W", manifest["missing"])
            ratio = manifest["headings"]["9"]["length"] / manifest["headings"]["6"]["length"]
            self.assertAlmostEqual(ratio, sp.length_ratio(9), delta=0.05)
            self.assertTrue((folder / "out" / "contact-sheet.png").exists())

    def test_reference_sprite_axis_matches_authored_constant_when_present(self):
        path = ROOT / "game" / "assets" / "travel" / "train-east.png"
        if not path.exists():
            self.skipTest("travel sprite absent")
        sp = self.sp
        axis = sp.measure_axis(sp.harden_alpha(sp.load_rgba(path)), 6)
        # source: travel_world.gd TRAIN_AXIS_ANGLE, measured by hand on the same file.
        self.assertAlmostEqual(axis.angle, 0.5070, delta=0.01)


if __name__ == "__main__":
    unittest.main()
