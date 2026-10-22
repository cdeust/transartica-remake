# SPDX-License-Identifier: MIT
"""Execute the original Amiga score code, observing its hardware register writes.

No effect implementation lives here. The immutable T.X routine runs in Musashi.
Addresses and harness boundary are documented in AMIGA_PLAYER.md.
"""
from importlib.metadata import version
import json
import hashlib
from pathlib import Path
from amiga_binary import HUNK_BASES, load_hunks, read_executable

DATA, CODE = HUNK_BASES[1:3]
SCORE = 0x600000
SAMPLE_BASE = 0x100000
SAMPLE_STRIDE = 65536
STACK, RETURN = 0xf00000, 0xf01000
CUSTOM = 0xdff0a0


class OriginalPlayer:
    def __init__(self, source: Path, capture: Path, cue: dict):
        from machine68k import CPUType, Machine, Register
        if version('machine68k') != '0.4.0':
            raise ValueError('Original execution requires pinned machine68k 0.4.0')
        self.machine = Machine(CPUType.M68000, 16384)
        self.mem, self.cpu = self.machine.mem, self.machine.cpu
        self.register = Register
        load_hunks(read_executable(source / 'disk1.adf'), self.mem)
        self.end = self.machine.create_execute_end('original routine returned')
        self.trap = self.machine.traps.alloc(lambda opcode, pc: self.end)
        self.mem.w16(RETURN, 0xa000 | self.trap)
        self.mem.w32(0, STACK)
        self.mem.w32(4, RETURN)
        self.cpu.pulse_reset()
        self.events = []
        self.instructions = 0
        self.cpu.set_instr_hook_callback(self._observe)
        self.cue = cue
        try:
            self._load_inputs(source, capture)
            self.call(CODE + 0x1f1a)
            self.events.clear()
        except Exception:
            self.close()
            raise

    def _load_inputs(self, source, capture):
        events = [json.loads(line) for line in (capture / 'score.ndjson').read_text().splitlines()]
        self.start = next(event for event in events if event['event'] == 'start')
        self.instruments = {event['slot']: event for event in events if event['event'] == 'instrument'}
        for slot in range(32):
            self.mem.w32(DATA + 0x45c0 + slot * 8, SAMPLE_BASE + slot * SAMPLE_STRIDE + 16)
        from amiga_samples import reconstruct
        cue_name = next(event['cue'] for event in events if event['event'] == 'header')
        self.instruments, self.sample_blobs = reconstruct(self, source, capture, cue_name)
        for slot, blob in self.sample_blobs.items():
            self.mem.w_block(SAMPLE_BASE + slot * SAMPLE_STRIDE, blob)
        script = (source / 'unpacked' / (self.cue['script'] + '.alis')).read_bytes()
        if hashlib.sha256(script).hexdigest() != self.cue['script_sha256']:
            raise ValueError('Original script SHA mismatch')
        self.mem.w_block(SCORE, script[self.cue['resource_offset']:])
        self.mem.w32(DATA + 0x6e3a, SCORE + 6)
        self.mem.w8(DATA + 0x6e2d, self.start['tempo'])
        self.mem.w8(DATA + 0x6e30, 127)  # MAIN25934, prepare_music_preview.py.
        for offset, key in ((0x6e3e, 'attack'), (0x6e40, 'release'), (0x6e42, 'duration')):
            self.mem.w16(DATA + offset, self.start[key])

    def _observe(self, pc):
        self.instructions += 1
        if pc == CODE + 0x214a:
            order = self.mem.r8(CODE + 0x2734)
            row = self.mem.r16(CODE + 0x2732) // 16
            pattern = self.mem.r8(SCORE + 8 + order)
            raw = bytes(self.mem.r_block(SCORE + 0x8c + pattern * 1024 + row * 16, 16))
            self.events.append({'event': 'row', 'order': order, 'row': row,
                                'pattern': pattern, 'raw': [raw[i:i + 4].hex() for i in range(0, 16, 4)]})
        elif pc == CODE + 0x23d6:  # All initial DMA registers have just been written.
            voice = (self.cpu.r_reg(self.register.A5) - CUSTOM) // 16
            pointer = self.mem.r32(CUSTOM + voice * 16)
            self.events.append({'event': 'trigger', 'voice': voice,
                                'slot': (pointer - SAMPLE_BASE - 16) // SAMPLE_STRIDE,
                                'period': self.mem.r16(CUSTOM + voice * 16 + 6),
                                'source_position': 0,
                                'source_segment_end': self.mem.r16(CUSTOM + voice * 16 + 4) * 2})
        elif pc == CODE + 0x2006:
            self.events.append({'event': 'stop'})
    def call(self, pc, interrupt=False, cycles=1_000_000):
        self.cpu.w_sp(STACK)
        if interrupt:
            # Original IRQ handlers use RTE: provide the real 68000 SR/PC frame.
            self.mem.w16(STACK, self.cpu.r_sr())
            self.mem.w32(STACK + 2, RETURN)
        else:
            self.mem.w32(STACK, RETURN)
        self.cpu.w_pc(pc)
        result = self.machine.execute(cycles)  # Harness watchdog, not a music constant.
        if result.result is not self.end:
            raise RuntimeError(f'Original routine failed to return at {self.cpu.r_pc():x}')

    def tick(self):
        self.events.clear()
        self.call(CODE + 0x1ef0)
        events = self.events.copy()
        voices = []
        for voice in range(4):
            reg = CUSTOM + voice * 16
            state = CODE + 0x273c + voice * 32
            voices.append({'voice': voice, 'period': self.mem.r16(reg + 6),
                           'volume': self.mem.r16(reg + 8),
                           'raw': bytes(self.mem.r_block(state, 4)).hex()})
        # Execute both original CIA timer handlers after capturing initial DMA.
        if any(event['event'] == 'trigger' for event in events):
            self.call(CODE + 0x2254, interrupt=True)
            self.call(CODE + 0x2274, interrupt=True)
        return events, voices

    def close(self):
        self.machine.traps.free(self.trap)
        self.machine.cleanup()
