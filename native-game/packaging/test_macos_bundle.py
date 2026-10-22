# SPDX-License-Identifier: MIT
"""Parser/closure and tiny filesystem transaction fixtures; no game processes."""
from pathlib import Path
import json
import re
import tempfile
import unittest
from unittest.mock import patch
import macos_bundle as package

LOADS = """example (architecture arm64):
Load command 0
          cmd LC_ID_DYLIB
      cmdsize 72
         name /opt/homebrew/lib/test.dylib (offset 24)
Load command 1
          cmd LC_LOAD_DYLIB
         name /usr/lib/libSystem.B.dylib (offset 24)
Load command 2
          cmd LC_LOAD_WEAK_DYLIB
         name @rpath/a folder/test.dylib (offset 24)
Load command 3
          cmd LC_RPATH
         path @loader_path/../lib (offset 12)
Load command 4
          cmd LC_BUILD_VERSION
        minos 14.0
"""


class ParserTests(unittest.TestCase):
    def test_current_native_asset_literals_are_in_allowlist(self):
        native = package.HERE.parent
        config = json.loads((package.HERE / "runtime-assets.json").read_text())
        selected = set(config["assets"])
        paths = (path for directory in ("screens", "view") for path in (native / directory).glob("*.cpp"))
        for path in paths:
            for name in re.findall(r'assets_?\s*/\s*"([^"\n]+\.(?:png|json))"', path.read_text()):
                self.assertIn(name, selected, f"Missing runtime asset in {path.name}")
        hover = (native / "screens/room_hover.cpp").read_text()
        for name in re.findall(r'"((?:boudoir|quarters)-[^"\n]+\.png)"', hover):
            self.assertIn("boudoir/cutouts/" + name, selected)

    def test_registered_worktree_uses_project_output_scope(self):
        self.assertEqual(package.project_scope(Path("/project/.claude/worktrees/native")), Path("/project"))
        self.assertEqual(package.project_scope(Path("/project/.worktrees/native")), Path("/project"))
        self.assertEqual(package.project_scope(Path("/project")), Path("/project"))

    def test_real_load_command_domains(self):
        value = package.macho_commands(LOADS)
        self.assertEqual(value["id"], "/opt/homebrew/lib/test.dylib")
        self.assertEqual(value["loads"], ["/usr/lib/libSystem.B.dylib", "@rpath/a folder/test.dylib"])
        self.assertEqual(value["rpaths"], ["@loader_path/../lib"])
        self.assertEqual(value["minimum"], ["14.0"])

    def test_fat_architecture_records_deduplicate_dependencies(self):
        self.assertEqual(package.macho_commands(LOADS + LOADS)["loads"], package.macho_commands(LOADS)["loads"])

    def test_invalid_load_record_fails_closed(self):
        with self.assertRaises(package.PackageError):
            package.macho_commands("Load command 0\n cmd LC_LOAD_DYLIB\n name missing-offset\n")

    def test_resource_paths_reject_traversal(self):
        for name in ("", "../a", "/a", "a/./b", "a//b", "a\\b", "a/../b"):
            with self.subTest(name=name), self.assertRaises(package.PackageError):
                package.relative(name)
        self.assertEqual(package.relative("data/audio/a.wav"), Path("data/audio/a.wav"))

    def test_loader_and_executable_paths_are_distinct(self):
        loader = Path("/Application/Contents/Frameworks/a.dylib")
        exe = Path("/Application/Contents/MacOS/Transartica")
        self.assertEqual(package.expand_path("@loader_path/b.dylib", loader, exe), loader.parent / "b.dylib")
        self.assertEqual(package.expand_path("@executable_path/b.dylib", loader, exe), exe.parent / "b.dylib")
        with self.assertRaises(package.PackageError):
            package.expand_path("relative/path.dylib", loader, exe)

    def test_only_apple_system_roots_are_exempt(self):
        for name in ("/usr/lib/libSystem.B.dylib", "/System/Library/Frameworks/Cocoa.framework/Cocoa"):
            self.assertTrue(package.system_library(name))
        for name in ("/opt/homebrew/lib/a.dylib", "/usr/local/lib/a.dylib", "/Library/Frameworks/A.framework/A", "/usr/library/a"):
            self.assertFalse(package.system_library(name))

    def test_final_closure_rejects_external_paths_and_rpaths(self):
        for text in (LOADS, "Load command 0\n cmd LC_LOAD_DYLIB\n name /opt/homebrew/lib/a.dylib (offset 24)\n"):
            with self.subTest(text=text), patch.object(package, "run", return_value=text), self.assertRaises(package.PackageError):
                package.validate_closed_macho(Path("/App/Contents/MacOS/Transartica"), Path("/App"))

    def test_library_content_deduplication_and_name_collision(self):
        exe, a, b, c = map(Path, ("/bin/game", "/one/liba.dylib", "/two/liba.dylib", "/three/liba.dylib"))
        graph = {exe: {"sha256": "exe", "edges": {}}, a: {"sha256": "a" * 64, "edges": {}},
                 b: {"sha256": "b" * 64, "edges": {}}, c: {"sha256": "a" * 64, "edges": {}}}
        names = package.library_names(graph, exe)
        self.assertEqual(names[a], names[c])
        self.assertNotEqual(names[a], names[b])
        graph[c]["edges"] = {"different": b}
        with self.assertRaises(package.PackageError):
            package.library_names(graph, exe)


