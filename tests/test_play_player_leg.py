"""MIT. Mock protocol fixtures supplement native10354..10356; no gameplay proof.

No console writes, game process, model stepping or resource/position injection.
Switch19 at phase0 and switch18 at phase2 are observed in those native captures.
"""
import importlib.util
import json
from pathlib import Path
import sys
import unittest
from unittest.mock import Mock, patch

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("player_leg_under_test", ROOT / "tools/play_player_leg.py")
leg = importlib.util.module_from_spec(spec)
with patch.object(sys, "path", [str(ROOT / "tools"), *sys.path]):
    spec.loader.exec_module(leg)


class SwitchPreparationFixtures(unittest.TestCase):
    def setUp(self):
        # Hard guard: a missed mock must never reach the active native console.
        guard = patch.object(leg.pilot, "send", side_effect=AssertionError("No native inputs allowed in fixtures"))
        guard.start()
        self.addCleanup(guard.stop)
        self.route = [{"cell": [42, 32], "switch": 19}]

    def test_targets_start_at_cursor_keep_first_visit_and_stop_at_reversal(self):
        route = [
            {"cell": [42, 32], "switch": 18},
            {"cell": [42, 32], "switch": 19},
            {"cell": [42, 32], "switch": 18},
            {"cell": [42, 32], "reverse": True},
            {"cell": [42, 32], "switch": 18},
        ]
        self.assertEqual(leg.switch_targets(route, 1), {(42, 32): 19})
        self.assertEqual(leg.switch_targets(route, 3), {})

    def test_needed_uses_only_visible_mismatching_targets(self):
        self.assertFalse(leg.switch_needed(self.route, 0, {"switches": []}))
        self.assertFalse(leg.switch_needed(self.route, 0, {"switches": [{"cell": [42, 32], "tile": 19}]}))
        self.assertTrue(leg.switch_needed(self.route, 0, {"switches": [{"cell": [42, 32], "tile": 18}]}))
        self.assertFalse(leg.switch_needed([], 0, {"switches": [{"cell": [42, 32], "tile": 18}]}))

    def test_selection_while_moving_is_rejected_before_any_action(self):
        moving = {"paused": False, "switches": [{"cell": [42, 32], "tile": 18}]}
        with patch.object(leg, "action") as action:
            with self.assertRaisesRegex(RuntimeError, "while paused"):
                leg.select_switches(self.route, 0, moving, "fixture")
            action.assert_not_called()

    def test_replan_selects_from_actual_f5_state_then_resumes(self):
        # Three distinct observations prevent a stale pre-pause observation
        # from accidentally passing: only the F5 observation needs switch19.
        moving = {"screen": "map", "paused": False, "phase": 0,
                  "switches": [{"cell": [42, 32], "tile": 19}]}
        paused = {**moving, "paused": True, "phase": 1}
        saved = {**moving, "paused": True, "phase": 2,
                 "switches": [{"cell": [42, 32], "tile": 18}]}
        selected = {**saved, "switches": [{"cell": [42, 32], "tile": 19}]}
        resumed = {**selected, "paused": False}
        timeline = []
        path = Mock(spec=Path)
        path.read_text.side_effect = lambda: timeline.append("read-plan") or json.dumps(self.route)

        def action(label, inputs, **expectations):
            timeline.append((label, inputs, expectations))
            return {"fixture-pause": paused, "fixture-save": saved,
                    "fixture-switch": selected, "fixture-continue": resumed}[label]

        with patch.object(leg, "action", side_effect=action), \
             patch.object(leg, "plan_from_save", side_effect=lambda *args: timeline.append("plan")) as plan, \
             patch.object(leg, "select_switches", wraps=leg.select_switches) as select:
            route, observed = leg.replan_and_resume(path, "42,32", moving, "fixture")
        plan.assert_called_once_with(path, "42,32")
        select.assert_called_once_with(self.route, 0, saved, "fixture-switch")
        self.assertEqual(timeline, [
            ("fixture-pause", [{"key": "Space"}], {"expect": {"paused": True}}),
            ("fixture-save", [{"key": "F5"}], {"expect": {"paused": True}}),
            "plan", "read-plan",
            ("fixture-switch", [{"switch_cell": [42, 32]}],
             {"expect_switches": [{"cell": [42, 32], "tile": 19}]}),
            ("fixture-continue", [{"key": "Space"}], {"expect": {"paused": False}}),
        ])
        self.assertEqual(route, self.route)
        self.assertIs(observed, resumed)

    def test_no_route_keeps_actual_game_paused_without_selection_or_resume(self):
        moving = {"screen": "map", "paused": False}
        saved = {"screen": "map", "paused": True}
        path = Mock(spec=Path)
        path.read_text.return_value = "[]"
        with patch.object(leg, "action", return_value=saved) as action, \
             patch.object(leg, "plan_from_save") as plan, \
             patch.object(leg, "select_switches") as select:
            with self.assertRaisesRegex(RuntimeError, "No itinerary"):
                leg.replan_and_resume(path, "42,32", moving, "fixture")
        self.assertEqual([call.args[0] for call in action.call_args_list], ["fixture-pause", "fixture-save"])
        plan.assert_called_once_with(path, "42,32")
        select.assert_not_called()
        self.assertTrue(saved["paused"])


if __name__ == "__main__":
    unittest.main()
