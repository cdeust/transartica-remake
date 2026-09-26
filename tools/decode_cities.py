#!/usr/bin/env python3
"""Decode VILLE.FIC records and check them against the map/name oracles.

This is a research decoder, not a game implementation. Its record layout is
backed by main.alis cdim/cfreadb and YODA's `omainc` reads; anchor and tile
normalization are backed by the time.alis city lookup. Labels are extracted
from reachable TEXTEK switch branches using tools/alis_disasm.py.
"""

from __future__ import annotations

import argparse
import csv
import hashlib
import json
import sys
from collections import Counter
from dataclasses import dataclass
from pathlib import Path
from typing import Any

sys.path.insert(0, str(Path(__file__).resolve().parent))
import alis_disasm  # noqa: E402

VILLE_BASE = 0x5FE4  # source: main.alis cdim/cfreadb and YODA indexed reads.
VILLE_STRIDE = 3  # source: main.alis cdim at 0x5fe4; 138-byte payload is 46*3.
MAP_BASE = 0x76  # source: main.alis CARTE.FIC cdim/cfreadb destination.
MAP_WIDTH = 160  # source: main.alis CARTE.FIC read length 0x2da0 and TIME index math.
MAP_HEIGHT = 73  # source: main.alis CARTE dimension metadata and TIME index math.
RECORD_X_ANCHOR_BIAS = 40  # source: TIME city lookup comparison at 0x2872.

# Exact differences between the script's label and the supplied independent
# CSV. These are explicit spelling variants, not fuzzy matching rules.
NAME_ALIASES = {
    "TEMIR TAU": "TEMIR TAN",
    "MONT SAINT-MICHEL": "MONT SAINT-MICHAEL",
    "DJIRGALANF": "DJIRGALANT",
}


@dataclass(frozen=True)
class SourcePaths:
    ville: Path
    carte: Path
    textek: Path
    time: Path
    cities: Path


@dataclass
class DecodeInputs:
    raw_ville: bytes
    raw_carte: bytes
    records: list[dict[str, int]]
    names: list[str]
    categories: list[str]
    text_evidence: dict[str, str]
    footprint: dict[int, tuple[int, int]]
    guide: list[dict[str, Any]]
    file_provenance: dict[str, dict[str, str]]


@dataclass
class RowContext:
    guide_by_name: dict[str, dict[str, Any]]
    categories: list[str]
    raw_carte: bytes
    footprint: dict[int, tuple[int, int]]


def sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def decode_records(raw: bytes, stride: int = VILLE_STRIDE) -> list[dict[str, int]]:
    if stride != 3:
        raise ValueError(f"the observed VILLE stride is 3, got {stride}")
    if len(raw) % stride:
        raise ValueError(f"VILLE payload length {len(raw)} is not divisible by stride {stride}")
    result = []
    for index in range(len(raw) // stride):
        first, second, kind = raw[index * stride:index * stride + stride]
        result.append({
            "index": index,
            "field0_raw": first,
            "field0_signed": first if first < 128 else first - 256,
            "field1": second,
            "field2_raw": kind,
            "field2_abs": abs(kind if kind < 128 else kind - 256),
        })
    return result


def read_cities(path: Path) -> list[dict[str, Any]]:
    with path.open(newline="", encoding="utf-8-sig") as stream:
        reader = csv.DictReader(stream)
        if reader.fieldnames != ["name", "x", "y"]:
            raise ValueError("cities CSV must have exactly the header: name,x,y")
        rows = []
        for line, row in enumerate(reader, start=2):
            try:
                rows.append({"name": row["name"].strip(), "x": int(row["x"]), "y": int(row["y"])})
            except (TypeError, ValueError) as exc:
                raise ValueError(f"invalid city row on CSV line {line}") from exc
    return rows


def _walk(value: Any):
    if isinstance(value, dict):
        yield value
        for child in value.values():
            yield from _walk(child)
    elif isinstance(value, list):
        for child in value:
            yield from _walk(child)


def _read_listing(path: Path, start: int = 0x18) -> dict[str, Any]:
    data = path.read_bytes()
    listing = alis_disasm.disassemble(data, start, 10000, reachable=True)
    if not listing["instructions"]:
        raise ValueError(f"no reachable ALIS instructions decoded from {path}")
    return listing


def _case_label(target: int, by_offset: dict[int, dict[str, Any]]) -> str:
    ins = by_offset.get(target)
    if not ins or ins["name"] != "cstore" or len(ins["args"]) < 1:
        raise ValueError(f"switch target {target:#x} does not store a literal label")
    first = ins["args"][0]
    if not (isinstance(first, dict) and first.get("name") == "oimmp" and first.get("args")):
        raise ValueError(f"switch target {target:#x} label is not a literal string")
    return str(first["args"][0])


def _find_city_switch(instructions: list[dict[str, Any]]) -> dict[str, Any]:
    for ins in instructions:
        if ins["name"] != "cswitch2" or len(ins["args"]) < 3:
            continue
        selector, count, addition = ins["args"][:3]
        if (isinstance(selector, dict) and selector.get("name") == "odirw"
                and selector.get("args") == [192] and count == 45 and addition == 0
                and len(ins["targets"]) == 46):
            return ins
    raise ValueError("could not identify TEXTEK's 46-entry city-name switch")


def _find_category_switch(instructions: list[dict[str, Any]]) -> dict[str, Any]:
    for ins in instructions:
        if ins["name"] != "cswitch2" or len(ins["args"]) < 3:
            continue
        selector, count, addition = ins["args"][:3]
        nodes = list(_walk(selector))
        reads_kind = any(n.get("name") == "omaintc" and n.get("args") == [VILLE_BASE] for n in nodes)
        takes_abs = any(n.get("name") == "oabs" for n in nodes)
        if reads_kind and takes_abs and count == 5 and addition == -1 and len(ins["targets"]) == 6:
            return ins
    raise ValueError("could not identify TEXTEK's six-category VILLE switch")


def extract_text_tables(textek_path: Path) -> tuple[list[str], list[str], dict[str, str]]:
    listing = _read_listing(textek_path)
    insns = listing["instructions"]
    by_offset = {i["offset"]: i for i in insns}
    city_switch = _find_city_switch(insns)
    type_switch = _find_category_switch(insns)
    city_names = [_case_label(target, by_offset) for target in city_switch["targets"]]
    categories = [_case_label(target, by_offset) for target in type_switch["targets"]]
    evidence = {
        "city_name_switch_offset": hex(city_switch["offset"]),
        "city_name_selector": "TEXTEK local word offset 192; switch cases 0..45",
        "category_switch_offset": hex(type_switch["offset"]),
        "category_selector": "absolute value of indexed VILLE byte field 2; cases 1..6",
    }
    return city_names, categories, evidence


def _nested_direct(instruction: dict[str, Any], opcode: str, offset: int) -> bool:
    return any(node.get("name") == opcode and node.get("args") == [offset]
               for node in _walk(instruction.get("args", [])))


def _footprint_offsets(time_path: Path) -> dict[int, tuple[int, int]]:
    insns = _read_listing(time_path)["instructions"]
    switch = _find_footprint_switch(insns)
    by_offset = {i["offset"]: i for i in insns}
    offsets = {code: _case_footprint(target, by_offset)
               for code, target in zip(range(71, 76), switch["targets"])}
    _verify_default_footprint(switch, by_offset)
    offsets[76] = (0, 0)
    expected = {71: (2, 1), 72: (1, 1), 73: (0, 1), 74: (2, 0), 75: (1, 0), 76: (0, 0)}
    if offsets != expected:
        raise ValueError(f"TIME footprint offsets differ from the reviewed ALIS evidence: {offsets}")
    return offsets


def _find_footprint_switch(insns: list[dict[str, Any]]) -> dict[str, Any]:
    for ins in insns:
        is_switch = ins["name"] == "cswitch2" and len(ins["args"]) >= 3
        is_map_codes = _nested_direct(ins, "omaintc", MAP_BASE)
        if is_switch and is_map_codes and ins["args"][1:3] == [4, -71] and len(ins["targets"]) == 5:
            return ins
    raise ValueError("could not identify the six-tile map-footprint switch in TIME")


def _coordinate_adjustment(ins: dict[str, Any] | None) -> tuple[int, int] | None:
    if not ins or ins["name"] != "cadd" or len(ins["args"]) != 2:
        return None
    amount, destination = ins["args"]
    if not isinstance(amount, dict) or not isinstance(destination, dict):
        return None
    if amount.get("name") != "oimmb" or destination.get("name") != "adirb":
        return None
    return int(destination["args"][0]), int(amount["args"][0])


def _case_footprint(target: int, by_offset: dict[int, dict[str, Any]]) -> tuple[int, int]:
    shifts = {48: 0, 49: 0}
    cursor = target
    for _ in range(4):
        ins = by_offset.get(cursor)
        adjustment = _coordinate_adjustment(ins)
        if adjustment:
            slot, amount = adjustment
            if slot in shifts:
                shifts[slot] += amount
            cursor = ins["end"]
            continue
        if not ins or ins["name"].startswith("cjmp"):
            break
        cursor = ins.get("end", cursor + 1)
    return shifts[48], shifts[49]


def _verify_default_footprint(switch, by_offset) -> None:
    default_jump = by_offset.get(switch["end"])
    valid_jump = default_jump and default_jump["name"].startswith("cjmp")
    if not valid_jump or len(default_jump["targets"]) != 1:
        raise ValueError("TIME footprint switch default path could not be verified")
    default_target = by_offset.get(default_jump["targets"][0])
    if not default_target or default_target["name"] != "cstore":
        raise ValueError("TIME footprint switch default does not lead to the record scan")


def _grid_code(carte: bytes, x: int, y: int) -> int | None:
    if not (0 <= x < MAP_WIDTH and 0 <= y < MAP_HEIGHT):
        return None
    return carte[x * MAP_HEIGHT + y]


def decode(paths: SourcePaths) -> dict[str, Any]:
    inputs = _load_inputs(paths)
    rows = _build_rows(inputs)
    return _assemble_result(inputs, rows)


def _load_inputs(paths: SourcePaths) -> DecodeInputs:
    raw_ville, raw_carte = paths.ville.read_bytes(), paths.carte.read_bytes()
    records = decode_records(raw_ville)
    if len(raw_carte) != MAP_WIDTH * MAP_HEIGHT:
        raise ValueError(f"CARTE must contain {MAP_WIDTH * MAP_HEIGHT} bytes, got {len(raw_carte)}")
    names, categories, evidence = extract_text_tables(paths.textek)
    footprint = _footprint_offsets(paths.time)
    guide = read_cities(paths.cities)
    _validate_record_sources(records, names, categories)
    file_provenance = _source_hashes(paths, raw_ville, raw_carte)
    return DecodeInputs(raw_ville, raw_carte, records, names, categories, evidence,
                        footprint, guide, file_provenance)


def _validate_record_sources(records: list[dict[str, int]], names: list[str], categories: list[str]) -> None:
    if len(records) != 46 or len(names) != 46:
        raise ValueError(f"expected 46 records and 46 TEXTEK names, got {len(records)} and {len(names)}")
    if len(categories) != 6:
        raise ValueError(f"expected six categories from TEXTEK, got {len(categories)}")


def _source_hashes(paths: SourcePaths, ville: bytes, carte: bytes) -> dict[str, dict[str, str]]:
    data = {"ville": ville, "carte": carte, "textek": paths.textek.read_bytes(),
            "time": paths.time.read_bytes(), "guide_csv": paths.cities.read_bytes()}
    file_paths = {"ville": paths.ville, "carte": paths.carte, "textek": paths.textek,
                  "time": paths.time, "guide_csv": paths.cities}
    return {name: {"path": str(file_paths[name]), "sha256": sha256(content)}
            for name, content in data.items()}


def _build_rows(inputs: DecodeInputs) -> list[dict[str, Any]]:
    guide_by_name = {city["name"].upper(): city for city in inputs.guide}
    context = RowContext(guide_by_name, inputs.categories, inputs.raw_carte, inputs.footprint)
    # Pairing is cross-checked by 43 independent guide anchors after TIME normalization.
    return [_build_row(record, name, context) for record, name in zip(inputs.records, inputs.names)]


def _build_row(record: dict[str, int], game_name: str, context: RowContext) -> dict[str, Any]:
    anchor = (record["field0_signed"] + RECORD_X_ANCHOR_BIAS, record["field1"])
    oracle_name = NAME_ALIASES.get(game_name, game_name)
    expected = context.guide_by_name.get(oracle_name.upper())
    check = _guide_check(expected, anchor, context) if expected else None
    kind = record["field2_abs"]
    label = context.categories[kind - 1] if 1 <= kind <= len(context.categories) else None
    return {**record, "game_name": game_name,
            "oracle_name": expected["name"] if expected else None,
            "name_alias_applied": bool(expected and expected["name"].upper() != game_name.upper()),
            "anchor_x": anchor[0], "anchor_y": anchor[1],
            "type_label_by_abs_value": label, "guide_check": check}


def _guide_check(expected: dict[str, Any], anchor: tuple[int, int],
                 context: RowContext) -> dict[str, Any]:
    tile = _grid_code(context.raw_carte, expected["x"], expected["y"])
    record_tile = _grid_code(context.raw_carte, *anchor)
    check = {"guide": {"x": expected["x"], "y": expected["y"]},
             "map_code_at_guide": tile, "normalized_anchor": None,
             "record_anchor_matches": False, "record_anchor_map_code": record_tile}
    if tile not in context.footprint:
        check["status"] = "no_footprint_at_guide"
        return check
    dx, dy = context.footprint[tile]
    normalized = {"x": expected["x"] + dx, "y": expected["y"] + dy}
    matches = anchor == (normalized["x"], normalized["y"])
    check.update({"status": "anchor_match" if matches else "anchor_mismatch",
                  "normalized_anchor": normalized, "record_anchor_matches": matches})
    return check


def _assemble_result(inputs: DecodeInputs, rows: list[dict[str, Any]]) -> dict[str, Any]:
    matched, unmatched = _guide_result_sets(rows)
    kind_counts = Counter(r["field2_raw"] for r in rows)
    return {"provenance": _provenance(inputs),
            "category_labels_by_abs_field2": inputs.categories,
            "field2_raw_histogram": {str(key): value for key, value in sorted(kind_counts.items())},
            "record_count": len(rows), "guide_count": len(inputs.guide),
            "guide_anchor_match_count": len(matched),
            "unmatched_guide_records": _unmatched_records(unmatched),
            "non_oracle_records": _non_oracle_records(rows),
            "records": rows}


def _guide_result_sets(rows: list[dict[str, Any]]) -> tuple[list[dict[str, Any]], list[dict[str, Any]]]:
    checked = [row for row in rows if row["guide_check"]]
    matched = [row for row in checked if row["guide_check"]["status"] == "anchor_match"]
    unmatched = [row for row in checked if row["guide_check"]["status"] != "anchor_match"]
    return matched, unmatched


def _unmatched_records(rows: list[dict[str, Any]]) -> list[dict[str, Any]]:
    return [{"index": row["index"], "game_name": row["game_name"], **row["guide_check"]}
            for row in rows]


def _non_oracle_records(rows: list[dict[str, Any]]) -> list[dict[str, Any]]:
    return [_record_summary(row) for row in rows if row["oracle_name"] is None]


def _record_summary(row: dict[str, Any]) -> dict[str, Any]:
    return {key: row[key] for key in ("index", "game_name", "anchor_x", "anchor_y",
                                      "field2_raw", "type_label_by_abs_value")}


def _provenance(inputs: DecodeInputs) -> dict[str, Any]:
    return {"files": inputs.file_provenance,
            "ville_record_layout": "signed(field0), field1, raw(field2); three bytes per record",
            "ville_base_main_offset": hex(VILLE_BASE), "ville_stride": VILLE_STRIDE,
            "anchor_formula": "anchor_x = signed(field0) + 40; anchor_y = field1",
            "footprint_offsets_from_time_bytecode": _serialize_offsets(inputs.footprint),
            "field2_semantics": "abs(raw byte) selects TEXTEK category label; preserve raw sign",
            "record_name_alignment": "positional pairing of 46 records/names; empirically cross-checked against independent guide",
            **inputs.text_evidence, "bytecode_evidence": _bytecode_evidence()}


def _serialize_offsets(footprint: dict[int, tuple[int, int]]) -> dict[str, list[int]]:
    return {str(code): list(offset) for code, offset in sorted(footprint.items())}


def _bytecode_evidence() -> dict[str, Any]:
    return {"ville_loader_main": "cfreadb dest=0x5fe4 len=0x008a; cdim stride=3",
            "yoda_record_access_offsets": ["0x0fc5", "0x0fe3", "0x1001", "0x101f", "0x1049",
                                            "0x1078", "0x1096", "0x10b4", "0x1dc5"],
            "time_lookup": "time.alis city-footprint lookup around 0x2797..0x28d6"}


def write_outputs(result: dict[str, Any], json_path: Path, csv_path: Path) -> None:
    json_path.parent.mkdir(parents=True, exist_ok=True)
    csv_path.parent.mkdir(parents=True, exist_ok=True)
    json_path.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    columns = ["index", "game_name", "oracle_name", "name_alias_applied", "field0_raw",
               "field0_signed", "field1", "field2_raw", "field2_abs",
               "type_label_by_abs_value", "anchor_x", "anchor_y", "guide_status",
               "guide_x", "guide_y", "map_code_at_guide", "normalized_anchor_x",
               "normalized_anchor_y", "record_anchor_matches", "record_anchor_map_code"]
    with csv_path.open("w", newline="", encoding="utf-8") as stream:
        writer = csv.DictWriter(stream, fieldnames=columns)
        writer.writeheader()
        for row in result["records"]:
            check = row["guide_check"] or {}
            guide = check.get("guide", {})
            normalized = check.get("normalized_anchor") or {}
            writer.writerow({**{k: row.get(k) for k in columns},
                             "guide_status": check.get("status"),
                             "guide_x": guide.get("x"), "guide_y": guide.get("y"),
                             "map_code_at_guide": check.get("map_code_at_guide"),
                             "normalized_anchor_x": normalized.get("x"),
                             "normalized_anchor_y": normalized.get("y"),
                             "record_anchor_matches": check.get("record_anchor_matches"),
                             "record_anchor_map_code": check.get("record_anchor_map_code")})


def main() -> None:
    parser = argparse.ArgumentParser(description="Decode VILLE.FIC using ALIS evidence and independent map/name checks.")
    parser.add_argument("--ville", type=Path, required=True, help="raw VILLE.FIC")
    parser.add_argument("--carte", type=Path, required=True, help="raw CARTE.FIC")
    parser.add_argument("--textek", type=Path, required=True, help="unpacked TEXTEK ALIS script")
    parser.add_argument("--time", type=Path, required=True, help="unpacked TIME ALIS script")
    parser.add_argument("--cities", type=Path, required=True, help="independent CSV: name,x,y")
    parser.add_argument("--json-out", type=Path, required=True)
    parser.add_argument("--csv-out", type=Path, required=True)
    args = parser.parse_args()
    try:
        result = decode(SourcePaths(args.ville, args.carte, args.textek, args.time, args.cities))
        write_outputs(result, args.json_out, args.csv_out)
    except (OSError, ValueError, alis_disasm.DecodeError) as exc:
        parser.error(str(exc))
    print(f"decoded {result['record_count']} records; guide anchors matched "
          f"{result['guide_anchor_match_count']}/{result['guide_count']}; outputs: {args.json_out}, {args.csv_out}")


if __name__ == "__main__":
    main()
