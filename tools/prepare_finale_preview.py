#!/usr/bin/env python3
"""MIT. Build an isolated original IFEBO/BOPRES verification fixture.

Only the new fixture is written. Original MAIN provides VM specifications and
screen definitions (MAIN0x84); IFEBO/BOPRES remain byte-for-byte original.
This invokes cinematic scripts directly and is NOT campaign route evidence.
"""
import argparse
from pathlib import Path
import shutil
import struct


def prepare(source, destination):
    destination.mkdir(parents=True, exist_ok=True)
    body = bytearray((source / 'unpacked/main.alis').read_bytes())
    body[6:14] = bytes(8)  # Disable unrelated MAIN callbacks in isolated preview.
    screen = bytes.fromhex('46') + struct.pack('>H', 25954) + bytes([64])
    screen += bytes.fromhex('00000000000000c700000000013f00c700000000000000ffff000100000000ff')
    setup = screen + bytes.fromhex('4e65624765626a0001')
    music = bytes.fromhex('45002b') + b'bopres.AO\0' + bytes.fromhex('40002b1410')
    movie = bytes.fromhex('450024') + b'ifebo.AO\0' + bytes.fromhex('40002414123f44')
    body[0x18:0x18+len(setup+music+movie)] = setup+music+movie
    original_header = (source / 'game-data/main.co').read_bytes()[6:22]
    header = struct.pack('>IH', len(body)+22, 0) + original_header
    (destination / 'main.co').write_bytes(header + body)
    for name in ['bopres', 'ifebo']:
        shutil.copyfile(source / ('game-data/'+name+'.co'), destination / (name+'.co'))


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    prepare(args.source, args.output)
