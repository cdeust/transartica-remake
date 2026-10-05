#!/usr/bin/env python3
"""MIT. Replay validated transit-city exits with real inputs and earned saves.

Source: owner3Oct repeatable native actions contract; play_player_leg.py and
plan_player_leg.gd. Stop for every unfamiliar city, dialog or game event.
"""
import argparse
from pathlib import Path

import native_play as pilot
import play_player_leg as leg


def plan(path, target):
    leg.plan_from_save(path, target)


def continue_travel(path, target, destination, options):
    transit = options["transit"]
    regulator = options["regulator"]
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
        leg.drive(path) if regulator == 300 else leg.drive(path, regulator)
        reached = pilot.state()
        # Native10904: using this city wrapper for a mouth waypoint repeated
        # the completed leg. Stop on the earned paused map instead of resuming.
        if reached["screen"] == "map" and leg.position(reached) == tuple(map(int, target.split(","))):
            print("PLAYER_STOP", "waypoint", target, flush=True)
            return


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("route", type=Path)
    parser.add_argument("target")
    parser.add_argument("destination")
    parser.add_argument("--transit", nargs="*", default=[])
    parser.add_argument("--regulator", type=int, choices=range(15,301,15), default=300,
                        help="Player regulator target; original arrows step by15")
    args = parser.parse_args()
    try:
        continue_travel(args.route, args.target, args.destination,
                        {"transit": args.transit, "regulator": args.regulator})
    except BaseException:
        observed = leg.action("observe-travel-failure", [])
        if observed["screen"] in ["map", "engine", "combat"]:
            leg.pause(observed, "travel-failure-pause")
        leg.action("travel-failure-save", [{"key": "F5"}])
        raise
