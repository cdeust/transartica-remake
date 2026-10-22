# SPDX-License-Identifier: MIT
from pathlib import Path
import unittest
import numpy as np
from render_score import RenderContext, calibrated_roots, component_weights, note_controls, render_note, sample_note, verify_render_events
from sample_bank import Sample, midi_hz
from timeline import Note, Span, Timeline


class RenderTests(unittest.TestCase):
    def sample(self, frames=200):
        ramp = np.arange(frames, dtype=float)
        return Sample(Path("test.wav"), 100, np.column_stack((ramp, ramp)), 0, 0, 1, "test")

    def test_frequency_changes_keep_exact_source_frames(self):
        note = Note(0, 1, 0, 10, 14, [Span(10, 12, 32768, 1), Span(12, 14, 65536, .5)])
        hz, gain = note_controls(note, .01, 10000)
        np.testing.assert_array_equal(hz, [50, 50, 100, 100])
        np.testing.assert_array_equal(gain, [1, 1, .5, .5])

    def test_phase_is_continuous_across_pitch_change(self):
        controls = (np.array([100, 100, 200, 200.]), np.ones(4))
        pcm = sample_note(self.sample(), controls, 100)
        np.testing.assert_array_equal(pcm[:, 0], [0, 1, 2, 4])

    def test_original_clock_ratio_avoids_q16_pitch_rounding(self):
        # Original AUDxPER playback is clock / period; source period 428.
        span = Span(0, 2, 0, 1, 3546895, 428 * 44100)
        note = Note(0, 1, 0, 0, 2, [span])
        frequency, _ = note_controls(note, .01, 44100)
        np.testing.assert_allclose(frequency, [.01 * 3546895 / 428] * 2)

    def test_unresolved_pitch_never_becomes_a_guessed_note(self):
        note = Note(0, 1, 3, 0, 2, [Span(0, 2, 65536, 1)])
        context = RenderContext(100, {"3": {"status": "ambiguous"}}, {}, [])
        with self.assertRaisesRegex(ValueError, "Unresolved"):
            render_note(note, context)

    def test_nonfinite_calibration_is_rejected_before_synthesis(self):
        for root in (float("nan"), float("inf"), -1, 0, None):
            with self.subTest(root=root), self.assertRaisesRegex(ValueError, "calibration"):
                calibrated_roots({"root_cycles_per_sample": root})

    def test_short_recording_does_not_silently_truncate_source_note(self):
        with self.assertRaisesRegex(ValueError, "too short"):
            sample_note(self.sample(3), (np.full(8, 100.), np.ones(8)), 100)

    def test_exhausted_recording_during_silence_is_allowed(self):
        gain = np.array([1., 1., 0., 0., 0.])
        pcm = sample_note(self.sample(3), (np.full(5, 100.), gain), 100)
        np.testing.assert_array_equal(pcm[:, 0], [0, 1, 0, 0, 0])

    def test_sound_resuming_after_recording_end_is_rejected(self):
        with self.assertRaisesRegex(ValueError, "too short"):
            sample_note(self.sample(3), (np.full(5, 100.), np.array([1., 0, 0, 0, 1])), 100)

    def test_release_does_not_shorten_written_note(self):
        sample = self.sample()
        sample.release = .8
        pcm = sample_note(sample, (np.full(5, 100.), np.ones(5)), 100)
        np.testing.assert_array_equal(pcm[:, 0], [0, 1, 2, 3, 4])

    def test_author_root_preserves_octave(self):
        self.assertEqual(midi_hz(69), 440)
        self.assertEqual(midi_hz(81), 880)

    def test_measured_chord_balance_is_preserved(self):
        tuning = {"components": [{"weight": 3}, {"weight": 1}]}
        np.testing.assert_array_equal(component_weights(tuning, 2), [.75, .25])
        with self.assertRaisesRegex(ValueError, "missing"):
            component_weights({}, 2)

    def test_event_audit_rejects_omitted_added_or_retimed_notes(self):
        note = Note(0, 1, 0, 2, 4, [Span(2, 4, 65536, 1)])
        timeline = Timeline({}, [note], 4, [], {})
        event = dict(voice=0, serial=1, slot=0, start=2, end=4)
        self.assertEqual(verify_render_events(timeline, [event])["matched_source_triggers"], 1)
        for evidence in ([], [dict(event, serial=2)], [dict(event, end=3)], [dict(event, slot=99)]):
            with self.subTest(evidence=evidence), self.assertRaises(ValueError):
                verify_render_events(timeline, evidence)

    def test_event_audit_rejects_original_sample_substitution(self):
        note = Note(0, 1, 7, 0, 2, [Span(0, 2, 65536, 1)])
        timeline = Timeline({}, [note], 2, [], {7: {"sha256": "source7"}})
        event = dict(voice=0, serial=1, slot=7, start=0, end=2,
                     mode="original_pcm", source_sha256="source7")
        verify_render_events(timeline, [event])
        with self.assertRaisesRegex(ValueError, "substitutes"):
            verify_render_events(timeline, [dict(event, source_sha256="other")])


if __name__ == "__main__":
    unittest.main()
