#!/usr/bin/env python3
"""MIT. Replace four private looping scores using source sample boundaries.

The original attack plays once; subsequent repeats use the captured second
cycle. WAV source is unchanged native ALIS mono signed16 PCM at44100Hz.
"""
import argparse
import hashlib
import json
from pathlib import Path
import struct
import wave

KEYS = ['bojeu-0', 'bojeu-1', 'bojeu2-0', 'bopres-0']


def prepare(captures, manifest):
    replacements = []
    for key in KEYS:
        metadata = json.loads((captures / (key + '.json')).read_text())
        log = (captures / (key + '.log')).read_text()
        raw = (captures / (key + '.raw')).read_bytes()
        if 'CAPTURE_COMPLETE: two original cycles' not in log or 'Releasing ALIS VM memory' not in log:
            raise ValueError(key + ': missing native completion/shutdown')
        if metadata.get('hz') != 44100 or metadata.get('channels') != 1 or metadata.get('attack_remaining') != 0:
            raise ValueError(key + ': source format/attack differs')
        first, last = metadata['loop_begin'], metadata['loop_end']
        if not 0 < first < last <= len(raw) // 2:
            raise ValueError(key + ': invalid original sample boundaries')
        samples = struct.unpack('<' + 'h' * (len(raw) // 2), raw)
        leading = next((index for index, value in enumerate(samples) if value), None)
        if leading is None or leading >= first or not any(samples[first:last]):
            raise ValueError(key + ': silent attack or second cycle')
        entry = manifest['tracks'][key].copy()
        pcm = raw[leading * 2:last * 2]
        entry.update(loop_begin=first-leading, loop_end=last-leading,
                     leading_zero_samples=leading, raw_loop_begin=first, raw_loop_end=last,
                     raw_sha256=hashlib.sha256(raw).hexdigest(), sha256=hashlib.sha256(pcm).hexdigest())
        entry['capture_seconds'] = len(pcm) / (44100 * 2)
        entry['loop_seconds'] = (last-first) / 44100
        entry['completion'] = 'Two original order-zero wraps, sample-boundary observer, attack_remaining=0.'
        entry['capture_limit'] = 'Native ALIS host mixer. Original first attack retained once; second source cycle loops. Not Amiga hardware recording.'
        replacements.append((key, entry, pcm))
    return replacements


def package(captures, output):
    path = output / 'music.json'
    manifest = json.loads(path.read_text())
    replacements = prepare(captures, manifest) # Validate all before replacing files.
    for key, entry, pcm in replacements:
        with wave.open(str(output / entry['file']), 'wb') as wav:
            wav.setnchannels(1)
            wav.setsampwidth(2)
            wav.setframerate(44100)
            wav.writeframes(pcm)
        manifest['tracks'][key] = entry
    path.write_text(json.dumps(manifest, indent=2) + '\n')
    print('PASS: four native second-cycle loops, attack once, all nine source scores retained.')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--captures', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    package(args.captures, args.output)
