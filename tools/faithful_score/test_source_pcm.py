# SPDX-License-Identifier: MIT
import unittest
import numpy as np
from source_pcm import SourcePCM, positions, render_source
from timeline import Note, Span


class OriginalDMA(unittest.TestCase):
    def test_initial_segment_enters_distinct_loop_then_wraps(self):
        # Synthetic four-frame initial segment, three-frame loop [2,5).
        source = SourcePCM(np.arange(6, dtype=float), 2, 3, "fixture")
        span = Span(0, 8, 65536, 1, source_position=2, source_segment_end=4)
        np.testing.assert_array_equal(positions(span, source), [2, 3, 2, 3, 4, 2, 3, 4])

    def test_source_silence_and_tick_cursor_are_preserved(self):
        source = SourcePCM(np.arange(6, dtype=float), 2, 3, "fixture")
        spans = [Span(0, 2, 32768, .5, source_position=1, source_segment_end=4),
                 Span(2, 4, 65536, 0, source_position=2, source_segment_end=4)]
        pcm = render_source(Note(0, 1, 0, 0, 4, spans), source)
        np.testing.assert_array_equal(pcm[:, 0], [.5, .5, 0, 0])

    def test_missing_original_cursor_refuses_invention(self):
        source = SourcePCM(np.zeros(8), 2, 3, "fixture")
        with self.assertRaisesRegex(ValueError, "cursor is required"):
            positions(Span(0, 1, 65536, 1), source)


if __name__ == "__main__":
    unittest.main()
