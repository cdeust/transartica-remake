#!/usr/bin/env python3
"""MIT. Private ECS sample extraction with source-grounded cue inventory.

ALIS alis.c adresmus: resource-table+12 relative pointer, count+16. opcodes.c
sound(): types1/2 signed8-bit PCM, BE length+2 minus16, payload+16; frequency
operand overrides header+1. audio.c playsample(): freq1..20 otherwise10, kHz.
Historical WAVs and full call datasets must stay in ignored private-data.
"""
import argparse
import hashlib
import json
from pathlib import Path
import struct
import wave
import alis_disasm


def integer(data, offset, kind='i'):
    return struct.unpack_from('>'+kind, data, offset)[0]


def resource(data, index):
    base = integer(data, 14)
    count = integer(data, base+16, 'H')
    if not 0 <= index < count:
        raise ValueError('sound resource index outside original table')
    pointer = base + integer(data, base+12) + index*4
    return pointer + integer(data, pointer)


def export(source, output):
    output.mkdir(parents=True, exist_ok=True)
    manifest = {'version': 1, 'scripts': {}}
    tables = alis_disasm.source_tables()
    for path in sorted((source/'unpacked').glob('*.alis')):
        data = path.read_bytes()
        base = integer(data, 14)
        if base+18 > len(data):
            continue
        count = integer(data, base+16, 'H')
        if not count:
            continue
        samples = {}
        for index in range(count):
            offset = resource(data, index)
            kind = data[offset]
            if kind not in (1, 2):
                continue
            length = integer(data, offset+2, 'I') - 16
            if length <= 0 or offset+16+length > len(data):
                raise ValueError(f'{path.stem}:{index}: invalid PCM length')
            frequency = data[offset+1]
            frequency = frequency if 1 <= frequency <= 20 else 10
            raw = data[offset+16:offset+16+length]
            name = f'{path.stem}-{index}.wav'
            with wave.open(str(output/name), 'wb') as wav:
                wav.setnchannels(1)
                wav.setsampwidth(1)
                wav.setframerate(frequency*1000)
                wav.writeframes(bytes(value ^ 128 for value in raw))
            samples[str(index)] = {'file': name, 'kind': kind, 'frequency_khz': frequency,
                                   'samples': length, 'sha256': hashlib.sha256(raw).hexdigest()}
        reader = alis_disasm.Reader(data, tables)
        instructions, errors = {}, []
        for entry in alis_disasm.header_entries(data)['entries']:
            listing = alis_disasm.walk(reader, entry, 20000, True)
            instructions.update({item['offset']: item for item in listing['instructions']})
            errors += listing['errors']
        cues = [item for item in instructions.values() if item['name'] in
                ['csound', 'cmsound', 'cmusic', 'cmmusic', 'cinstru', 'cdelsound', 'cdelmusic']]
        manifest['scripts'][path.stem] = {'samples': samples, 'cues': cues, 'decode_errors': errors}
    (output/'manifest.json').write_text(json.dumps(manifest, indent=2)+'\n')
    count = sum(len(script['samples']) for script in manifest['scripts'].values())
    print(f'Exported {count} original PCM samples privately; cue operands and remaining decode errors retained.')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    export(args.source, args.output)
