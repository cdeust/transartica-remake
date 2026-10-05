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

    def test_city_arrival_during_fuel_input_stops_and_saves(self):
        # Native11589 changes map to TURIN during fire(), before the next poll.
        # source: native11589 calendar.factor=3; mass below is unused mock data.
        initial = {"screen": "map", "paused": True, "brake": False,
                   "calendar": {"factor": 3}, "position": "(42, 32)", "switches": []}
        moving = {**initial, "paused": False, "blocked": False, "switches": []}
        city = {**moving, "screen": "city", "paused": True}
        path = Mock(spec=Path)
        path.stem = "arrival"
        path.read_text.return_value = json.dumps([
            {"cell": [42, 32], "next": [43, 32], "switch": 0}])
        console = Mock(spec=Path)
        console.__truediv__ = Mock(return_value=Mock(
            read_text=Mock(return_value='{"session":{"engine":{"train_mass":100}}}')))
        with patch.object(leg.pilot, "CONSOLE", console), \
             patch.object(leg.pilot, "state", return_value=initial), \
             patch.object(leg, "action", side_effect=lambda label, *args, **kwargs:
                          initial if label == "arrival-regulator" else moving) as action, \
             patch.object(leg, "checkpoint"), \
             patch.object(leg, "fire", return_value=city) as fire, \
             patch.object(leg.time, "sleep"):
            leg.drive(path)
        fire.assert_called_once()
        self.assertEqual(action.call_args.args,
                         ("arrival-stop-screen", [{"key": "F5"}]))

    def test_loaded_lignite_is_cut_while_paused_before_motion(self):
        initial = {"screen": "map", "paused": True, "brake": False,
                   "calendar": {"factor": 3}, "position": "(42, 32)",
                   "switches": [], "lignite_rate": 1, "blocked": False}
        stopped = {**initial, "lignite_rate": 0}
        city = {**stopped, "screen": "city"}
        timeline = []
        path = Mock(spec=Path)
        path.stem = "preflight"
        path.read_text.return_value = json.dumps([{"cell": [42, 32], "next": [43, 32]}])
        console = Mock(spec=Path)
        console.__truediv__ = Mock(return_value=Mock(
            read_text=Mock(return_value='{"session":{"engine":{"train_mass":2208}}}')))

        def action(label, *args, **kwargs):
            timeline.append(label)
            return initial if label.endswith("regulator") else city

        def cut(state, label, mass):
            self.assertTrue(state["paused"])
            timeline.append(label)
            return stopped

        with patch.object(leg.pilot, "CONSOLE", console), \
             patch.object(leg.pilot, "state", return_value=initial), \
             patch.object(leg, "action", side_effect=action), \
             patch.object(leg, "fire", side_effect=cut) as fire, \
             patch.object(leg, "checkpoint"), patch.object(leg.time, "sleep"):
            leg.drive(path, 45)
        fire.assert_called_once()
        self.assertLess(timeline.index("preflight-stop-loaded-lignite"),
                        timeline.index("preflight-drive"))

    def test_forward_constraint_survives_replanning(self):
        path = Mock(spec=Path)
        path.resolve.return_value = "/route.json"
        constraints = path.with_suffix.return_value
        constraints.exists.return_value = True
        constraints.read_text.return_value = '{"forward_only":true}'
        with patch.object(leg.subprocess, "run") as run:
            leg.plan_from_save(path, "40,38")
        self.assertEqual(run.call_args.args[0][-1], "forward-only")

    def test_paused_engine_opens_and_saves_map_before_regulator_or_motion(self):
        # Native30619: closing the victory panel leaves the paused engine room.
        initial = {"screen": "engine", "paused": True}
        mapped = {"screen": "map", "paused": True, "brake": False,
                  "calendar": {"factor": 3}, "position": "(42, 32)",
                  "switches": [], "blocked": False}
        arrived = {**mapped, "paused": False, "position": "(43, 32)"}
        path = Mock(spec=Path)
        path.stem = "engine-entry"
        path.read_text.return_value = json.dumps([{"cell": [42, 32], "next": [43, 32]}])
        console = Mock(spec=Path)
        console.__truediv__ = Mock(return_value=Mock(
            read_text=Mock(return_value='{"session":{"engine":{"train_mass":2208}}}')))

        def observe(label, *args, **kwargs):
            return arrived if label == "observe-engine-entry" else mapped

        with patch.object(leg.pilot, "CONSOLE", console), \
             patch.object(leg.pilot, "state", return_value=initial), \
             patch.object(leg, "action", side_effect=observe) as action, \
             patch.object(leg, "checkpoint"), patch.object(leg.time, "sleep"):
            leg.drive(path, 45)
        first = action.call_args_list[0]
        self.assertEqual(first.args, ("engine-entry-open-map", [{"key": "M"}, {"key": "F5"}]))
        self.assertEqual(first.kwargs, {"expect": {"screen": "map", "paused": True}})
        labels = [call.args[0] for call in action.call_args_list]
        self.assertLess(labels.index("engine-entry-open-map"), labels.index("engine-entry-regulator"))
        self.assertLess(labels.index("engine-entry-open-map"), labels.index("engine-entry-drive"))

    def test_other_starting_screens_are_rejected_without_navigation(self):
        path = Mock(spec=Path)
        path.stem = "rejected-entry"
        path.read_text.return_value = json.dumps([{"cell": [42, 32], "next": [43, 32]}])
        for screen, paused in [("engine", False), ("map", False),
                               ("combat", True), ("city", True)]:
            with self.subTest(screen=screen, paused=paused), \
                 patch.object(leg.pilot, "state", return_value={"screen": screen, "paused": paused}), \
                 patch.object(leg, "action") as action:
                self.assertRaisesRegex(RuntimeError, "paused map", leg.drive, path)
                action.assert_not_called()


