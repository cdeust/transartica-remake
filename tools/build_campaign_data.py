#!/usr/bin/env python3
"""Prepare private ECS campaign data. Never publishes historical dialogue or maps.

Source: MAIN0x7b3–7ea reads HIMA/TRANS/OASIS three-byte records; TIME0x1b9d
consumes them. TEXTEK/TEXTE2K listings contain the exact dialogue strings.
"""
import argparse
import json
import re
from pathlib import Path


def signed_triplets(raw):
    return [[v if v < 128 else v - 256 for v in raw[i:i+3]] for i in range(0, len(raw), 3)]


def build(source):
    data = {'version': 1, 'regions': {}, 'messages': {}, 'epitaphs': {}}
    for name, count in [('hima', 80), ('trans', 92), ('oasis', 9)]:
        raw = (source / 'game-data' / (name + '.fic')).read_bytes()
        if len(raw) != count * 3:
            raise ValueError(f'{name}: wrong ECS record length')
        data['regions'][name] = signed_triplets(raw)
    for script, section in [('textek', 'messages'), ('texte2k', 'epitaphs')]:
        text = (source / 'city-scripts' / (script + '-messages.txt')).read_text()
        # Only first dispatch and explicit ending dispatch; other switches reuse IDs.
        for line in text.splitlines():
            m = re.match(r'\s*(\d+) 0x[0-9a-f]+ (.*)', line)
            if m and m[1] not in data[section]:
                data[section][m[1]] = m[2].split(' / ')
    return data


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(build(args.source), separators=(',', ':')) + '\n')


if __name__ == '__main__':
    main()
