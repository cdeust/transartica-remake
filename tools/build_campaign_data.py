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
    data = {'version': 1, 'regions': {}, 'messages': {}, 'documents': {}, 'epitaphs': {}}
    for name, count in [('hima', 80), ('trans', 92), ('oasis', 9)]:
        raw = (source / 'game-data' / (name + '.fic')).read_bytes()
        if len(raw) != count * 3:
            raise ValueError(f'{name}: wrong ECS record length')
        data['regions'][name] = signed_triplets(raw)
    for script, section in [('textek', 'messages'), ('texte2k', 'documents')]:
        text = (source / 'city-scripts' / (script + '-messages.txt')).read_text()
        # Only first dispatch and explicit ending dispatch; other switches reuse IDs.
        for line in text.splitlines():
            if script == 'texte2k' and line.startswith('# switch at 0x25f0'):
                break
            m = re.match(r'\s*(\d+) 0x[0-9a-f]+ (.*)', line)
            if m and m[1] not in data[section]:
                data[section][m[1]] = m[2].split(' / ')
    listing = json.loads((source / 'observations/listings-20260927/texte2k.json').read_text())
    instructions = sorted(listing['instructions'], key=lambda item: item['offset'])
    first = [0x26e6, 0x2798, 0x2836, 0x28df, 0x2973, 0x2a1f]
    last = [0x2b12, 0x2b55, 0x2bad, 0x2bcc, 0x2c0d, 0x2c59]
    common = strings_in(instructions, 0x2c83, 0x2cd5) + strings_in(instructions, 0x2cfe, 0x2d41)
    for index in range(6):
        start_end = first[index + 1] if index < 5 else 0x2afc
        tail_end = last[index + 1] if index < 5 else 0x2c83
        data['epitaphs'][str(100 + index)] = (
            strings_in(instructions, first[index], start_end)
            + strings_in(instructions, last[index], tail_end) + common)
    listing = json.loads((source / 'observations/listings-20260927/textek.json').read_text())
    data['report_phrases'] = report_phrases(listing['instructions'])
    phrases = {item['offset']: literals(item) for item in listing['instructions']
               if 0x48cc <= item['offset'] < 0x49fc and literals(item)}
    data['mine_bulletin'] = {
        'title_closed': phrases[0x48e3][0], 'title_open': phrases[0x4901][0],
        'ore_anthracite': phrases[0x492f][0], 'ore_lignite': phrases[0x4951][0],
        'coordinates': phrases[0x496c][0] + '%s' + phrases[0x499d][0] + '%s',
        'date': phrases[0x49cc][0] + '%s' + phrases[0x49cc][1]}
    return data


def report_phrases(instructions):
    return {str(item['offset']): literals(item) for item in instructions
            if 0x27f4 <= item['offset'] < 0x2bf0 and literals(item)}


def literals(value):
    if isinstance(value, dict):
        if value.get('name') == 'oimmp':
            return value['args']
        return [text for nested in value.values() for text in literals(nested)]
    if isinstance(value, list):
        return [text for nested in value for text in literals(nested)]
    return []


def strings_in(instructions, begin, end):
    # TEXTE2K cstore string operands, excluding adjacent unrelated dispatches.
    result = []
    for item in instructions:
        if begin <= item['offset'] < end and item['name'] == 'cstore':
            operand = item['args'][0]
            if operand['name'] == 'oimmp':
                result.append(operand['args'][0])
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(build(args.source), separators=(',', ':')) + '\n')


if __name__ == '__main__':
    main()
