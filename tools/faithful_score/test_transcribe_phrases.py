"""MIT. Reviewed attacks retain their measured uncertainty and source cutoff."""
import unittest

from transcribe_phrases import measured_note


class PhraseTranscriptionTests(unittest.TestCase):
    def component(self, amplitudes):
        points = []
        for index, amplitude in enumerate(amplitudes):
            points.append({'source_frame': 100 * (index + 1),
                           'support_start': 100 * index,
                           'support_end': 100 * (index + 2),
                           'cycles_per_sample': .01931,
                           'amplitude_pcm': amplitude})
        return {'points': points}

    def test_attack_midpoint_preserves_full_measurement_bracket(self):
        note = measured_note(self.component([1, 2, 8, 5]), (150, 350), 500)
        self.assertEqual(note['onset_bounds'], [100, 400])
        self.assertEqual(note['source_start'], 250)
        self.assertEqual(note['source_end'], 500)
        self.assertEqual(note['root_cycles_per_sample'], .01931)
        self.assertEqual(note['gain_curve']['gains'], [0, 0, 0, 1, .625, 0])

    def test_first_note_retains_original_trigger(self):
        note = measured_note(self.component([1, 2, 8, 5]), None, 500)
        self.assertEqual(note['source_start'], 0)
        self.assertEqual(note['onset_bounds'], [0, 0])

    def test_decaying_component_cannot_be_promoted_to_a_new_attack(self):
        with self.assertRaisesRegex(ValueError, 'no measured fundamental rise'):
            measured_note(self.component([8, 5, 2, 1]), (150, 350), 500)

    def test_independent_harmonic_refinement_updates_gate_and_gain_support(self):
        refinement = {'source_start': 150, 'onset_bounds': [100, 200],
                      'basis': 'independently resolved third partial'}
        note = measured_note(self.component([1, 2, 8, 5]), (150, 350), 500, refinement)
        self.assertEqual(note['source_start'], 150)
        self.assertEqual(note['gain_curve']['gains'][2], .25)


if __name__ == '__main__':
    unittest.main()
