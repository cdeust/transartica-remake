"""Export TEXTEK message switch 0x84 (ids 1..n, lines split on ' / ') to JSON for the
game's private data. Input: reference-private/city-scripts/textek-messages.txt
(produced from the TEXTEK listing). Output stays private (game/private-data is ignored).
Usage: export_textek.py <textek-messages.txt> <out.json>"""
import json, re, sys

def parse(path):
    messages, active = {}, False
    for raw in open(path, encoding='utf-8'):
        line = raw.rstrip('\n')
        if line.startswith('#'):
            active = line.startswith('# switch at 0x84 ')
            continue
        match = re.match(r'\s*(\d+) 0x[0-9a-f]+ ?(.*)$', line)
        if active and match:
            parts = [p.strip() for p in match.group(2).split(' / ')]
            messages[match.group(1)] = [p for p in parts if p]
    return messages

if __name__ == '__main__':
    data = parse(sys.argv[1])
    json.dump({'source': 'TEXTEK switch 0x84', 'messages': data}, open(sys.argv[2], 'w'), indent=1)
    print(len(data), 'messages')
