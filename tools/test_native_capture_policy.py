"""MIT. Native command protocol preserves action logs and actual F5 archives."""
import contextlib
import io
import json
import tempfile
import unittest
from pathlib import Path
from unittest.mock import Mock, patch

import native_play


class CapturePolicyTest(unittest.TestCase):
    def test_default_evidence_is_project_temporary(self):
        self.assertEqual(native_play.EVIDENCE, native_play.CONSOLE / "captures")

    def test_godot_and_python_share_the_capture_directory(self):
        source = (native_play.ROOT / "game/tests/native_play_console.gd").read_text()
        resource = next(
            line.split('"')[1] for line in source.splitlines() if line.startswith('const EVIDENCE := "')
        )
        directory = (native_play.ROOT / "game" / resource.removeprefix("res://")).resolve()
        self.assertEqual(directory, (native_play.CONSOLE / "captures").resolve())
        self.assertEqual(directory, native_play.EVIDENCE.resolve())

    def test_launch_creates_capture_directory_before_its_log(self):
        with tempfile.TemporaryDirectory(dir=native_play.ROOT / ".cache") as temporary:
            evidence = Path(temporary) / "captures"
            process = Mock()
            process.poll.return_value = 0
            with patch.object(native_play, "EVIDENCE", evidence), \
                    patch.object(native_play.subprocess, "Popen", return_value=process), \
                    patch.object(native_play, "wait_for_boot"), patch.object(native_play, "perform"):
                native_play.launch(Mock(stay_open=False))
            self.assertEqual(len(list(evidence.glob("native-launch-*.log"))), 1)
            process.wait.assert_called_once_with(timeout=30)

    def test_commands_log_state_and_archive_f5_without_implicit_png(self):
        with tempfile.TemporaryDirectory(dir=native_play.ROOT / ".cache") as temporary:
            self.exercise_commands(Path(temporary))

    def exercise_commands(self, directory):
        observed = {"id": 8, "label": "action", "position": "(1,1)",
                    "cycles": 1, "speed": 0, "paused": True, "vehicles": 1}
        (directory / "save.json").write_text("earned F5 bytes")
        for extra, expected in [({}, False), ({"capture": False}, False), ({"capture": "true"}, False), ({"capture": True}, True)]:
            step = {"label": "action", "inputs": [{"key": "F5"}], **extra}
            self.send_command(directory, step, observed)
            command = json.loads((directory / "command.json").read_text())
            self.assertIs(command["capture"], expected)
            self.assertEqual(command["inputs"], [{"key": "F5"}])
            self.assertEqual((directory / "saves/8.json").read_text(), "earned F5 bytes")
        logs = [json.loads(line) for line in (directory / "captures/actions.jsonl").read_text().splitlines()]
        self.assertEqual(len(logs), 4)
        self.assertTrue(all(entry["state"] == observed for entry in logs))

    def send_command(self, directory, step, observed):
        initial = {"id": 7, "controls": []}
        with patch.object(native_play, "CONSOLE", directory), patch.object(native_play, "EVIDENCE", directory / "captures"), \
                patch.object(native_play, "state", side_effect=[initial, observed]), contextlib.redirect_stdout(io.StringIO()):
            self.assertEqual(native_play.send(step), observed)


if __name__ == "__main__":
    unittest.main()
