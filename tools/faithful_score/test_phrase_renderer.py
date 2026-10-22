# SPDX-License-Identifier: MIT
"""Small exact-control probes; no orchestral sample downloads required."""
import copy
from pathlib import Path
from types import SimpleNamespace
import unittest
import numpy as np

from timeline import Note, Span
from source_pcm import SourcePCM
from phrase_renderer import render_phrase


class PhraseRendererTests(unittest.TestCase):
    def setUp(self):
        self.part = dict(source_start=4, source_end=20, root_cycles_per_sample=.125,
                         weight=1, family='harp', onset_bounds=[3, 5], end_bounds=[20, 20],
                         evidence={'measurement': 'fixture'},
                         gain_curve=dict(source_frames=[0, 20], gains=[1, 1]))
        self.context = SimpleNamespace(rate=100, banks={'harp': ['bank']},
            sources={0: SourcePCM(np.zeros(20), 0, 2, 'source')},
            slots={'0': dict(resource_sha256='source', rendering=dict(
                mode='phrase_orchestra', transcription_status='accepted_measured_inference',
                notes=[self.part]))})
        self.calls = []
        self.sample = SimpleNamespace(path=Path('test.wav'), sha256='recording', root_hz=12.5)

    def render(self, note):
        def select(bank, controls):
            self.assertEqual(bank, ['bank'])
            return self.sample
        def synth(sample, controls, rate):
            self.calls.append(tuple(v.copy() for v in controls))
            # A phase ramp demonstrates that rendering starts at internal onset.
            return (np.arange(len(controls[0])) + 1)[:, None] * controls[1][:, None] * np.ones((1, 2))
        return render_phrase(note, self.context, choose_sample=select, sample_note=synth)

    def test_rate_change_moves_onset_and_keeps_pitch_rate(self):
        note = Note(1, 7, 0, 10, 18, [Span(10, 13, 0, .8, 1, 1, 0, 20),
                                     Span(13, 18, 0, .4, 2, 1, 3, 20)])
        pcm, evidence = self.render(note)
        np.testing.assert_array_equal(pcm[:4], 0)
        self.assertEqual(pcm[4, 0], .4)
        np.testing.assert_array_equal(self.calls[0][0], 25)
        self.assertEqual(evidence[0]['rendered_start'], 14)
        self.assertEqual((evidence[0]['start'], evidence[0]['end']), (10, 18))

    def test_curve_and_hardware_gain_multiply_without_normalization(self):
        self.part['source_start'] = 0
        self.part['onset_bounds'] = [0, 0]
        self.part['gain_curve'] = dict(source_frames=[0, 4], gains=[0, 1])
        note = Note(0, 1, 0, 0, 5, [Span(0, 5, 0, .8, 1, 1, 0, 20)])
        self.render(note)
        np.testing.assert_allclose(self.calls[0][1], [0, .2, .4, .6, .8])

    def test_retrigger_clips_gate_and_resets_internal_phase(self):
        note = Note(0, 1, 0, 0, 6, [Span(0, 10, 0, 1, 1, 1, 0, 20)])
        first, evidence = self.render(note)
        again = Note(0, 2, 0, 6, 12, [Span(6, 16, 0, 1, 1, 1, 0, 20)])
        second, later = self.render(again)
        np.testing.assert_array_equal(first, second)
        self.assertEqual(first.shape, (6, 2))
        self.assertEqual(evidence[0]['rendered_end'], 6)
        self.assertEqual(later[0]['rendered_start'], 10)

    def test_before_onset_is_silent_with_gate_evidence(self):
        pcm, evidence = self.render(Note(0, 1, 0, 0, 3, [Span(0, 3, 0, 1, 1, 1, 0, 20)]))
        np.testing.assert_array_equal(pcm, 0)
        self.assertEqual(self.calls, [])
        self.assertIsNone(evidence[0]['rendered_start'])
        self.assertEqual(evidence[0]['end'], 3)

    def test_rejects_unresolved_uncertain_or_malformed_notes(self):
        note = Note(0, 1, 0, 0, 8, [Span(0, 8, 0, 1, 1, 1, 0, 20)])
        original = copy.deepcopy(self.part)
        changes = [dict(onset_bounds=[5, 6]), dict(end_bounds=[19, 19]),
                   dict(root_cycles_per_sample=float('nan')), dict(weight=-1),
                   dict(evidence={}), dict(gain_curve=dict(source_frames=[2, 1], gains=[1, 1]))]
        for change in changes:
            self.part.clear(); self.part.update(original); self.part.update(change)
            with self.subTest(change=change), self.assertRaises(ValueError):
                self.render(note)
        self.part.clear(); self.part.update(original)
        self.context.slots['0']['rendering']['transcription_status'] = 'unresolved'
        with self.assertRaises(ValueError): self.render(note)

    def test_rejects_looped_source_and_missing_dma_cursor(self):
        note = Note(0, 1, 0, 0, 8, [Span(0, 8, 0, 1, 1, 1, None, 20)])
        with self.assertRaises(ValueError): self.render(note)
        note.spans[0].source_position = 0
        self.context.sources[0].loop_start = 2
        with self.assertRaises(ValueError): self.render(note)

    def test_pitch_changes_continue_phase_and_clip_internal_end(self):
        self.part.update(source_start=0, onset_bounds=[0, 0], source_end=7, end_bounds=[7, 7])
        note = Note(0, 1, 0, 0, 6, [Span(0, 3, 0, 1, 1, 1, 0, 20),
                                    Span(3, 6, 0, 1, 2, 1, 3, 20)])
        pcm, evidence = self.render(note)
        np.testing.assert_array_equal(self.calls[0][0], [12.5, 12.5, 12.5, 25, 25])
        self.assertEqual(pcm[3, 0], 4)
        self.assertEqual(pcm[5, 0], 0)
        self.assertEqual(evidence[0]['rendered_end'], 5)

    def test_clipped_span_advances_source_position(self):
        note = Note(0, 1, 0, 12, 17, [Span(10, 18, 0, 1, 1, 1, 0, 20)])
        pcm, evidence = self.render(note)
        np.testing.assert_array_equal(pcm[:2], 0)
        self.assertEqual(pcm[2, 0], 1)
        self.assertEqual(evidence[0]['rendered_start'], 14)

    def test_missing_or_overlapping_span_is_rejected(self):
        for second_start in (2, 4):
            note = Note(0, 1, 0, 0, 8, [Span(0, 3, 0, 1, 1, 1, 0, 20),
                                        Span(second_start, 8, 0, 1, 1, 1, 3, 20)])
            with self.subTest(second_start=second_start), self.assertRaises(ValueError):
                self.render(note)

    def test_weight_sum_and_original_initial_extent_are_required(self):
        note = Note(0, 1, 0, 0, 8, [Span(0, 8, 0, 1, 1, 1, 0, 20)])
        self.part['weight'] = .5
        with self.assertRaises(ValueError): self.render(note)
        self.part['weight'] = 1
        self.context.slots['0']['source_playback'] = {'initial_pcm_end': 16}
        with self.assertRaises(ValueError): self.render(note)

    def test_weights_preserve_measured_relative_component_gain(self):
        self.part['weight'] = .25
        other = copy.deepcopy(self.part)
        other.update(weight=.75, source_start=19, onset_bounds=[19, 19])
        self.context.slots['0']['rendering']['notes'].append(other)
        pcm, _ = self.render(Note(0, 1, 0, 0, 8, [Span(0, 8, 0, .8, 1, 1, 0, 20)]))
        self.assertEqual(pcm[4, 0], .2)

    def test_rejects_wrong_source_hash(self):
        self.context.slots['0']['resource_sha256'] = 'other'
        with self.assertRaises(ValueError):
            self.render(Note(0, 1, 0, 0, 8, [Span(0, 8, 0, 1, 1, 1, 0, 20)]))


if __name__ == '__main__': unittest.main()
