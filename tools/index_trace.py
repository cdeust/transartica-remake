"""Index ALIS debug instruction blocks without claiming unexecuted coverage.

Source: maestun/alis commit 19a95afdc07b45d997467806d4dd1bf83c5f8076,
src/alis.c:62-95 (readexec) debug output; runtime.trace observed locally.
Addresses are runtime addresses, never labelled as unpacked-file offsets.
Distinct operand/result text is retained, including taken/untaken branches.
"""

import argparse
from collections import Counter
import hashlib
import json
from pathlib import Path
import re


START = re.compile(
    r"^([\w.]+) \[([0-9a-f]+)\]([0-9a-f]+): ([0-9a-f]{2}): (\w+) ###(.*)$",
    re.IGNORECASE,
)
OPERAND = re.compile(r"^\s+--> \[[0-9a-f]+\][0-9a-f]+:", re.IGNORECASE)


def instruction_blocks(lines):
    """Yield contiguous instruction/operand debug blocks with source line numbers."""
    current = None
    for line_number, raw in enumerate(lines, 1):
        line = raw.rstrip("\r\n")
        match = START.match(line)
        if match:
            if current is not None:
                yield current
            script, debug_address, pc_after_fetch, code, name, details = match.groups()
            current = {
                "script": script, "debug_file_address": debug_address,
                "pc_after_fetch": pc_after_fetch,
                "opcode_address": f"{int(pc_after_fetch, 16) - 1:06x}",
                "opcode": code, "name": name, "details": [details.strip()],
                "line": line_number,
            }
        elif current is not None and OPERAND.match(line):
            current["details"].append(line.strip())
        elif current is not None:
            yield current
            current = None
    if current is not None:
        yield current


def summarize(lines):
    variants = {}
    script_counts = Counter()
    for block in instruction_blocks(lines):
        script_counts[block["script"]] += 1
        key = (block["script"], block["pc_after_fetch"], block["opcode"],
               block["name"], tuple(block["details"]))
        if key not in variants:
            variants[key] = {**block, "count": 0, "first_line": block["line"]}
            del variants[key]["line"]
        variants[key]["count"] += 1
        variants[key]["last_line"] = block["line"]
    return {"instruction_count": sum(script_counts.values()),
            "script_counts": dict(sorted(script_counts.items())),
            "variants": list(variants.values())}


def file_digest(path):
    with path.open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("trace", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    with args.trace.open(encoding="utf-8", errors="strict") as stream:
        result = summarize(stream)
    result["trace_sha256"] = file_digest(args.trace)
    result["limitations"] = [
        "Only executed instructions present in this trace are indexed.",
        "Duplicate instruction text does not imply identical hidden VM state.",
        "Runtime addresses are not unpacked-file offsets.",
    ]
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    print(f"{result['instruction_count']} instructions; {len(result['variants'])} variants")


if __name__ == "__main__":
    main()
