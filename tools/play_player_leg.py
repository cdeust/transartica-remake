#!/usr/bin/env python3
"""MIT. Drive an itinerary through actual viewport inputs at live game cadence.

Source: owner3Oct full-player-run contract; decoded rail planner is an itinerary
aid only. No model step, position/resource write or campaign outcome is injected.
"""
import argparse
import json
import subprocess
import time
from pathlib import Path

import native_play as pilot


def position(observed):
    return tuple(map(int, observed["position"].strip("()").split(",")))


def action(label, inputs, **expectations):
    return pilot.send({"label": label, "inputs": inputs, **expectations})


def pause(observed, label):
    # Tactical pause is independent of travel pause (tactical_scene KEY_P).
    if observed["screen"] == "combat" and not observed["combat_paused"]:
        return action(label, [{"key": "P"}], expect={"combat_paused": True})
    if not observed["paused"]:
        return action(label, [{"key": "Space"}], expect={"paused": True})
    return observed


def reheating_reserve(observed, train_mass):
    # TIME0x18a..0x27a, locomotive-rules.md: simulate heating to a production
    # sufficient for the regulator target. Budget consumption conservatively;
    # ignore produced steam and retain TIME's1500 starting reserve.
    resistance = (train_mass + (train_mass // 100) ** 2) // 2
    divisor = 32000 // resistance
    speed = max(observed["speed"], observed["regulator"])
    consumption = (speed + speed * (speed // 10)) // divisor
    heating = 30 * (observed["anthracite"] > 0) # Owner: lignite is money.
    if not heating:
        return 0
    heat, cycles = observed["heat"], 0
    while True:
        previous_heat = heat
        heat += heating
        transfer = heat // 100 + 1
        heat -= transfer
        cycles += 1
        if heat > 100 and transfer * 100 >= consumption:
            return 1500 + consumption * cycles
        if heat <= previous_heat:
            return 32000 # TIME reserve clamp; requested production is unreachable.


def fire(observed, label, train_mass):
    # Owner4Oct: heat to maximum fire, stop feeding, coast on stored energy.
    # EngineRoomArt.FIRE_HEAT_REFERENCE=600 saturates the visible remake fire;
    # this is a visual cutoff, not an asserted original ECS fire-stage decode.
    inputs = []
    feeding = observed["lignite_rate"] + observed["anthracite_rate"] > 0
    coast = observed["heat"] >= 600
    relight = observed["steam"] <= reheating_reserve(observed, train_mass)
    if not observed["anthracite"] and observed["steam"] <= 1500:
        raise RuntimeError("Anthracite required: stop before spending lignite")
    for key, fuel, rate in [("L", "lignite", "lignite_rate"),
                            ("A", "anthracite", "anthracite_rate")]:
        if observed[rate] and (key == "L" or coast or observed[fuel] == 0):
            # TRAIN source command cycles0->1->2->0.
            inputs.extend([{"key": key}] * (3 - observed[rate]))
        elif key == "A" and not feeding and not coast and relight and observed[fuel] > 0:
            inputs.append({"key": key})
    return action(label, inputs) if inputs else observed


def switch_targets(route, cursor):
    targets = {}
    for upcoming in route[cursor:]:
        if upcoming.get("reverse"):
            break
        if upcoming.get("switch") and tuple(upcoming["cell"]) not in targets:
            targets[tuple(upcoming["cell"])] = upcoming["switch"]
    return targets


def switch_needed(route, cursor, observed):
    targets = switch_targets(route, cursor)
    return any(targets.get(tuple(s["cell"]), s["tile"]) != s["tile"]
               for s in observed["switches"])


def select_switches(route, cursor, observed, label):
    if not observed["paused"]:
        raise RuntimeError("Prepare switches while paused, then resume")
    targets = switch_targets(route, cursor)
    for visible in observed["switches"]:
        desired = targets.get(tuple(visible["cell"]))
        if desired is not None and desired != visible["tile"]:
            observed = action(label, [{"switch_cell": visible["cell"]}],
                              expect_switches=[{"cell": visible["cell"], "tile": desired}])
    return observed


def advance_cursor(route, cursor, observed):
    here = position(observed)
    if tuple(route[cursor]["cell"]) == here:
        return cursor
    for index in range(cursor + 1, len(route)):
        if route[index].get("reverse") and tuple(route[index]["cell"]) != here:
            break
        if tuple(route[index]["cell"]) == here:
            return index
    raise RuntimeError(f"Train left itinerary at {here}, cursor{cursor}: {route[cursor]}")


def reverse_here(observed, label):
    observed = pause(observed, label + "-pause")
    return action(label, [{"click": [799, 852]}, {"key": "F5"}],
           expect={"paused": True, "reverse": not observed["reverse"]})


def plan_from_save(path, target):
    # Read actual F5 phase; TIME/YODA reversals can return to the turn phase.
    # Evidence: native9875..9898, phase1->0 made switch23 turn heading6->3.
    command = [
        str(pilot.ROOT / ".toolchain/Godot.app/Contents/MacOS/Godot"),
        "--headless", "--path", str(pilot.ROOT / "game"),
        "--script", "res://tests/plan_player_leg.gd", "--",
        str(pilot.CONSOLE / "save.json"), target, str(path.resolve())]
    # Native13584: a point reversal led the rear back to station49,33.
    # Retain this leg's operator restriction across every switch replan.
    constraints = path.with_suffix(".constraints.json")
    if constraints.exists() and json.loads(constraints.read_text()).get("forward_only"):
        command.append("forward-only")
    subprocess.run(command, check=True)


def checkpoint(path, cursor, observed):
    path.write_text(json.dumps({"cursor": cursor, "state": observed}, indent=2) + "\n")


def replan_and_resume(path, target, observed, label):
    # Native10354..10356: hidden Hima switch appears only on entry. The turn
    # may execute before the input arrives; replan from the actual paused phase.
    pause(observed, label + "-pause")
    observed = action(label + "-save", [{"key": "F5"}], expect={"paused": True})
    plan_from_save(path, target)
    route = json.loads(path.read_text())
    if not route:
        raise RuntimeError("No itinerary from the actual paused save")
    select_switches(route, 0, observed, label + "-switch")
    observed = action(label + "-continue", [{"key": "Space"}],
                      expect={"paused": False})
    return route, observed


def set_regulator(name, regulator):
    # Source: gameplay_input.gd uses15 per arrow press; EngineState caps at300.
    keys = [{"key": "Right"}] * 20 if regulator == 300 else (
        [{"key": "Left"}] * 20 + [{"key": "Right"}] * (regulator // 15))
    return action(name + "-regulator", keys, expect={"regulator": regulator})


def prepare_drive(name, regulator):
    observed = pilot.state()
    # Native30619: a dismissed victory returns to the paused engine room.
    if observed["screen"] == "engine" and observed["paused"]:
        observed = action(name + "-open-map", [{"key": "M"}, {"key": "F5"}],
                          expect={"screen": "map", "paused": True})
    if observed["screen"] != "map" or not observed["paused"]:
        raise RuntimeError("Begin from the actual saved, paused map")
    # Read the earned F5 composition once per leg; never modify that snapshot.
    train_mass = json.loads((pilot.CONSOLE / "save.json").read_text())["session"]["engine"]["train_mass"]
    observed = set_regulator(name, regulator)
    # Native13592 restored an active lignite stoker; cut it while still paused.
    if observed.get("lignite_rate", 0):
        observed = fire(observed, name + "-stop-loaded-lignite", train_mass)
    if observed["brake"]:
        observed = action(name + "-release-brake", [{"key": "B"}], expect={"brake": False})
    # game_calendar.gd FAST_FACTOR: YODA/TEXTEK main+0x2fb8 = 3.
    if observed["calendar"]["factor"] != 3:
        observed = action(name + "-fast-clock", [{"click": [108, 810]}])
        if observed["calendar"]["factor"] != 3:
            raise RuntimeError("Fast clock control was not applied")
    return observed, train_mass


def drive(path, regulator=300):
    route = json.loads(path.read_text())
    if not route:
        raise RuntimeError("No itinerary: keep the native game paused")
    name = path.stem
    target = ",".join(map(str, route[-1]["next"]))
    progress = path.with_suffix(".progress.json")
    cursor = 0
    observed, train_mass = prepare_drive(name, regulator)
    observed = select_switches(route, cursor, observed, name + "-switch")
    action(name + "-drive", [{"key": "Space"}], expect={"paused": False})
    while True:
        time.sleep(0.25) # Observation cadence only; never advances simulation.
        observed = action("observe-" + name, [])
        checkpoint(progress, cursor, observed)
        if position(observed) == tuple(route[-1].get("next", [])):
            pause(observed, name + "-waypoint-pause")
            action(name + "-waypoint-save", [{"key": "F5"}])
            return
        if observed["blocked"] or observed["screen"] not in ["map", "engine"]:
            if observed["screen"] == "combat":
                pause(observed, name + "-combat-pause")
            action(name + "-stop-screen", [{"key": "F5"}])
            return
        cursor = advance_cursor(route, cursor, observed)
        if route[cursor].get("reverse"):
            observed = reverse_here(observed, name + "-reverse")
            route, observed = replan_and_resume(path, target, observed, name + "-reverse")
            cursor = 0
        elif switch_needed(route, cursor, observed):
            route, observed = replan_and_resume(path, target, observed, name + "-prepare")
            cursor = 0
        observed = fire(observed, name + "-stoke", train_mass)
        # Native11589: a normal city arrival can occur during a fuel-key input.
        # Re-check its resulting screen before treating the pause as a failure.
        if observed["blocked"] or observed["screen"] not in ["map", "engine"]:
            if observed["screen"] == "combat":
                pause(observed, name + "-combat-pause")
            action(name + "-stop-screen", [{"key": "F5"}])
            return
        if observed["paused"]:
            raise RuntimeError("Unexpected pause: inspect native window before continuing")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("route", type=Path)
    parser.add_argument("--regulator", type=int, choices=range(15,301,15), default=300,
                        help="Player regulator target; original arrows step by15")
    args = parser.parse_args()
    try:
        drive(args.route, args.regulator)
    except BaseException:
        # Owner requires fixing failures in the same earned party. Stop live
        # travel before diagnosis so failed automation cannot consume its fuel.
        observed = action("observe-pilot-failure", [])
        if observed["screen"] in ["map", "engine", "combat"]:
            pause(observed, "pilot-failure-pause")
        action("pilot-failure-save", [{"key": "F5"}])
        raise
