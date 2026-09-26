#!/usr/bin/env python3
"""Decode the observed Transarctica CARTE.FIC byte map for private research.

Evidence: the supplied CARTE.FIC is 11,680 bytes (160 x 73). Inspection of
the ALIS bytecode in source revision 19a95afdc07b45d997467806d4dd1bf83c5f8076
shows target VRAM 0x76 and dimension metadata 73; cfreadb loads 0x2da0 bytes
at 0x76 and the next array metadata starts at 0x2e16, exactly after that
buffer. The inferred column-major interpretation data[x * 73 + y] is
independently cross-checked against villes.csv: 43 of 44 towns have codes
71..76, while Tibesti is at (43,70) with code 0. This does not establish
rail connectivity or the meaning of other tile codes. Ville coordinates are
consumed as given; their source coordinate format remains unknown.

This utility writes local research artifacts only. Keep raw outputs out of
the publishable MIT corpus.
"""

from __future__ import annotations

import argparse
import csv
import hashlib
import html
import json
from pathlib import Path
from typing import Any

# source: observed file size and ALIS dimension metadata, described above.
WIDTH = 160
HEIGHT = 73
SIZE = WIDTH * HEIGHT
# source: observed cross-check against villes.csv, supplied with this research task.
# Codes 71 through 76 are the measured town-code set, not general tile semantics.
TOWN_CODES = set(range(71, 77))
# source: supplied reference observation SHA-256, for provenance comparison only.
REFERENCE_SHA256 = "8e1067619b254d57717348fefedc1b5013eb1d7ba23200a815e36f9b856d811a"


def column_major_to_rows(data: bytes, width: int = WIDTH, height: int = HEIGHT) -> list[list[int]]:
    """Convert x-major bytes to row-major rows, preserving each byte value."""
    expected = width * height
    if len(data) != expected:
        raise ValueError(f"expected {expected} map bytes ({width}x{height}), got {len(data)}")
    return [[data[x * height + y] for x in range(width)] for y in range(height)]


def read_cities(path: Path) -> list[dict[str, Any]]:
    with path.open(newline="", encoding="utf-8-sig") as stream:
        reader = csv.DictReader(stream)
        if reader.fieldnames != ["name", "x", "y"]:
            raise ValueError("cities CSV must have exactly the header: name,x,y")
        cities = []
        for line, row in enumerate(reader, start=2):
            try:
                cities.append({"name": row["name"], "x": int(row["x"]), "y": int(row["y"])})
            except (TypeError, ValueError) as exc:
                raise ValueError(f"invalid city coordinates on CSV line {line}") from exc
    return cities


def validate_cities(cities: list[dict[str, Any]], grid: list[list[int]]) -> dict[str, Any]:
    entries = []
    for city in cities:
        x, y = city["x"], city["y"]
        in_bounds = 0 <= x < WIDTH and 0 <= y < HEIGHT
        code = grid[y][x] if in_bounds else None
        entries.append({**city, "in_bounds": in_bounds, "map_code": code,
                        "town_code_match": code in TOWN_CODES if code is not None else False})
    matches = sum(city["town_code_match"] for city in entries)
    tibesti = next((city for city in entries if city["name"].casefold() == "tibesti"), None)
    return {"town_count": len(entries), "town_code_matches": matches,
            "town_code_match_codes": sorted(TOWN_CODES), "cities": entries,
            "unmatched_tibesti": tibesti if tibesti and not tibesti["town_code_match"] else None}


