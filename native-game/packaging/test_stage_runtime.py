# SPDX-License-Identifier: MIT
"""Resource staging regression tests using small synthetic, non-game payloads."""
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

import macos_bundle as package
import stage_runtime


class StagingTests(unittest.TestCase):
    def setUp(self):
        scratch = tempfile.TemporaryDirectory(prefix=".stage-test-", dir=Path(__file__).parent)
        self.addCleanup(scratch.cleanup)
        self.directory = Path(scratch.name)
        self.repo = self.directory / "source"
        self.output = self.directory / "runtime"
        self.config = self.repo / "native-game/packaging"
        self.game = self.repo / "game"
        self.populate()
        config_patch = patch.object(package, "HERE", self.config)
        config_patch.start()
        self.addCleanup(config_patch.stop)

    def write(self, name, value):
        path = self.repo / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(value if isinstance(value, bytes) else json.dumps(value).encode())
        return path

    def populate(self):
        self.write("native-game/packaging/runtime-assets.json", {
            "game_data_files": ["CARTE.FIC", "audio/manifest.json"],
            "assets": ["travel/artwork/world-hd/manifest.json", "atlas/sheet.json",
                       "interface/original-data-manifest.json"],
            "atlas_manifests": ["atlas/sheet.json"], "audio_scripts": ["son"]})
        self.write("game/assets/atlas/sheet.json", {"file": "sheet.png"})
        self.write("game/assets/atlas/sheet.png", b"first atlas bytes")
        self.write("game/data/audio/manifest.json", {"scripts": {
            "son": {"samples": {"1": {"file": "res://private-data/audio/sample.wav"}}}}})
        self.write("game/data/audio/sample.wav", b"sample bytes")
        self.write("game/data/audio/music.json", {"tracks": {}})
        carte = self.write("game/data/CARTE.FIC", b"edition bytes")
        self.write("game/assets/interface/original-data-manifest.json", {
            "format": "transartica-original-data-v1", "files": [{
                "path": "private-data/CARTE.FIC", "sha256": package.sha(carte), "size": carte.stat().st_size}]})
        for name in ("native-game/assets/fonts/NotoSans.ttf", "native-game/assets/fonts/OFL.txt",
                     "LICENSE", "native-game/third_party/godot-math-LICENSE.txt",
                     "native-game/packaging/RESOURCE-NOTICE.txt"):
            self.write(name, b"synthetic ancillary bytes")
        self.paintings()

    def paintings(self):
        scenes = []
        for index in range(8):
            name = f"assets/travel/artwork/world-hd/region-{index:02d}.png"
            path = self.write("game/" + name, f"painting {index}".encode())
            scenes.append({"id": str(index), "registration": "region_bounds", "variants": [{
                "background": {"image": "res://" + name, "png_sha256": package.sha(path)}}]})
        self.write("game/assets/travel/artwork/world-hd/manifest.json", {"scenes": scenes})

    def test_missing_transitive_asset_fails_before_writing(self):
        (self.game / "assets/atlas/sheet.png").unlink()
        with self.assertRaisesRegex(package.PackageError, "Required file unavailable"):
            stage_runtime.stage(self.repo, self.output)
        self.assertFalse(self.output.exists())

    def test_changed_resource_is_refreshed_without_rewriting_unchanged_files(self):
        stage_runtime.stage(self.repo, self.output)
        stable = self.output / "game/data/CARTE.FIC"
        timestamp = stable.stat().st_mtime_ns
        self.write("game/assets/atlas/sheet.png", b"second atlas bytes")
        result = stage_runtime.stage(self.repo, self.output)
        self.assertEqual(result["copied"], 1)
        self.assertEqual((self.output / "game/assets/atlas/sheet.png").read_bytes(), b"second atlas bytes")
        self.assertEqual(stable.stat().st_mtime_ns, timestamp)

    def test_stage_is_closed_after_source_checkout_is_unavailable(self):
        stage_runtime.stage(self.repo, self.output)
        self.repo.rename(self.directory / "source-offline")
        installed = self.directory / "installed"
        stage_runtime.install_staged(self.output, installed)
        inventory = json.loads((installed / "resource-inventory.json").read_text())
        self.assertIn("game/data/audio/sample.wav", inventory)
        self.assertTrue(inventory["game/data/CARTE.FIC"]["edition_verified"])
        for name, entry in inventory.items():
            path = installed / name
            self.assertFalse(path.is_symlink())
            self.assertEqual(package.sha(path), entry["sha256"])
            self.assertNotIn("source", entry)

    def test_install_prunes_removed_owned_files_and_keeps_unrelated_files(self):
        installed = self.directory / "installed"
        stage_runtime.stage(self.repo, self.output)
        stage_runtime.install_staged(self.output, installed)
        unrelated = installed / "user-notes.txt"
        unrelated.write_text("keep this user file")
        config_path = self.config / "runtime-assets.json"
        config = json.loads(config_path.read_text())
        config["assets"].remove("atlas/sheet.json")
        config["atlas_manifests"] = []
        config_path.write_text(json.dumps(config))
        stage_runtime.stage(self.repo, self.output)
        stage_runtime.install_staged(self.output, installed)
        self.assertFalse((installed / "game/assets/atlas/sheet.png").exists())
        self.assertFalse((installed / "game/assets/atlas/sheet.json").exists())
        self.assertEqual(unrelated.read_text(), "keep this user file")

    def test_install_rejects_changed_source_before_writing(self):
        stage_runtime.stage(self.repo, self.output)
        (self.output / "fonts/NotoSans.ttf").write_bytes(b"changed staged font")
        installed = self.directory / "installed"
        with self.assertRaisesRegex(package.PackageError, "Staged resource identity mismatch"):
            stage_runtime.install_staged(self.output, installed)
        self.assertFalse(installed.exists())

    def test_install_rejects_missing_source_before_writing(self):
        stage_runtime.stage(self.repo, self.output)
        (self.output / "game/data/CARTE.FIC").unlink()
        installed = self.directory / "installed"
        with self.assertRaisesRegex(package.PackageError, "Required file unavailable"):
            stage_runtime.install_staged(self.output, installed)
        self.assertFalse(installed.exists())

    def test_historical_edition_identity_survives_native_path_relocation(self):
        self.write("game/data/CARTE.FIC", b"changed edition")
        with self.assertRaisesRegex(package.PackageError, "Historical edition mismatch"):
            stage_runtime.stage(self.repo, self.output)
        self.assertFalse(self.output.exists())

    def test_resource_symlink_outside_checkout_is_rejected(self):
        external = self.directory / "external.png"
        external.write_bytes(b"external bytes")
        path = self.game / "assets/atlas/sheet.png"
        path.unlink()
        path.symlink_to(external)
        with self.assertRaisesRegex(package.PackageError, "outside (checkout|project)"):
            stage_runtime.stage(self.repo, self.output)


if __name__ == "__main__":
    unittest.main()
