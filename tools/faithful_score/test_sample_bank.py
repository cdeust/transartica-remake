# SPDX-License-Identifier: MIT
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

import numpy as np
from sample_bank import MAPPINGS, Sample, _decode, _trim_sustain, choose_sample, load_bank


class SampleSelection(unittest.TestCase):
    def test_sustain_last_audible_frame_is_retained_and_silence_cannot_fit(self):
        pcm = np.array([[1., 1.], [.25, 0.], [0., 0.], [0., 0.]])
        sample = self.sample("sustain.wav", 4, 100)
        sample.pcm = _trim_sustain(pcm)
        np.testing.assert_array_equal(sample.pcm, pcm[:2])
        self.assertIs(choose_sample([sample], (np.full(2, 100.), np.ones(2))), sample)
        with self.assertRaisesRegex(ValueError, "complete audible source note"):
            choose_sample([sample], (np.full(3, 100.), np.ones(3)))

    def test_sustain_trimming_is_selected_only_for_sustained_families(self):
        for family in MAPPINGS:
            with self.subTest(family=family):
                self.check_family_trim(family)

    def check_family_trim(self, family):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "samples").mkdir()
            (root / "mappings").mkdir()
            (root / "samples/sample.wav").write_bytes(b"source")
            (root / "mappings" / MAPPINGS[family]).write_text("<region>\nsample=sample.wav\npitch_keycenter=69\n")
            sample = self.sample("sample.wav", 4, 440)
            sample.pcm[2:] = 0
            with patch("sample_bank._decode", return_value=sample):
                loaded = load_bank(root, family, 44100)
            self.assertEqual(len(loaded[0].pcm), 4 if family in ("harp", "timpani") else 2)

    @staticmethod
    def sample(name, frames, root):
        return Sample(Path(name), root, np.ones((frames, 2)), 0, 0, 1, "fixture")

    def test_nearest_pitch_must_cover_the_written_duration(self):
        short = self.sample("near.wav", 3, 100)
        sustained = self.sample("far.wav", 6, 80)
        controls = (np.full(5, 100.), np.ones(5))
        self.assertIs(choose_sample([short, sustained], controls), sustained)

    def test_pitch_change_uses_integrated_playback_position(self):
        short = self.sample("near.wav", 4, 100)
        sustained = self.sample("far.wav", 4, 200)
        controls = (np.array([100., 100., 300., 300.]), np.ones(4))
        self.assertIs(choose_sample([short, sustained], controls), sustained)

    def test_exhaustion_during_trailing_silence_is_allowed(self):
        sample = self.sample("near.wav", 2, 100)
        controls = (np.full(5, 100.), np.array([1., 1., 0., 0., 0.]))
        self.assertIs(choose_sample([sample], controls), sample)

    def test_phase_advances_through_silence_before_audible_return(self):
        sample = self.sample("near.wav", 2, 100)
        controls = (np.full(5, 100.), np.array([1., 0., 0., 0., 1.]))
        with self.assertRaisesRegex(ValueError, "complete audible source note"):
            choose_sample([sample], controls)

    def test_only_audible_pitch_guides_timbre_selection(self):
        low, high = self.sample("low.wav", 31, 100), self.sample("high.wav", 31, 1000)
        controls = (np.array([1000., 1000., 1000., 100.]), np.array([0., 0., 0., 1.]))
        self.assertIs(choose_sample([low, high], controls), low)

    def test_no_recording_long_enough_is_an_explicit_failure(self):
        with self.assertRaisesRegex(ValueError, "complete audible source note"):
            choose_sample([self.sample("short.wav", 2, 100)], (np.full(4, 100.), np.ones(4)))

    def test_trimmed_zero_prefix_cannot_extend_available_duration(self):
        pcm = np.array([[0., 0.], [0., 0.], [1., 1.], [1., 1.]], dtype="<f4")
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "recording.wav"
            path.write_bytes(b"source-wave")
            with patch("sample_bank.subprocess.check_output", return_value=pcm.tobytes()):
                sample = _decode(path, "pitch_keycenter=69", "", 44100)
            self.assertEqual(len(sample.pcm), 2)
            with self.assertRaisesRegex(ValueError, "complete audible source note"):
                choose_sample([sample], (np.full(3, 440.), np.ones(3)))

    def test_invalid_controls_are_rejected(self):
        invalid = [(np.ones(2), np.ones(1)), (np.array([np.nan]), np.ones(1)),
                   (np.array([-1.]), np.ones(1)), (np.zeros(1), np.ones(1)),
                   (np.ones(1), np.zeros(1)), (np.ones(1), np.array([np.inf]))]
        for controls in invalid:
            with self.subTest(controls=controls), self.assertRaises(ValueError):
                choose_sample([self.sample("sample.wav", 2, 100)], controls)


if __name__ == "__main__":
    unittest.main()
