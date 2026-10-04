"""MIT. Detached protocol regression for native10904 waypoint-wrapper misuse."""
import contextlib
import io
from pathlib import Path
import sys
import unittest
from unittest.mock import patch

with patch.object(sys, "path", [str(Path(__file__).resolve().parents[1] / "tools"), *sys.path]):
    import player_travel as travel


class CompletedWaypoint(unittest.TestCase):
    def test_completed_leg_never_restarts_the_native_driver(self):
        before = {"screen": "map", "paused": True, "position": "(113, 58)"}
        after = {"screen": "map", "paused": True, "position": "(51, 39)"}
        with patch.object(travel.pilot, "state", side_effect=[before, after]), \
             patch.object(travel.pilot, "send", side_effect=AssertionError("No native input")), \
             patch.object(travel.leg, "drive") as drive, \
             contextlib.redirect_stdout(io.StringIO()) as output:
            travel.continue_travel(Path("detached.json"), "51,39", "not-a-city", [])
        drive.assert_called_once_with(Path("detached.json"))
        self.assertEqual(output.getvalue(), "PLAYER_STOP waypoint 51,39\n")


if __name__ == "__main__":
    unittest.main()
