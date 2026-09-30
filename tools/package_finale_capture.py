#!/usr/bin/env python3
"""MIT. Package private original framebuffer evidence and captured SDL audio.

Input capture_alis_frames.c records little-endian width,height,milliseconds and
RGBA pixels. Keep only changed frames. Historical outputs MUST remain private.
Audio specification is verified SDL log: 44100Hz, mono, signed16-bit little-endian.
"""
import argparse
import hashlib
import json
from pathlib import Path
import struct
import wave
import zlib


def chunk(kind, value):
    return struct.pack('>I', len(value)) + kind + value + struct.pack('>I', zlib.crc32(kind+value) & 0xffffffff)


def png(width, height, pixels):
    rows = b''.join(b'\0'+pixels[y*width*4:(y+1)*width*4] for y in range(height))
    return (b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('>IIBBBBB', width, height, 8, 6, 0, 0, 0))
            + chunk(b'IDAT', zlib.compress(rows, 9)) + chunk(b'IEND', b''))


def package(frames, audio, output):
    output.mkdir(parents=True, exist_ok=True)
    previous, changes, count = '', [], 0
    with frames.open('rb') as stream:
        while header := stream.read(12):
            if len(header) != 12:
                raise ValueError('truncated frame header')
            width, height, timestamp = struct.unpack('<III', header)
            if (width, height) != (320, 240):
                raise ValueError('unexpected native ECS framebuffer dimensions')
            pixels = stream.read(width*height*4)
            if len(pixels) != width*height*4:
                raise ValueError('truncated framebuffer')
            digest = hashlib.sha256(pixels).hexdigest()
            count += 1
            if digest != previous:
                name = f'reference-{len(changes):04d}.png'
                (output/name).write_bytes(png(width, height, pixels))
                changes.append({'ms': timestamp, 'file': name, 'sha256': digest})
                previous = digest
    if len(changes) < 2:
        raise ValueError('capture never changed; do not accept black/dummy renderer as proof')
    raw_audio = audio.read_bytes()
    if not any(raw_audio) or len(raw_audio) % 2:
        raise ValueError('empty or invalid native audio capture')
    with wave.open(str(output.parent/'finale.wav'), 'wb') as wav:
        wav.setnchannels(1)
        wav.setsampwidth(2)
        wav.setframerate(44100)
        wav.writeframes(raw_audio)
    manifest = {'version': 1, 'source': 'English ECS IFEBO/BOPRES, isolated original ALIS preview',
                'width': width, 'height': height, 'captured_frames': count, 'frames': changes,
                'audio_sha256': hashlib.sha256(raw_audio).hexdigest(),
                'audio_seconds': len(raw_audio)/88200,
                'timing_limit': 'Framebuffer timestamps start at first render, audio starts at device open. Host VM scheduler duration is not original Amiga hardware proof.'}
    (output/'reference.json').write_text(json.dumps(manifest, indent=2)+'\n')
    print(f'Packaged {len(changes)} changed frames; {manifest["audio_seconds"]:.2f}s original audio.')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--frames', type=Path, required=True)
    parser.add_argument('--audio', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    package(args.frames, args.audio, args.output)
