#!/usr/bin/env python3
"""MIT. Repeat real viewport actions; record timing/state, never change game state.

Source: owner3Oct repeatable actions request; native_play_console.gd file protocol.
"""
import argparse
import json
import re
import shutil
import subprocess
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CONSOLE = ROOT / ".cache/native-play"
EVIDENCE = ROOT / "tasks/validation/continuous-play-20261003"


def state():
    return json.loads((CONSOLE / "state.json").read_text())


def resolve_input(action, previous):
    if "button" in action:
        controls = [c for c in previous["controls"] if c["text"] == action["button"]]
        if len(controls) != 1:
            raise RuntimeError(f"Button not unique on screen: {action['button']}")
        x, y, width, height = map(float, re.findall(r"-?\d+(?:\.\d+)?", controls[0]["rect"]))
        return {**action, "click": [x + width / 2, y + height / 2]}
    if "switch_cell" not in action:
        return action
    matching = [s for s in previous["switches"] if s["cell"] == action["switch_cell"]]
    if len(matching) != 1:
        raise RuntimeError(f"Switch not visible: {action['switch_cell']}")
    return {**action, "click": matching[0]["click"]}


def send(step):
    previous = state()
    command = {"id": previous["id"] + 1, "label": step["label"],
               "inputs": [resolve_input(a, previous) for a in step.get("inputs", [])]}
    temporary = CONSOLE / "command.tmp"
    temporary.write_text(json.dumps(command))
    temporary.replace(CONSOLE / "command.json")
    started = time.monotonic()
    # Harness timeout, not a game rule. Failure must never be called acceptance.
    while time.monotonic() - started < 30:
        observed = state()
        if observed["id"] == command["id"] and observed["label"] == command["label"]:
            break
        time.sleep(0.1)
    else:
        raise TimeoutError(f"No captured response: {command}")
    entry = {"utc": time.time(), "seconds": time.monotonic() - started,
             "command": command, "state": observed}
    with (EVIDENCE / "actions.jsonl").open("a") as log:
        log.write(json.dumps(entry) + "\n")
    archive_save(command)
    for field, delta in step.get("expect_delta", {}).items():
        if observed.get(field) != previous.get(field) + delta:
            raise AssertionError(f"{step['label']}: unexpected {field} delta")
    for field, expected in step.get("expect", {}).items():
        if observed.get(field) != expected:
            raise AssertionError(f"{step['label']}: {field}={observed.get(field)!r}, expected {expected!r}")
    for switch in step.get("expect_switches", []):
        matches = [s for s in observed["switches"] if s["cell"] == switch["cell"]]
        if len(matches) != 1 or matches[0]["tile"] != switch["tile"]:
            raise AssertionError(f"{step['label']}: switch not selected: {matches}")
    print(json.dumps({k: observed[k] for k in
                     ("id", "label", "position", "cycles", "speed", "paused", "vehicles")}), flush=True)
    return observed


def archive_save(command):
    # Actual F5 snapshots only, kept private; never reconstruct earned state.
    if any(a.get("key") == "F5" for a in command["inputs"]):
        destination = CONSOLE / "saves"
        destination.mkdir(exist_ok=True)
        shutil.copyfile(CONSOLE / "save.json", destination / f"{command['id']}.json")


def ready(step):
    current = state()
    exact = all(current.get(k) == v for k, v in step.get("wait_until", {}).items())
    minimum = all(current.get(k, -1) >= v for k, v in step.get("wait_min", {}).items())
    return exact and minimum


def await_state(step):
    deadline = time.monotonic() + step.get("timeout_seconds", 60)
    while not ready(step):
        if time.monotonic() >= deadline:
            raise TimeoutError(f"State not reached: {step}")
        time.sleep(1)
        send({"label": "observe-" + step["label"]})


def replay(path):
    scenario = json.loads(Path(path).read_text())
    for step in scenario["steps"]:
        # Times are supplied by the recorded scenario, never acceleration hacks.
        if step.get("delay_seconds", 0):
            time.sleep(step["delay_seconds"])
        if "wait_cycles" in step:
            target = state()["cycles"] + step["wait_cycles"]
            step = {**step, "wait_min": {**step.get("wait_min", {}), "cycles": target}}
        if "wait_until" in step or "wait_min" in step:
            await_state(step)
        send(step)


def wait_for_boot(process):
    deadline = time.monotonic() + 30
    while time.monotonic() < deadline:
        if process.poll() is not None:
            raise RuntimeError("Native game exited before its first captured frame")
        if (CONSOLE / "state.json").exists() and state().get("process_id") == process.pid:
            return
        time.sleep(0.1)
    raise TimeoutError("Native boot frame not captured")


def perform(args):
    if args.replay:
        replay(args.replay)
    else:
        send(json.loads(args.step))


def launch(args):
    log = (EVIDENCE / f"native-launch-{time.time_ns()}.log").open("w")
    process = subprocess.Popen([
        str(ROOT / ".toolchain/Godot.app/Contents/MacOS/Godot"), "--path", "game",
        "--script", "res://tests/native_play_console.gd"], cwd=ROOT, stdout=log, stderr=log)
    try:
        wait_for_boot(process)
        perform(args)
        if args.stay_open:
            print(f"OWNED_NATIVE_PID {process.pid}", flush=True)
            process.wait()
    finally:
        if process.poll() is None:
            process.terminate() # Only this helper's own child, after captures/saves.
        process.wait(timeout=30)
        log.close()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument("--step", help="JSON action with label, inputs and expected states")
    group.add_argument("--replay", help="Scenario JSON; game must already be running")
    parser.add_argument("--launch", action="store_true", help="Own a native game process and wait for its boot frame")
    parser.add_argument("--stay-open", action="store_true", help="Keep this owned native process for subsequent player actions")
    args = parser.parse_args()
    if args.launch:
        launch(args)
    else:
        perform(args)


if __name__ == "__main__":
    main()
