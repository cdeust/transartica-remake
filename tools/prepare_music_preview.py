#!/usr/bin/env python3
"""MIT. Isolated original music preview with source selector and instrument setup.

BOJEU/BOJEU2/BOLIEU use local field13 for selection; the original cinstru loops
and cmusic calls are executed verbatim. MAIN25934 volume is the source setting.
Completion comes from capture_alis_music.c observing the original order wrap.
"""
import argparse
from pathlib import Path
import shutil
import struct


def prepare(source, output, name, selection):
    output.mkdir(parents=True, exist_ok=True)
    body = bytearray((source/'unpacked/main.alis').read_bytes())
    body[6:14] = bytes(8)
    script = (source/('unpacked/'+name+'.alis')).read_bytes()
    identity = struct.unpack_from('>H', script)[0]
    # Original MAIN volume and BOLIEU flags (zero means127).
    program = bytes.fromhex('1e007f06654e6a0001')
    dependencies = [name, 'bolieu'] if name == 'bolost' else [name]
    for dependency in dependencies:
        item = (source/('unpacked/'+dependency+'.alis')).read_bytes()
        idx = struct.unpack_from('>H', item)[0]
        program += bytes([0x45])+struct.pack('>H', idx)+dependency.encode()+b'.AO\0'
        shutil.copyfile(source/('game-data/'+dependency+'.co'), output/(dependency+'.co'))
    program += bytes([0x40])+struct.pack('>H', identity)+bytes.fromhex('1410')
    program += bytes.fromhex('1e00')+bytes([selection])+bytes.fromhex('2a0010000d')
    # Yield forever; observer quits on first complete original order sequence.
    program += bytes.fromhex('4208fd')
    body[24:24+len(program)] = program
    original_header = (source/'game-data/main.co').read_bytes()[6:22]
    (output/'main.co').write_bytes(struct.pack('>IH',len(body)+22,0)+original_header+body)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--script', choices=['bojeu','bojeu2','bolieu','bolost','bopres'], required=True)
    parser.add_argument('--selection', type=int, default=0)
    args = parser.parse_args()
    prepare(args.source,args.output,args.script,args.selection)
