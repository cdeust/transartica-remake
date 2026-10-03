#!/usr/bin/env python3
"""MIT. Replay validated transit-city exits with real inputs and earned saves.

Source: owner3Oct repeatable native actions contract; play_player_leg.py and
plan_player_leg.gd. Stop for every unfamiliar city, dialog or game event.
"""
import argparse
import subprocess
from pathlib import Path

import native_play as pilot
import play_player_leg as leg


def plan(path, target):
    subprocess.run([
        str(pilot.ROOT / ".toolchain/Godot.app/Contents/MacOS/Godot"),
        "--headless", "--path", str(pilot.ROOT / "game"),
        "--script", "res://tests/plan_player_leg.gd", "--",
        str(pilot.CONSOLE / "save.json"), target, str(path.resolve())], check=True)


def continue_travel(path, target, destination, transit):
    while True:
        observed = pilot.state()
        if observed["screen"] == "city":
            city = observed["controls"][0]["text"]
            if city == destination or city not in transit:
                print("PLAYER_STOP", city, flush=True)
                return
            observed = leg.action(path.stem + "-depart-" + city,
                       [{"button": "EXIT"}, {"key": "Space"}, {"key": "F5"}],
                       expect={"paused": True, "blocked": False})
            plan(path, target)
        if observed["screen"] == "engine":
            observed = leg.action(path.stem + "-open-travel-map",
                                 [{"key": "M"}, {"key": "F5"}],
                                 expect={"screen": "map", "paused": True})
            plan(path, target)
        if observed["screen"] != "map":
            print("PLAYER_STOP", observed["screen"], flush=True)
            return
        leg.drive(path)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("route", type=Path)
    parser.add_argument("target")
    parser.add_argument("destination")
    parser.add_argument("--transit", nargs="*", default=[])
    args = parser.parse_args()
    try:
        continue_travel(args.route, args.target, args.destination, args.transit)
    except BaseException:
        observed = leg.action("observe-travel-failure", [])
        if observed["screen"] in ["map", "engine", "combat"]:
            leg.pause(observed, "travel-failure-pause")
        leg.action("travel-failure-save", [{"key": "F5"}])
        raise
