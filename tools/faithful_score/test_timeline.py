# SPDX-License-Identifier: MIT
import json
from pathlib import Path
import tempfile
import unittest
from timeline import read_timeline, clipped_spans, voice_gain


class TimelineTests(unittest.TestCase):
    def read(self, events):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "trace.ndjson"
            path.write_text("\n".join(json.dumps(e) for e in events))
            return read_timeline(path)

    def trigger(self, frame, serial):
        return dict(event="trigger", frame=frame, voice=0, serial=serial, slot=2)

    def tick(self, frame, serial, frames=10):
        voice = dict(voice=0, serial=serial, rate_q16=32000, volume=64)
        return dict(event="tick", frame=frame, frames=frames, global_volume=64, voices=[voice])

    def test_identical_retriggers_remain_distinct(self):
        timeline = self.read([dict(event="header", rate=44100), self.trigger(0, 1),
                              self.tick(0, 1), self.trigger(10, 2), self.tick(10, 2),
                              dict(event="complete", frame=20)])
        self.assertEqual([(n.serial, n.start, n.end) for n in timeline.notes],
                         [(1, 0, 10), (2, 10, 20)])

    def test_exact_intrabuffer_end_and_stale_end(self):
        timeline = self.read([dict(event="header", rate=44100), self.trigger(0, 1),
                              self.tick(0, 1), dict(event="endvoice", frame=7, voice=0, serial=1),
                              self.trigger(10, 2), self.tick(10, 2),
                              dict(event="endvoice", frame=12, voice=0, serial=1),
                              dict(event="stop", frame=18), dict(event="complete", frame=20)])
        self.assertEqual([(s.start, s.end) for n in timeline.notes for s in clipped_spans(n)],
                         [(0, 7), (10, 18)])

    def test_incomplete_trace_is_rejected(self):
        with self.assertRaises(ValueError):
            self.read([dict(event="header", rate=44100), self.trigger(0, 1)])

    def test_source_gain_uses_integer_volume_rule(self):
        self.assertEqual(voice_gain(64, 64), 1)
        self.assertEqual(voice_gain(0, 64), 0)
        self.assertEqual(voice_gain(32, 64), 31 / 63)


if __name__ == "__main__":
    unittest.main()
