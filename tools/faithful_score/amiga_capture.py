# SPDX-License-Identifier: MIT
"""Capture original 68000 score execution and PAL DMA sample positions.

The hardware register formulas come from T.X and Commodore HRM ch5;
see AMIGA_PLAYER.md. The harness runs one tick per PAL nominal 1/50 second.
"""
import argparse
from fractions import Fraction
import hashlib
import json
from pathlib import Path
from amiga_binary import TX_SHA256
from amiga_player import OriginalPlayer, CODE

RATE = 44100
TICK_FRAMES = RATE // 50
PAL_CLOCK = 3546895  # Commodore HRM chapter5 pp138–139.


def instrument_metadata(item):
    result = item.copy()
    header = bytes.fromhex(item['header_hex'])
    total = int.from_bytes(header[2:6], 'big')
    start = int.from_bytes(header[8:12], 'big')
    end = int.from_bytes(header[12:16], 'big')
    # Original T.X hunk2:0x2334..0x237a, counted in DMA words.
    result.update(initial_pcm_end=2 * ((end if start else total - 16) // 2),
                  loop_pcm_start=start, loop_pcm_length=2 * ((end - start) // 2 + 1),
                  silent_loop=start == end == 0, playback_zero_prefix=4,
                  metadata_source='original T.X hunk2:0x2334..0x237a')
    if result['initial_pcm_end'] > item['pcm_bytes'] or start + result['loop_pcm_length'] > item['pcm_bytes']:
        raise ValueError('Original DMA outside captured payload')
    return result


class DMAState:
    def __init__(self):
        self.serial = 0
        self.slot = -1
        self.position = Fraction(0)
        self.segment_end = 0
        self.ended = True

    def trigger(self, event):
        self.serial += 1
        self.slot = event['slot']
        self.position = Fraction(event['source_position'])
        self.segment_end = event['source_segment_end']
        self.ended = False
        event['serial'] = self.serial

    def span(self, voice, item, frame):
        period = voice['period']
        result = dict(voice, serial=self.serial, slot=self.slot,
                      gain=0 if self.ended else voice['volume'] / 64,
                      rate_numerator=PAL_CLOCK,
                      rate_denominator=period * RATE,
                      source_position=float(self.position), source_segment_end=self.segment_end)
        if self.slot < 0 or not period or self.ended:
            return result, None
        step = Fraction(PAL_CLOCK, period * RATE)
        next_position = self.position + TICK_FRAMES * step
        ended = None
        if next_position >= self.segment_end:
            if item['silent_loop']:
                frames_left = (self.segment_end - self.position) / step
                offset = -(-frames_left.numerator // frames_left.denominator)
                ended = {'event': 'endvoice', 'frame': frame + offset,
                         'voice': voice['voice'], 'serial': self.serial}
                self.ended = True
                next_position = Fraction(0)
            else:
                next_position = item['loop_pcm_start'] + (next_position - self.segment_end) % item['loop_pcm_length']
                self.segment_end = item['loop_pcm_start'] + item['loop_pcm_length']
        self.position = next_position
        return result, ended


def _header(cue, selected):
    files = ('amiga_binary.py', 'amiga_player.py', 'amiga_samples.py', 'amiga_capture.py')
    sources = {name: hashlib.sha256(Path(__file__).with_name(name).read_bytes()).hexdigest()
               for name in files}
    return {'event': 'header', 'version': 2, 'rate': RATE, 'cue': cue,
            'rate_source': 'amiga-pal', 'reader': 'original-68000-musashi',
            'executable_sha256': TX_SHA256, 'machine68k': '0.4.0',
            'script_sha256': selected['script_sha256'], 'resource': selected['resource'],
            'frame_origin': 'first original VBL music tick; row zero occurs on sixth tick',
            'hardware_boundary': 'nominal 50 Hz score ticks; CIA DMA sub-tick latency omitted',
            'sources': sources}


class CaptureRun:
    def __init__(self, player, selected, stream):
        self.player, self.selected, self.stream = player, selected, stream
        self.instruments = {slot: instrument_metadata(item) for slot, item in player.instruments.items()}
        self.states = [DMAState() for _ in range(4)]
        self.cycles = self.previous_order = self.rows = self.triggers = 0
        self.expected_cycles = 0
        self.loops = []

    def emit(self, event):
        self.stream.write(json.dumps(event, separators=(',', ':')) + '\n')

    def row(self, event, frame):
        if event['order'] < self.previous_order:
            self.cycles += 1
            self.loops.append(frame)
            self.emit({'event': 'loop', 'frame': frame, 'cycle': self.cycles})
            if self.cycles == self.expected_cycles:
                return 'cycles'
        self.previous_order = event['order']
        expected = self.selected['patterns'][str(event['pattern'])][event['row']]['words']
        if event['raw'] != [word['raw'] for word in expected]:
            raise ValueError('Original CPU decoded words differ from source audit')
        self.rows += 1
        return None

    def events(self, events, frame):
        done = None
        for event in events:
            event['frame'] = frame
            if event['event'] == 'row' and self.row(event, frame):
                return 'cycles'
            if event['event'] == 'trigger':
                self.states[event['voice']].trigger(event)
                self.triggers += 1
            self.emit(event)
            if event['event'] == 'stop':
                done = 'native-stop'
        return done

    def tick(self, voices, frame):
        spans, endings = [], []
        for voice, state in zip(voices, self.states):
            span, ending = state.span(voice, self.instruments.get(state.slot), frame)
            spans.append(span)
            if ending:
                endings.append(ending)
        self.emit({'event': 'tick', 'frame': frame, 'frames': TICK_FRAMES, 'mixed': True,
                   'global_volume': 64, 'speed': self.player.mem.r8(CODE + 0x2730),
                   'filter_cia_bit': (self.player.mem.r8(0xbfe001) >> 1) & 1, 'voices': spans})
        for ending in endings:
            self.emit(ending)

    def run(self, cue):
        self.expected_cycles = 0 if cue.startswith('bolieu') else 2
        self.emit(_header(cue, self.selected))
        self.emit(dict(self.player.start, frame=0, frames=TICK_FRAMES))
        for item in self.instruments.values():
            self.emit(item)
        # Watchdog only: source duration + attack + release bounds native stop.
        start = self.player.start
        maximum_ticks = start['duration'] + start['attack'] + start['release'] + 2
        for tick in range(maximum_ticks):
            frame = tick * TICK_FRAMES
            events, voices = self.player.tick()
            done = self.events(events, frame)
            if done:
                self.emit({'event': 'complete', 'frame': frame, 'reason': done})
                return frame
            self.tick(voices, frame)
        raise RuntimeError('Original score reached watchdog without semantic completion')


def capture(source, host_capture, cue, output):
    audit = json.loads((host_capture / 'audit.json').read_text())
    selected = audit['cues'][cue]
    prior = host_capture / 'captures' / (cue + '-final')
    output.mkdir(parents=True, exist_ok=False)
    (output / 'samples').mkdir()
    player = OriginalPlayer(source, prior, selected)
    for slot, blob in player.sample_blobs.items():
        (output / 'samples' / f'slot-{slot}.bin').write_bytes(blob)
    try:
        with (output / 'score.ndjson').open('w') as stream:
            run = CaptureRun(player, selected, stream)
            frame = run.run(cue)
    finally:
        player.close()
    manifest = {str(k): v for k, v in run.instruments.items()}
    (output / 'samples' / 'manifest.json').write_text(json.dumps(manifest, indent=2) + '\n')
    receipt = {'cue': cue, 'rows': run.rows, 'triggers': run.triggers, 'loops': run.loops,
               'frames': frame, 'trace_sha256': hashlib.sha256((output / 'score.ndjson').read_bytes()).hexdigest()}
    (output / 'validation.json').write_text(json.dumps(receipt, indent=2) + '\n')
    return receipt


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source', type=Path, required=True)
    parser.add_argument('--host-capture', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--cue', required=True)
    args = parser.parse_args()
    print(json.dumps(capture(args.source, args.host_capture, args.cue, args.output)))


if __name__ == '__main__':
    main()
