"""Export private ECS panel resources; no historical pixels enter public assets."""
import argparse
import json
from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).parent / "claude" / "visuals"))
from alisimg import Script


def export(source, target, palette=44):
    script = Script(str(source))
    resources = {}
    for index in range(script.n):
        kind = script.kind(index)
        if kind < 3:
            kind, width, height, rows = script.pixels(index)
            resources[str(index)] = {"kind": kind, "width": width, "height": height,
                                     "pixels": "".join(format(p, "x") for row in rows for p in row)}
        elif kind == 255:
            resources[str(index)] = {"kind": kind, "parts": script.composite(index)}
    payload = {"version": 1, "palette": script.palette(palette), "resources": resources}
    target.write_text(json.dumps(payload, separators=(",", ":")) + "\n")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", type=Path)
    parser.add_argument("target", type=Path)
    parser.add_argument("--palette", type=int, default=44)
    args = parser.parse_args()
    export(args.source, args.target, args.palette)
