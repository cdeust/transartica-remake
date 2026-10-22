"""Execute original T.X, including cases missing from the host reader."""
import json
import os
from pathlib import Path
import unittest
from amiga_binary import TX_SHA256, read_executable, load_hunks
from amiga_player import CODE, SCORE, OriginalPlayer


class OriginalPlayerTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.source = Path(os.environ['ALIS_REFERENCE_SOURCE'])
        cls.capture = Path(os.environ['ALIS_CAPTURE_ROOT'])
        cls.audit = json.loads((cls.capture / 'audit.json').read_text())['cues']

    def player(self, cue='bojeu-0'):
        player = OriginalPlayer(self.source, self.capture / 'captures' / (cue + '-final'), self.audit[cue])
        self.addCleanup(player.close)
        return player

    def set_row(self, player, row, words):
        pattern = self.audit['bojeu-0']['orders'][0]
        player.mem.w_block(SCORE + 0x8c + pattern * 1024 + row * 16, bytes.fromhex(''.join(words)))

    def test_rejects_sample_metadata_hash_mismatch(self):
        import tempfile
        import shutil
        with tempfile.TemporaryDirectory() as directory:
            capture = Path(directory)
            original = self.capture / 'captures' / 'bojeu-0-final'
            shutil.copytree(original / 'samples', capture / 'samples')
            trace = (original / 'score.ndjson').read_text()
            events = [json.loads(line) for line in trace.splitlines()]
            next(event for event in events if event['event'] == 'instrument')['sha256'] = 'wrong'
            (capture / 'score.ndjson').write_text('\n'.join(json.dumps(event) for event in events))
            with self.assertRaisesRegex(ValueError, 'instrument SHA'):
                OriginalPlayer(self.source, capture, self.audit['bojeu-0'])

    def test_original_restart_byte_is_observed_without_normalization(self):
        player = self.player('bojeu-1')
        player.mem.w8(CODE + 0x2734, 6)
        player.mem.w16(CODE + 0x2732, 63 * 16)
        player.mem.w8(CODE + 0x2731, 5)
        player.tick()
        self.assertEqual(player.mem.r8(CODE + 0x2734), 127)
        for _ in range(6):
            events, _ = player.tick()
        row = next(event for event in events if event['event'] == 'row')
        self.assertEqual((row['order'], row['pattern'], row['row']), (127, 0, 0))

    def test_original_decompressor_retains_zero_pcm_and_original_lengths(self):
        player = self.player()
        blob = player.sample_blobs[0]
        self.assertEqual(len(blob), 8560)
        self.assertEqual(int.from_bytes(blob[12:16], 'big'), 8516)
        self.assertEqual(blob[16:20], bytes.fromhex('00fff7ff'))
        self.assertEqual(bytes(player.mem.r_block(0x100010, 4)), bytes(4))

    def test_bopres_source_keeps_slot_one_as_resource_one(self):
        player = self.player('bopres-0')
        self.assertEqual(player.instruments[0]['original_resource'], 1)
        self.assertEqual(player.instruments[1]['original_resource'], 1)
        self.assertEqual(player.instruments[12]['original_resource'], 12)

    def test_original_hunks_reject_changed_bytes(self):
        original = read_executable(self.source / 'disk1.adf')
        with self.assertRaisesRegex(ValueError, 'unreviewed'):
            load_hunks(original[:-1] + bytes([original[-1] ^ 1]), None)

    def test_first_row_is_on_sixth_tick_and_repeated_note_retriggers(self):
        player = self.player()
        self.set_row(player, 0, ['01ac1000', '00000000', '00000000', '00000000'])
        self.set_row(player, 1, ['01ac1000', '00000000', '00000000', '00000000'])
        counts = []
        for tick in range(12):
            events, _ = player.tick()
            counts.extend(tick for event in events if event['event'] == 'trigger')
        self.assertEqual(counts, [5, 11])

    def test_real_vibrato_and_zero_word_clear_effect(self):
        player = self.player()
        self.set_row(player, 0, ['01ac1472', '00000000', '00000000', '00000000'])
        self.set_row(player, 1, ['00000000'] * 4)
        periods = [player.tick()[1][0]['period'] for _ in range(13)]
        self.assertEqual(periods[5:11], [428, 428, 430, 431, 431, 429])
        self.assertEqual(periods[12], 428)

    def test_f00_stops_next_tick_and_mutes_hardware(self):
        player = self.player()
        self.set_row(player, 0, ['01ac1f00', '00000000', '00000000', '00000000'])
        for _ in range(6):
            events, _ = player.tick()
        self.assertFalse(any(event['event'] == 'stop' for event in events))
        events, voices = player.tick()
        self.assertTrue(any(event['event'] == 'stop' for event in events))
        self.assertEqual([voice['volume'] for voice in voices], [0] * 4)

    def test_e_command_changes_actual_cia_bit(self):
        player = self.player()
        self.set_row(player, 0, ['00000e00', '00000000', '00000000', '00000000'])
        self.set_row(player, 1, ['00000e01', '00000000', '00000000', '00000000'])
        for _ in range(6):
            player.tick()
        self.assertEqual(player.mem.r8(0xbfe001) & 2, 0)
        for _ in range(6):
            player.tick()
        self.assertEqual(player.mem.r8(0xbfe001) & 2, 2)

    def test_instrument_only_resets_volume_without_trigger(self):
        player = self.player()
        self.set_row(player, 0, ['01ac1c10', '00000000', '00000000', '00000000'])
        self.set_row(player, 1, ['00001000', '00000000', '00000000', '00000000'])
        for _ in range(6):
            _, voices = player.tick()
        self.assertLess(voices[0]['volume'], 16)
        for _ in range(6):
            events, voices = player.tick()
        self.assertFalse(any(event['event'] == 'trigger' for event in events))
        self.assertEqual(voices[0]['volume'], 63)

class DMAEvidenceTests(unittest.TestCase):
    def test_original_loop_region_excludes_host_offset(self):
        from amiga_capture import instrument_metadata
        item = {'header_hex': '020a00002160010000000c1c00002134', 'pcm_bytes': 8528}
        actual = instrument_metadata(item)
        self.assertEqual((actual['initial_pcm_end'], actual['loop_pcm_start'],
                          actual['loop_pcm_length']), (8500, 3100, 5402))

    def test_silent_loop_closes_voice_at_sample_frame(self):
        from fractions import Fraction
        from amiga_capture import DMAState
        state = DMAState()
        state.trigger({'slot': 0, 'source_position': 0, 'source_segment_end': 100})
        voice = {'voice': 0, 'period': 428, 'volume': 64}
        span, end = state.span(voice, {'silent_loop': True}, 200)
        expected = Fraction(100 * 428 * 44100, 3546895)
        self.assertEqual(end['frame'], 200 - (-expected.numerator // expected.denominator))
        self.assertEqual(span['gain'], 1)
        next_span, _ = state.span(voice, {'silent_loop': True}, 1082)
        self.assertEqual(next_span['gain'], 0)

    def test_loop_wrap_preserves_fractional_position(self):
        from fractions import Fraction
        from amiga_capture import DMAState
        state = DMAState()
        state.trigger({'slot': 0, 'source_position': 0, 'source_segment_end': 100})
        item = {'silent_loop': False, 'loop_pcm_start': 20, 'loop_pcm_length': 80}
        _, end = state.span({'voice': 0, 'period': 428, 'volume': 64}, item, 0)
        self.assertIsNone(end)
        self.assertEqual(state.position, 20 + (Fraction(882 * 3546895, 428 * 44100) - 100) % 80)


if __name__ == '__main__':
    unittest.main()