def _html_document(grid: list[list[int]], validation: dict[str, Any], source_sha: str) -> str:
    codes = sorted({value for row in grid for value in row})
    payload = json.dumps({"grid": grid, "cities": validation["cities"]}, ensure_ascii=False)
    payload = payload.replace("<", "\\u003c").replace(">", "\\u003e").replace("&", "\\u0026")
    legend = " ".join(f'<span><i style="background:{_color(c)}"></i>{c}</span>' for c in codes)
    # source: integer pixel scale chosen as 960 canvas pixels / 160 map columns.
    return f'''<!doctype html><meta charset="utf-8"><meta name="viewport" content="width=device-width">
<title>CARTE.FIC research map</title><style>
body{{font:14px system-ui,sans-serif;margin:18px;color:#18212b}} canvas{{image-rendering:pixelated;border:1px solid #555;max-width:100%;height:auto}}
.legend{{display:flex;flex-wrap:wrap;gap:9px;margin:12px 0}}.legend span{{display:inline-flex;align-items:center;gap:4px}}.legend i{{width:13px;height:13px;display:inline-block;border:1px solid #555}}
#status{{margin:9px 0}} .unmatched{{color:#a20;font-weight:700}} label{{margin-right:10px}}
</style><h1>CARTE.FIC numeric research view</h1>
<p>160 × 73 bytes; inferred column-major layout. Hover reports coordinates and raw code. No rail graph or tile semantics are inferred.</p>
<label>Town <select id="town"><option value="">Choose a town</option></select></label>
<label>Search <input id="search" type="search" placeholder="Town name"></label>
<label><input type="checkbox" id="overlay" checked> Show all CSV town coordinates</label>
<div id="status">Hover over a map cell.</div><canvas id="map" width="960" height="438"></canvas><div class="legend">{legend}</div>
<p>CSV town-code validation: {validation['town_code_matches']} / {validation['town_count']} coordinates contain codes 71–76. {('Tibesti is unmatched from those codes at its supplied CSV coordinate.' if validation['unmatched_tibesti'] else 'Tibesti matched the measured town-code set or is absent from this CSV.')}</p>
<p>Input SHA-256: <code>{html.escape(source_sha)}</code>{' (matches supplied reference)' if source_sha == REFERENCE_SHA256 else ''}</p>
<script>const data={payload}, scale=6, canvas=document.querySelector('#map'), ctx=canvas.getContext('2d');
const colors=new Map([...new Set(data.grid.flat())].map(c=>[c,c===0?'#20242b':`hsl(${{(c*47)%360}} 55% 54%)`]));
const sel=document.querySelector('#town'), search=document.querySelector('#search'), status=document.querySelector('#status'), overlay=document.querySelector('#overlay');
function draw(c){{for(let y=0;y<73;y++)for(let x=0;x<160;x++){{ctx.fillStyle=colors.get(data.grid[y][x]);ctx.fillRect(x*scale,y*scale,scale,scale)}}if(overlay.checked)for(const t of data.cities){{ctx.strokeStyle=t.name.toLowerCase()==='tibesti'&&!t.town_code_match?'#f00':'#fff';ctx.lineWidth=1;ctx.strokeRect(t.x*scale+1,t.y*scale+1,scale-2,scale-2)}}if(c){{ctx.strokeStyle='#ffe600';ctx.lineWidth=2;ctx.strokeRect(c.x*scale,c.y*scale,scale,scale)}}}}
draw();
for(const c of data.cities){{const o=document.createElement('option');o.value=c.name;o.textContent=c.name+(c.name.toLowerCase()==='tibesti'&&!c.town_code_match?' — unmatched (code '+c.map_code+')':'');sel.append(o)}}
function mark(c){{draw(c);if(c){{status.textContent=`${{c.name}}: x=${{c.x}}, y=${{c.y}}, code=${{c.map_code}}`+(c.town_code_match?' (town code match)':' (unmatched town code)');status.className=c.name.toLowerCase()==='tibesti'?'unmatched':''}}}}
function selected(){{return data.cities.find(c=>c.name===sel.value)}}sel.onchange=()=>mark(selected());overlay.onchange=()=>mark(selected());search.oninput=()=>{{const q=search.value.toLowerCase();const c=data.cities.find(v=>v.name.toLowerCase().includes(q));if(c){{sel.value=c.name;mark(c)}}}};
canvas.onmousemove=e=>{{const r=canvas.getBoundingClientRect(),x=Math.floor((e.clientX-r.left)*160/r.width),y=Math.floor((e.clientY-r.top)*73/r.height);if(x>=0&&x<160&&y>=0&&y<73)status.textContent=`x=${{x}}, y=${{y}}, code=${{data.grid[y][x]}}`}};
</script>'''


def _color(code: int) -> str:
    """Choose readable categorical display colors; values do not encode meaning."""
    return "#20242b" if code == 0 else f"hsl({(code * 47) % 360} 55% 54%)"


def decode(input_path: Path, cities_path: Path, output_dir: Path) -> dict[str, Any]:
    raw = input_path.read_bytes()
    grid = column_major_to_rows(raw)
    cities = read_cities(cities_path)
    validation = validate_cities(cities, grid)
    source_sha = hashlib.sha256(raw).hexdigest()
    output_dir.mkdir(parents=True, exist_ok=True)
    result = {"provenance": {"input": str(input_path), "sha256": source_sha,
                             "reference_sha256": REFERENCE_SHA256,
                             "matches_supplied_reference": source_sha == REFERENCE_SHA256,
                             "layout": "inferred column-major; data[x * 73 + y]",
                             "dimensions": {"width": WIDTH, "height": HEIGHT},
                             "source_evidence": "ALIS revision 19a95afdc07b45d997467806d4dd1bf83c5f8076; see module docstring"},
              "grid": grid, "city_validation": validation}
    (output_dir / "map.json").write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    (output_dir / "index.html").write_text(_html_document(grid, validation, source_sha), encoding="utf-8")
    with (output_dir / "city-validation.csv").open("w", newline="", encoding="utf-8") as stream:
        fields = ["name", "x", "y", "in_bounds", "map_code", "town_code_match"]
        writer = csv.DictWriter(stream, fieldnames=fields)
        writer.writeheader()
        writer.writerows(validation["cities"])
    return result


def main() -> None:
    parser = argparse.ArgumentParser(description="Decode a bounded CARTE.FIC research map into JSON and interactive HTML.")
    parser.add_argument("input", type=Path, help="raw CARTE.FIC input")
    parser.add_argument("cities", type=Path, help="CSV with header name,x,y")
    parser.add_argument("output_directory", type=Path, help="directory for map.json and index.html")
    args = parser.parse_args()
    try:
        result = decode(args.input, args.cities, args.output_directory)
    except (OSError, ValueError) as exc:
        parser.error(str(exc))
    print(f"decoded {WIDTH}x{HEIGHT}; validated {result['city_validation']['town_code_matches']}/{result['city_validation']['town_count']} towns; outputs: {args.output_directory}")


if __name__ == "__main__":
    main()