class ArtworkOverrideTests(unittest.TestCase):
    def setUp(self):
        self.scratch = tempfile.TemporaryDirectory(prefix=".artwork-test-", dir=package.HERE)
        self.addCleanup(self.scratch.cleanup)
        self.repo = Path(self.scratch.name) / "repo"
        self.game = self.repo / "game"
        self.original = self.game / "assets/travel/artwork/world-hd"
        self.candidate = self.repo / "candidate"
        self.config = self.repo / "packaging"
        for path in (self.original, self.candidate, self.config, self.game / "assets/interface", self.game / "data/audio"):
            path.mkdir(parents=True)
        self.write(self.config / "runtime-assets.json", {"game_data_files": [], "assets": ["travel/artwork/world-hd/manifest.json"], "atlas_manifests": [], "audio_scripts": []})
        self.write(self.game / "assets/interface/original-data-manifest.json", {"format": "transartica-original-data-v1", "files": []})
        self.write(self.game / "data/audio/manifest.json", {"scripts": {}})
        self.write(self.game / "data/audio/music.json", {"tracks": {}})
        for directory, marker in ((self.original, "original"), (self.candidate, "candidate")):
            scenes = []
            for i in range(8):
                path = directory / f"region-{i:02d}.png"
                path.write_bytes(f"{marker} fixture {i}".encode())
                scenes.append({"id": f"world-hd-{i:02d}", "world": [i, 0, 1, 1], "registration": "region_bounds", "variants": [{"background": {"image": "res://assets/travel/artwork/world-hd/" + path.name, "png_sha256": package.sha(path), "rgba_sha256": ("a" if marker == "original" else "b") * 64}}]})
            self.write(directory / "manifest.json", {"scenes": scenes})
        self.patch = patch.object(package, "HERE", self.config)
        self.patch.start()
        self.addCleanup(self.patch.stop)

    @staticmethod
    def write(path, value):
        path.write_text(json.dumps(value))

    def test_override_copies_complete_candidate_closure_without_touching_sources(self):
        before = {p.name: p.read_bytes() for p in self.original.iterdir()}
        default = package.resource_plan(self.repo)
        selected = package.resource_plan(self.repo, self.candidate)
        for name in ["manifest.json"] + [f"region-{i:02d}.png" for i in range(8)]:
            key = "assets/travel/artwork/world-hd/" + name
            self.assertEqual(selected[key]["source"], str((self.candidate / name).resolve()))
            self.assertEqual(selected[key]["sha256"], package.sha(self.candidate / name))
            self.assertEqual(default[key]["source"], str((self.original / name).resolve()))
        self.assertEqual(before, {p.name: p.read_bytes() for p in self.original.iterdir()})

    def test_override_rejects_incomplete_changed_or_escaping_closure(self):
        target = self.candidate / "region-07.png"
        content = target.read_bytes()
        target.unlink()
        with self.assertRaisesRegex(package.PackageError, "Required file"):
            package.resource_plan(self.repo, self.candidate)
        target.write_bytes(b"changed after manifest")
        with self.assertRaisesRegex(package.PackageError, "Artwork identity mismatch"):
            package.resource_plan(self.repo, self.candidate)
        target.write_bytes(content)
        doc = package.read_json(self.candidate / "manifest.json")
        changed = json.loads(json.dumps(doc))
        changed["scenes"][0]["world"][0] += 1
        self.write(self.candidate / "manifest.json", changed)
        with self.assertRaisesRegex(package.PackageError, "registration or dependencies"):
            package.resource_plan(self.repo, self.candidate)
        self.write(self.candidate / "manifest.json", doc)
        outside = self.repo / "outside.png"
        outside.write_bytes(content)
        target.unlink()
        target.symlink_to(outside)
        with self.assertRaisesRegex(package.PackageError, "escapes its directory"):
            package.resource_plan(self.repo, self.candidate)


