"""MIT. Independent sample-pitch and decoded-resource contract checks."""
import hashlib
import json
from pathlib import Path
import tempfile
import unittest

import numpy as np
import calibrate


def tone(cycles, length=8192):
    return np.sin(2 * np.pi * cycles * np.arange(length)) * 60


class CalibrationTests(unittest.TestCase):
    def test_fft_difference_matches_direct_definition(self):
        signal = np.random.default_rng(21).normal(size=127)
        width = len(signal) // 2
        expected = [
            np.sum((signal[:width] - signal[t:t + width]) ** 2)
            for t in range(width)]
        np.testing.assert_allclose(calibrate.difference(signal), expected, atol=1e-10)

    def test_continuous_root_not_rounded_to_note(self):
        measured = calibrate.analyze_pcm(tone(0.01734))
        self.assertEqual(measured['status'], 'accepted')
        self.assertAlmostEqual(measured['root_cycles_per_sample'], 0.01734, places=5)

    def test_missing_fundamental_is_candidate_not_spectral_max(self):
        measured = calibrate.analyze_pcm(tone(0.03125) + tone(0.046875) / 2)
        root = measured['candidates'][0]['cycles_per_sample']
        self.assertAlmostEqual(root, 0.015625, places=5)
        self.assertEqual(measured['status'], 'ambiguous')
        self.assertIsNone(measured['root_cycles_per_sample'])

    def test_noise_and_two_unrelated_tones_not_accepted(self):
        signals = [np.random.default_rng(22).normal(size=8192),
                   tone(0.021) + tone(0.034)]  # source: synthetic fixture tones defined in this test
        for signal in signals:
            with self.subTest(signal=signal[:3]):
                self.assertEqual(calibrate.analyze_pcm(signal)['status'], 'ambiguous')

    def test_pitch_change_across_windows_not_accepted(self):
        signal = np.concatenate((tone(0.02, 4096), tone(0.03, 4096)))
        self.assertEqual(calibrate.analyze_pcm(signal)['status'], 'ambiguous')

    def test_zero_and_short_data_are_explicitly_ambiguous(self):
        for signal in [np.zeros(8192), np.array([1, 2, 3])]:
            self.assertEqual(calibrate.analyze_pcm(signal)['status'], 'ambiguous')

    def test_reviewed_components_require_independent_harmonic_evidence(self):
        signal = tone(0.021) + tone(0.042) / 2 + tone(0.034) + tone(0.068) / 2  # source: synthetic fixture tones defined in this test
        measured = calibrate.analyze_pcm(signal)
        review = {'roots_cycles_per_sample': [0.021, 0.034],  # source: synthetic fixture tones defined in this test
                  'reason': 'synthetic two-tone oracle', 'family': 'strings'}
        calibrated = calibrate.apply_review(measured, review)
        self.assertEqual(calibrated['status'], 'accepted')
        self.assertEqual(calibrated['classification'], 'polyphonic')
        np.testing.assert_allclose(calibrated['roots_cycles_per_sample'],
                                   [0.021, 0.034], atol=1 / len(signal))  # source: synthetic fixture tones defined in this test
        self.assertLess(calibrated['spectral_peak_residual_fraction'], 0.01)

    def test_review_cannot_introduce_absent_notes(self):
        measured = calibrate.analyze_pcm(tone(0.02) + tone(0.04) / 2)
        review = {'roots_cycles_per_sample': [0.02, 0.031],  # source: synthetic fixture tones defined in this test
                  'reason': 'deliberately invalid note', 'family': 'strings'}
        with self.assertRaisesRegex(ValueError, 'component'):
            calibrate.apply_review(measured, review)

    def test_dominant_pure_tone_review_does_not_invent_harmonics(self):
        measured = calibrate.analyze_pcm(tone(.01931))
        review = {'roots_cycles_per_sample': [.01931], 'mode': 'dominant_single_band',
                  'reason': 'known synthetic pure tone', 'family': 'cello'}
        result = calibrate.apply_review(measured, review)
        self.assertTrue(result['components'][0]['dominant_single_band'])
        self.assertTrue(all(not w['harmonics'] for w in result['components'][0]['windows']))

    def test_dominant_review_cannot_select_a_weaker_unrelated_band(self):
        measured = calibrate.analyze_pcm(tone(.01931) + tone(.03521) / 4)
        review = {'roots_cycles_per_sample': [.03521], 'mode': 'dominant_single_band',
                  'reason': 'deliberately wrong dominant root', 'family': 'cello'}
        with self.assertRaisesRegex(ValueError, 'strongest'):
            calibrate.apply_review(measured, review)

    def test_reviewed_missing_fundamental_requires_periodicity_and_partials(self):
        measured = calibrate.analyze_pcm(tone(0.03125) + tone(0.046875) / 2)
        review = {'roots_cycles_per_sample': [0.015625], 'mode': 'periodic_harmonics',  # source: synthetic fixture tones defined in this test
                  'reason': 'synthetic known missing fundamental', 'family': 'horn'}
        calibrated = calibrate.apply_review(measured, review)
        self.assertAlmostEqual(calibrated['root_cycles_per_sample'], 0.015625, places=5)

    def test_contour_tracks_continuous_glide_without_midi_rounding(self):
        frequencies = np.linspace(0.02, 0.03, 8192)
        signal = 60 * np.sin(2 * np.pi * np.cumsum(frequencies))
        contour = calibrate.pitch_contour(signal, 0.02)
        accepted = [point for point in contour if point['cycles_per_sample'] is not None]
        self.assertGreater(len(accepted), len(contour) / 2)
        for point in accepted:
            self.assertAlmostEqual(point['cycles_per_sample'],
                                   frequencies[point['source_frame']], delta=0.001)

    def fixture(self, directory):
        pcm = np.rint(tone(0.02)).astype(np.int8).tobytes()
        header = bytearray(16)
        header[2:6] = (len(pcm) + 16).to_bytes(4, 'big')
        header[8:12] = (256).to_bytes(4, 'big')
        header[12:16] = (4350).to_bytes(4, 'big')
        data = header + pcm
        path = Path(directory) / 'slot-0.bin'
        path.write_bytes(data)
        metadata = {'resource_file': path.name, 'sha256': hashlib.sha256(data).hexdigest(),
                    'payload_sha256': hashlib.sha256(pcm).hexdigest(),
                    'resource_bytes': len(data), 'payload_offset': 16,
                    'pcm_bytes': len(pcm), 'initial_pcm_end': len(pcm) - 16,
                    'loop_pcm_start': 256, 'loop_pcm_length': 4096, 'type': 2}
        return metadata

    def test_payload_hash_and_mixer_loop_region(self):
        with tempfile.TemporaryDirectory() as directory:
            metadata = self.fixture(directory)
            pcm, region = calibrate.load_sample(Path(directory), metadata)
            self.assertEqual(len(pcm), metadata['pcm_bytes'])
            self.assertEqual(region, {'start': 256, 'end': 4352, 'kind': 'original_paula_loop'})
            self.assertTrue(np.all(pcm[:4] == 0))
            metadata['payload_sha256'] = '0' * 64
            with self.assertRaisesRegex(ValueError, 'hash'):
                calibrate.load_sample(Path(directory), metadata)

    def test_reject_path_escape_and_invalid_loop(self):
        with tempfile.TemporaryDirectory() as directory:
            metadata = self.fixture(directory)
            metadata['resource_file'] = '../slot-0.bin'
            with self.assertRaises(ValueError):
                calibrate.load_sample(Path(directory), metadata)
            metadata['resource_file'] = 'slot-0.bin'
            data = bytearray((Path(directory) / metadata['resource_file']).read_bytes())
            data[12:16] = (metadata['pcm_bytes'] + 1).to_bytes(4, 'big')
            with self.assertRaisesRegex(ValueError, 'DMA'):
                calibrate.original_playback(data)

    def test_original_paula_layout_matches_observed_bojeu_header(self):
        data = bytes.fromhex('020a00002170010000000c1c00002144') + bytes(8560 - 16)
        result = calibrate.original_playback(data)
        self.assertEqual(result['initial_pcm_end'], 8516)
        self.assertEqual(result['loop_pcm_start'], 3100)
        self.assertEqual(result['loop_pcm_length'], 5418)

    def test_final_capture_directory_keeps_canonical_cue_identity(self):
        with tempfile.TemporaryDirectory() as directory:
            captures = Path(directory)
            sample_dir = captures / 'test-final' / 'samples'
            sample_dir.mkdir(parents=True)
            metadata = self.fixture(sample_dir)
            (sample_dir / 'manifest.json').write_text(json.dumps({'0': metadata}))
            trace = [{'event': 'header', 'cue': 'test'},
                     {'event': 'trigger', 'slot': 0}, {'event': 'complete'}]
            (sample_dir.parent / 'score.ndjson').write_text(
                '\n'.join(json.dumps(event) for event in trace))
            result = calibrate.calibrate_captures(captures)
            self.assertEqual(list(result['cues']), ['test'])

    def test_instrument_only_word_is_calibrated_without_host_trigger(self):
        with tempfile.TemporaryDirectory() as directory:
            trace = Path(directory) / 'score.ndjson'
            trace.write_text('\n'.join(json.dumps(event) for event in [
                {'event': 'row', 'raw': ['00002000', '10000000', '00000000', '00000e01']},
                {'event': 'complete'}]))
            self.assertEqual(calibrate.used_slots(trace), {'1', '15'})


if __name__ == '__main__':
    unittest.main()
