"""MIT. Known-waveform oracles for temporal component measurements."""
import unittest

import numpy as np

from temporal_evidence import component_tracks


class TemporalEvidenceTests(unittest.TestCase):
    def test_staggered_components_do_not_become_a_simultaneous_chord(self):
        frames = np.arange(8192)
        pcm = 40 * np.sin(2 * np.pi * .02 * frames)
        pcm[4096:] += 30 * np.sin(2 * np.pi * .034 * frames[4096:])
        result = component_tracks(pcm, [.02, .034])
        first, second = result['components']
        self.assertTrue(all(p['cycles_per_sample'] for p in first['points']))
        before = [p for p in second['points'] if p['support_end'] <= 4096]
        after = [p for p in second['points'] if p['support_start'] >= 4096]
        self.assertTrue(all(p['cycles_per_sample'] is None for p in before))
        self.assertTrue(all(abs(p['cycles_per_sample'] - .034) < 1 / result['window_frames'] for p in after))
        self.assertAlmostEqual(np.mean([p['amplitude_pcm'] for p in after]), 30, delta=1)

    def test_unsupported_seed_stays_null(self):
        pcm = 60 * np.sin(2 * np.pi * .02 * np.arange(8192))
        result = component_tracks(pcm, [.02, .039])
        self.assertTrue(all(p['cycles_per_sample'] is None for p in result['components'][1]['points']))

    def test_absolute_source_coordinates_and_full_tail_coverage(self):
        pcm = 60 * np.sin(2 * np.pi * .0173 * np.arange(2000))
        result = component_tracks(pcm, [.0173], 123)
        points = result['components'][0]['points']
        self.assertEqual(points[0]['support_start'], 123)
        self.assertEqual(points[-1]['support_end'], 2123)
        self.assertTrue(all(abs(p['cycles_per_sample'] - .0173) < 1 / result['window_frames'] for p in points))


if __name__ == '__main__':
    unittest.main()
