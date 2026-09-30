#!/usr/bin/env python3
"""MIT. Package nine source-selected native score captures privately.

Acceptance requires source order-wrap/score-stop event, nonzero signed16 PCM,
and native VM shutdown. Remove measured device-open silence preceding first
nonzero sample; preserve the untouched capture hash and trim count in manifest.
"""
import argparse
import hashlib
import json
from pathlib import Path
import struct
import wave

TRACKS = [('bojeu', 0, 13, 32000), ('bojeu', 1, 14, 32000), ('bojeu2', 0, 14, 32000),
          ('bolieu', 0, 10, 1000), ('bolieu', 1, 11, 1000), ('bolieu', 2, 12, 1000),
          ('bolieu', 3, 13, 1000), ('bolost', 0, 0, 10000), ('bopres', 0, 0, 10000)]


def package(captures, output):
    output.mkdir(parents=True, exist_ok=True)
    manifest = {'version': 1, 'tracks': {}}
    for script, selector, resource, duration in TRACKS:
        key = f'{script}-{selector}'
        log = (captures/('music-'+key+'.log')).read_text()
        if 'CAPTURE_COMPLETE:' not in log or 'Releasing ALIS VM memory' not in log:
            raise ValueError(key+': missing native source completion/shutdown evidence')
        raw = (captures/(key+'.raw')).read_bytes()
        samples = struct.unpack('<'+'h'*(len(raw)//2), raw)
        first = next((index for index, value in enumerate(samples) if value), None)
        if first is None:
            raise ValueError(key+': silent capture rejected')
        data = raw[first*2:]
        filename = 'music-'+key+'.wav'
        with wave.open(str(output/filename),'wb') as wav:
            wav.setnchannels(1)
            wav.setsampwidth(2)
            wav.setframerate(44100)
            wav.writeframes(data)
        manifest['tracks'][key] = {'file':filename, 'script':script, 'selector':selector,
                'resource':resource, 'duration_ticks':duration, 'hz':50,
                'cycle':script in ['bojeu','bojeu2','bopres'],
                'capture_seconds':len(raw)/88200, 'leading_zero_samples':first,
                'raw_sha256':hashlib.sha256(raw).hexdigest(), 'sha256':hashlib.sha256(data).hexdigest(),
                'completion':[line for line in log.splitlines() if 'CAPTURE_COMPLETE:' in line][0],
                'capture_limit':'Native ALIS host mixer, SDL callback boundary and first attack retained. Not an original Amiga hardware recording.'}
    (output/'music.json').write_text(json.dumps(manifest,indent=2)+'\n')
    print('PASS: nine native source-selected scores have nonzero PCM and source completion; private WAV manifest written.')


if __name__ == '__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--captures',type=Path,required=True)
    parser.add_argument('--output',type=Path,required=True)
    args=parser.parse_args()
    package(args.captures,args.output)
