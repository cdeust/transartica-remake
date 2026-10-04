#!/usr/bin/env python3
"""MIT. Drive an itinerary through actual viewport inputs at live game cadence.

Source: owner3Oct full-player-run contract; decoded rail planner is an itinerary
aid only. No model step, position/resource write or campaign outcome is injected.
"""
import argparse
import json
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


def fire(observed, label, train_mass):
    inputs = []
    # TIME0x215..0x27a: forecast one unfuelled boiler/drive cycle from the
    # observed heat and mass. Start reheating before stored pressure runs out.
    # Evidence: native8645..8650 reached zero reserve under the old1500-only rule.
    resistance = (train_mass + (train_mass // 100) ** 2) // 2
    divisor = 32000 // resistance
    speed = observed["speed"]
    consumption = (speed + speed * (speed // 10)) // divisor
    heat = observed["heat"]
    transfer = heat // 100 + 1 if heat else 0
    production = transfer * 100 if heat - transfer > 100 else 0
    # The1500 starting threshold and32000 clamp belong to EngineState._drive.
    if observed["steam"] <= 1500 or production < consumption:
        for key, fuel, rate in [("L", "lignite", "lignite_rate"),
                                ("A", "anthracite", "anthracite_rate")]:
            if observed[fuel] > 0 and observed[rate] == 0:
                inputs.append({"key": key})
    # TIME0x215..0x27a consumes steam after the32000 boiler clamp.
    # Source: tasks/evidence/locomotive-rules.md and engine_state._drive.
    ceiling = 32000 - consumption
    for key, fuel, rate in [("L", "lignite", "lignite_rate"),
                            ("A", "anthracite", "anthracite_rate")]:
        if (observed["steam"] >= ceiling or observed[fuel] == 0) and observed[rate]:
            inputs.extend([{"key": key}] * (3 - observed[rate]))
    return action(label, inputs) if inputs else observed


def select_switches(route, cursor, observed, label):
    targets = {}
    for upcoming in route[cursor:]:
        if upcoming.get("reverse"):
            break
        if upcoming.get("switch") and tuple(upcoming["cell"]) not in targets:
            targets[tuple(upcoming["cell"])] = upcoming["switch"]
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
    action(label, [{"click": [799, 852]}, {"key": "F5"}],
           expect={"paused": True, "reverse": not observed["reverse"]})
    return action(label + "-continue", [{"key": "Space"}], expect={"paused": False})


def checkpoint(path, cursor, observed):
    path.write_text(json.dumps({"cursor": cursor, "state": observed}, indent=2) + "\n")


def drive(path):
    route = json.loads(path.read_text())
    if not route:
        raise RuntimeError("No itinerary: keep the native game paused")
    name = path.stem
    progress = path.with_suffix(".progress.json")
    cursor = 0
    observed = pilot.state()
    if observed["screen"] != "map" or not observed["paused"]:
        raise RuntimeError("Begin from the actual saved, paused map")
    # Read the earned F5 composition once per leg; never modify that snapshot.
    train_mass = json.loads((pilot.CONSOLE / "save.json").read_text())["session"]["engine"]["train_mass"]
    observed = action(name + "-regulator", [{"key": "Right"}] * 20,
                      expect={"regulator": 300})
    if observed["brake"]:
        observed = action(name + "-release-brake", [{"key": "B"}], expect={"brake": False})
    # game_calendar.gd FAST_FACTOR: YODA/TEXTEK main+0x2fb8 = 3.
    if observed["calendar"]["factor"] != 3:
        observed = action(name + "-fast-clock", [{"click": [108, 810]}])
        if observed["calendar"]["factor"] != 3:
            raise RuntimeError("Fast clock control was not applied")
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
            cursor += 1
        observed = select_switches(route, cursor, observed, name + "-switch")
        observed = fire(observed, name + "-stoke", train_mass)
        if observed["paused"]:
            raise RuntimeError("Unexpected pause: inspect native window before continuing")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("route", type=Path)
    try:
        drive(parser.parse_args().route)
    except BaseException:
        # Owner requires fixing failures in the same earned party. Stop live
        # travel before diagnosis so failed automation cannot consume its fuel.
        observed = action("observe-pilot-failure", [])
        if observed["screen"] in ["map", "engine", "combat"]:
            pause(observed, "pilot-failure-pause")
        action("pilot-failure-save", [{"key": "F5"}])
        raise
