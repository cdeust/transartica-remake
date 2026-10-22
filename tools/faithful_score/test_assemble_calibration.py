"""MIT. The render contract cannot turn uncertainty into a guessed note."""
import unittest

from assemble_calibration import assemble


class AssemblyTests(unittest.TestCase):
    def source(self):
        return {'cues': {'test': {'slots': {'0': {
            'pcm_sha256': 'hash', 'status': 'ambiguous',
            'source_playback': {'initial_pcm_end': 1000},
            'vsco': {'family': 'strings'}}}}}}

    def temporal(self):
        def point(frequency, amplitude):
            return {'cycles_per_sample': frequency, 'amplitude_pcm': amplitude}
        return {'samples': {'hash': {
            'source_frames': 1000,
            'components': [{'points': [point(.02, 10), point(None, 0)]},
                           {'points': [point(.03, 20), point(.03, 5)]}],
            'window_frames': 128, 'frequency_resolution_cycles_per_sample': .01,
            'onset_uncertainty_frames': 64,
            'review': {'family': 'cello', 'reason': 'synthetic evidence oracle'}}}}

    def test_unknown_pitch_requires_explicit_disposition(self):
        with self.assertRaisesRegex(ValueError, 'unresolved source'):
            assemble(self.source(), {'samples': {}}, {}, {})

    def test_temporal_normalization_keeps_nulls_and_relative_amplitudes(self):
        result = assemble(self.source(), self.temporal(), {}, {})
        slot = result['cues']['test']['slots']['0']
        self.assertEqual(slot['status'], 'ambiguous')
        rendering = slot['rendering']
        self.assertEqual(rendering['mode'], 'original_pcm')
        self.assertEqual(rendering['source_mask'], 'entire_original_sample')
        self.assertNotIn('components', rendering)
        first, second = slot['temporal_analysis']['components']
        self.assertIsNone(first['points'][1]['cycles_per_sample'])
        self.assertEqual(first['points'][1]['amplitude_gain'], 0)
        self.assertAlmostEqual(first['points'][0]['amplitude_gain'], 1 / 3)
        self.assertAlmostEqual(second['points'][0]['amplitude_gain'], 2 / 3)
        self.assertAlmostEqual(second['points'][1]['amplitude_gain'], 1 / 6)

    def test_preservation_does_not_reclassify_unknown_sample_as_unpitched(self):
        result = assemble(self.source(), {'samples': {}},
                          {'hash': {'reason': 'unresolved attack'}}, {})
        slot = result['cues']['test']['slots']['0']
        self.assertEqual(slot['status'], 'ambiguous')
        self.assertEqual(slot['rendering']['mode'], 'original_pcm')

    def test_temporal_playback_extent_must_match_source(self):
        temporal = self.temporal()
        temporal['samples']['hash']['source_frames'] = 900
        with self.assertRaisesRegex(ValueError, 'DMA extent'):
            assemble(self.source(), temporal, {}, {})


if __name__ == '__main__':
    unittest.main()