class PublicationTests(unittest.TestCase):
    def setUp(self):
        # Root runs these under its guard; fixtures stay inside this project and
        # contain a single text payload, never an executable or historical data.
        self.scratch = tempfile.TemporaryDirectory(prefix=".publication-test-", dir=package.HERE)
        self.addCleanup(self.scratch.cleanup)
        self.directory = Path(self.scratch.name)
        self.stage = self.directory / ".incoming"
        self.stage.mkdir()
        (self.stage / "payload.txt").write_text("unchanged payload")
        self.output = self.directory / "Result.app"
        self.final_receipt = Path(str(self.output) + ".receipt.json")
        self.candidate = Path(str(self.stage) + ".receipt.json")
        self.receipt = {"files": {"payload.txt": "fixture"}}

    def assert_unpublished(self):
        self.assertEqual((self.stage / "payload.txt").read_text(), "unchanged payload")
        self.assertFalse(self.output.exists())
        self.assertFalse(self.final_receipt.exists())

    def test_receipt_write_failure_does_not_publish_bundle(self):
        def incomplete_write(value, stream, **kwargs):
            stream.write("partial")
            raise OSError("injected receipt write failure")
        with patch.object(package.json, "dump", side_effect=incomplete_write), self.assertRaisesRegex(OSError, "receipt write"):
            package.publish_bundle(self.stage, self.output, self.receipt)
        self.assert_unpublished()
        self.assertEqual(self.candidate.read_text(), "partial")

    def test_bundle_publication_failure_retains_complete_receipt(self):
        with patch.object(Path, "rename", side_effect=OSError("injected bundle publication failure")), self.assertRaisesRegex(OSError, "bundle publication"):
            package.publish_bundle(self.stage, self.output, self.receipt)
        self.assert_unpublished()
        self.assertEqual(json.loads(self.candidate.read_text()), self.receipt)

    def test_receipt_publication_failure_rolls_back_bundle(self):
        with patch.object(package.os, "link", side_effect=OSError("injected receipt publication failure")), self.assertRaisesRegex(OSError, "receipt publication"):
            package.publish_bundle(self.stage, self.output, self.receipt)
        self.assert_unpublished()
        self.assertEqual(json.loads(self.candidate.read_text()), self.receipt)

    def test_receipt_race_preserves_existing_file_and_rolls_back_bundle(self):
        original_link = package.os.link
        def competing_receipt(source, destination):
            self.final_receipt.write_text("other owner")
            original_link(source, destination)
        with patch.object(package.os, "link", side_effect=competing_receipt), self.assertRaises(FileExistsError):
            package.publish_bundle(self.stage, self.output, self.receipt)
        self.assertFalse(self.output.exists())
        self.assertTrue(self.stage.is_dir())
        self.assertEqual(self.final_receipt.read_text(), "other owner")
        self.assertEqual(json.loads(self.candidate.read_text()), self.receipt)

    def test_failed_rollback_reports_the_actual_retained_bundle(self):
        original_rename = Path.rename
        def rename(source, target):
            if source == self.output:
                raise OSError("injected rollback failure")
            return original_rename(source, target)
        with patch.object(Path, "rename", rename), patch.object(package.os, "link", side_effect=OSError("publication failure")), self.assertRaises(package.PackageError) as error:
            package.publish_bundle(self.stage, self.output, self.receipt)
        self.assertIn(str(self.output), str(error.exception))
        self.assertIn(str(self.candidate), str(error.exception))
        self.assertFalse(self.stage.exists())
        self.assertEqual((self.output / "payload.txt").read_text(), "unchanged payload")
        self.assertFalse(self.final_receipt.exists())
        self.assertEqual(json.loads(self.candidate.read_text()), self.receipt)

    def test_success_publishes_complete_pair_and_removes_candidate(self):
        self.assertEqual(package.publish_bundle(self.stage, self.output, self.receipt), self.final_receipt)
        self.assertFalse(self.stage.exists())
        self.assertFalse(self.candidate.exists())
        self.assertEqual((self.output / "payload.txt").read_text(), "unchanged payload")
        self.assertEqual(json.loads(self.final_receipt.read_text()), self.receipt)


if __name__ == "__main__":
    unittest.main()
