# SPDX-License-Identifier: MIT
"""Publication refuses substituted runs, music and installer bytes."""
import copy
import hashlib
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
import zipfile

import publish_installer as publisher


class Publisher(unittest.TestCase):
    def test_source_identity_checks(self):
        run = {"repository": {"full_name": "owner/repo"}, "head_repository": {"full_name": "owner/repo"},
               "head_sha": "a" * 40, "name": "Native Windows installer", "path": ".github/workflows/native-windows-delivery.yml",
               "status": "completed", "conclusion": "success"}
        publisher.validate_run(run, "owner/repo", "a" * 40)
        for key, value in (("head_repository", {"full_name": "other/repo"}), ("head_sha", "b" * 40), ("path", "other.yml"), ("conclusion", "failure")):
            with self.subTest(key=key), self.assertRaises(ValueError):
                publisher.validate_run(dict(run, **{key: value}), "owner/repo", "a" * 40)

    def test_draft_lookup_preserves_existing_assets(self):
        release = {"id": 1, "tag_name": "native-v1", "draft": True, "assets": [{"name": "mac.dmg"}]}
        with patch.object(publisher.subprocess, "check_output", return_value=json.dumps([[release]]).encode()):
            self.assertEqual(publisher.draft_release("owner/repo", "native-v1")["id"], 1)
        for field in ({"draft": False}, {"assets": [{"name": "Transartica-setup.exe"}]}):
            with patch.object(publisher.subprocess, "check_output", return_value=json.dumps([[dict(release, **field)]]).encode()), self.assertRaises(ValueError):
                publisher.draft_release("owner/repo", "native-v1")

    def fixture(self, root, mutation=None):
        installer = b"installer fixture"
        digest = hashlib.sha256(installer).hexdigest()
        names = ["bopres-0"] + [f"cue-{index}" for index in range(8)]
        manifest = {"tracks": {name: {"file": f"res://assets/audio/orchestral/{name}.wav", "sha256": name, "rate": 44100, "frames": 12} for name in names}}
        package = {"files": {"resources/game/" + t["file"][6:]: t["sha256"] for t in manifest["tracks"].values()}}
        package["files"]["resources/game/assets/audio/orchestral/music.json"] = "manifest"
        smoke = {"runtime_tested": True, "uninstall_tested": True, "resources_verified": len(package["files"]), "physical_audio_tested": False, "gameplay_input_tested": False, "installer_sha256": digest}
        if mutation:
            mutation(package, smoke)
        path = root / "artifact.zip"
        with zipfile.ZipFile(path, "w") as archive:
            archive.writestr("delivery/Transartica-setup.exe", installer)
            archive.writestr("build/package-receipt.json", json.dumps(package))
            archive.writestr("delivery/windows-smoke/receipt.json", json.dumps(smoke))
            archive.writestr("delivery/windows-smoke/state.log", 'STATE event=boot x\nSTATE event=quit x\nAUDIO event=quit driver=dummy rate=44100 music_cursor=3 music_frames=12 music_playing=1 finale_cursor=0 error=""\n')
            archive.writestr("delivery/windows-smoke/stdout.log", "NATIVE runtime=SDL2 renderer=software")
            archive.writestr("delivery/windows-smoke/stderr.log", "")
            archive.writestr("build/LastTest.log", "CTest fixture")
        artifact = {"size_in_bytes": path.stat().st_size, "digest": "sha256:" + publisher.sha(path)}
        return path, artifact, manifest

    def test_verified_archive_preserves_small_proof(self):
        with tempfile.TemporaryDirectory() as name:
            path, artifact, manifest = self.fixture(Path(name))
            installer, proof = publisher.verify_archive(path, artifact, manifest, "manifest")
            self.assertEqual(installer.read_bytes(), b"installer fixture")
            self.assertEqual(len(proof["music_sha256"]), 9)
            self.assertTrue((Path(name) / "proof/windows-smoke-receipt.json").is_file())

    def test_rejects_artifact_digest_and_music_substitution(self):
        with tempfile.TemporaryDirectory() as name:
            path, artifact, manifest = self.fixture(Path(name))
            with self.assertRaisesRegex(ValueError, "digest mismatch"):
                publisher.verify_archive(path, dict(artifact, digest="bad"), manifest, "manifest")
            altered = copy.deepcopy(manifest)
            altered["tracks"]["bopres-0"]["sha256"] = "substituted"
            with self.assertRaisesRegex(ValueError, "Music hash mismatch"):
                publisher.verify_archive(path, artifact, altered, "manifest")

    def test_rejects_installer_substitution_and_incomplete_smoke(self):
        for field, value in (("installer_sha256", "bad"), ("uninstall_tested", False), ("resources_verified", 0)):
            with self.subTest(field=field), tempfile.TemporaryDirectory() as name:
                path, artifact, manifest = self.fixture(Path(name), lambda package, smoke: smoke.update({field: value}))
                self.assertRaises(ValueError, publisher.verify_archive, path, artifact, manifest, "manifest")

    def test_upload_refuses_release_changed_to_public(self):
        with patch.object(publisher, "api", return_value={"draft": False, "tag_name": "native-v1"}), patch.object(publisher.subprocess, "run") as upload:
            with self.assertRaisesRegex(ValueError, "Draft changed"):
                publisher.upload("owner/repo", {"id": 1, "tag_name": "native-v1"}, Path("Transartica-setup.exe"))
            upload.assert_not_called()

    def test_title_frame_mismatch_is_rejected(self):
        with tempfile.TemporaryDirectory() as name:
            path, artifact, manifest = self.fixture(Path(name))
            manifest["tracks"]["bopres-0"]["frames"] += 1
            with self.assertRaisesRegex(ValueError, "title did not advance"):
                publisher.verify_archive(path, artifact, manifest, "manifest")

    def test_upload_checks_remote_asset_digest(self):
        with tempfile.TemporaryDirectory() as name:
            installer = Path(name) / "Transartica-setup.exe"
            installer.write_bytes(b"installer")
            release = {"id": 1, "tag_name": "native-v1", "draft": True, "assets": []}
            asset = {"name": installer.name, "state": "uploaded", "size": installer.stat().st_size, "digest": "bad"}
            with patch.object(publisher, "api", side_effect=[release, [asset]]), patch.object(publisher.subprocess, "run"), self.assertRaisesRegex(ValueError, "Remote asset digest mismatch"):
                publisher.upload("owner/repo", release, installer)


if __name__ == "__main__":
    unittest.main()