class FurnaceCycleFixtures(unittest.TestCase):
    # Native12488: mass2208, heat83, steam32000,19 lignite,0 anthracite.
    def setUp(self):
        self.state = {"heat": 83, "steam": 32000, "speed": 120,
                      "regulator": 120, "lignite": 19, "anthracite": 0,
                      "lignite_rate": 0, "anthracite_rate": 0}
        guard = patch.object(leg.pilot, "send", side_effect=AssertionError("No native inputs"))
        guard.start()
        self.addCleanup(guard.stop)

    def test_full_reserve_coasts_even_without_instantaneous_production(self):
        with patch.object(leg, "action") as action:
            self.assertIs(leg.fire(self.state, "coast", 2208), self.state)
            action.assert_not_called()

    def test_maximum_fire_stops_both_stokers(self):
        state = {**self.state, "heat": 600, "lignite_rate": 1,
                 "anthracite_rate": 2, "anthracite": 500}
        with patch.object(leg, "action") as action:
            leg.fire(state, "cut", 2208)
        action.assert_called_once_with("cut", [{"key": "L"}] * 2 + [{"key": "A"}])

    def test_heating_continues_to_maximum_despite_full_pressure(self):
        state = {**self.state, "heat": 599, "anthracite_rate": 1, "anthracite": 500}
        with patch.object(leg, "action") as action:
            leg.fire(state, "heat", 2208)
            action.assert_not_called()

    def test_cold_high_speed_relights_before_old_1500_threshold(self):
        state = {**self.state, "speed": 300, "regulator": 300, "anthracite": 500}
        reserve = leg.reheating_reserve(state, 2208)
        self.assertGreater(reserve, 1500)
        with patch.object(leg, "action") as action:
            leg.fire({**state, "steam": reserve}, "relight", 2208)
        action.assert_called_once_with("relight", [{"key": "A"}])

    def test_empty_stoker_is_stopped_without_relighting_empty_fuel(self):
        state = {**self.state, "lignite": 0, "lignite_rate": 1, "steam": 32000}
        with patch.object(leg, "action") as action:
            leg.fire(state, "empty", 2208)
        action.assert_called_once_with("empty", [{"key": "L"}] * 2)

    def test_money_is_not_burned_when_anthracite_runs_out(self):
        with patch.object(leg, "action") as action:
            with self.assertRaisesRegex(RuntimeError, "Anthracite required"):
                leg.fire({**self.state, "steam": 1500}, "stop", 2208)
            action.assert_not_called()

    def test_existing_lignite_feeding_is_stopped(self):
        with patch.object(leg, "action") as action:
            leg.fire({**self.state, "lignite_rate": 1}, "protect-money", 2208)
        action.assert_called_once_with("protect-money", [{"key": "L"}] * 2)


if __name__ == "__main__":
    unittest.main()
