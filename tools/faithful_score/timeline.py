# SPDX-License-Identifier: MIT
"""Preserve ALIS observer triggers and sample-clock voice spans without MIDI rounding."""
from dataclasses import dataclass, field
import json
from pathlib import Path


@dataclass
class Span:
    start: int
    end: int
    rate_q16: int
    gain: float
    rate_numerator: int | None = None
    rate_denominator: int | None = None
    source_position: float | None = None
    source_segment_end: int | None = None

    @property
    def source_step(self) -> float:
        if self.rate_numerator is not None:
            if not self.rate_denominator or self.rate_denominator < 0:
                raise ValueError("Invalid source playback denominator")
            return self.rate_numerator / self.rate_denominator
        return self.rate_q16 / 65536


@dataclass
class Note:
    voice: int
    serial: int
    slot: int
    start: int
    end: int
    spans: list[Span] = field(default_factory=list)


@dataclass
class Timeline:
    header: dict
    notes: list[Note]
    frames: int
    loops: list[int]
    instruments: dict[int, dict]


def voice_gain(volume: int, global_volume: int) -> float:
    # ALIS music_v2.c:f_volume and mv2_soundcal, before PCM mixing.
    return max(0, ((volume * global_volume) >> 6) - 1) / 63


def read_timeline(path: Path) -> Timeline:
    """Trigger serials distinguish repetitions even when pitch and slot match."""
    events = [json.loads(line) for line in path.read_text().splitlines() if line]
    if not events or events[0].get("rate") != 44100:
        raise ValueError("Expected a 44100 Hz source-clock trace")
    complete = [event for event in events if event["event"] == "complete"]
    if len(complete) != 1:
        raise ValueError("Trace must contain exactly one completion event")
    frames = complete[0]["frame"]
    active: dict[int, Note] = {}
    notes: list[Note] = []
    for event in events:
        _consume(event, active, notes, frames)
    if any(note.end < note.start for note in notes):
        raise ValueError("Negative source note duration")
    return Timeline(events[0], notes, frames,
                    [event["frame"] for event in events if event["event"] == "loop"],
                    {event["slot"]: event for event in events if event["event"] == "instrument"})


ActiveNotes = dict[int, Note]


def _consume(event: dict, active: ActiveNotes, notes: list[Note], frames: int) -> None:
    kind = event["event"]
    if kind == "trigger":
        voice = event["voice"]
        if voice in active:
            active[voice].end = min(active[voice].end, event["frame"])
        note = Note(voice, event["serial"], event["slot"], event["frame"], frames)
        active[voice] = note
        notes.append(note)
    elif kind == "endvoice":
        note = active.get(event["voice"])
        if note and note.serial == event["serial"]:
            note.end = min(note.end, event["frame"])
    elif kind == "tick" and event.get("mixed", True):
        for voice in event["voices"]:
            note = active.get(voice["voice"])
            if note and note.serial == voice["serial"]:
                gain = (voice["gain"] if "gain" in voice else
                        voice_gain(voice["volume"], event["global_volume"]))
                note.spans.append(Span(event["frame"], event["frame"] + event["frames"],
                                       voice.get("rate_q16", 0), gain,
                                       voice.get("rate_numerator"), voice.get("rate_denominator"),
                                       voice.get("source_position"), voice.get("source_segment_end")))
    elif kind == "stop":
        for note in active.values():
            note.end = min(note.end, event["frame"])


def clipped_spans(note: Note) -> list[Span]:
    return [Span(max(note.start, s.start), min(note.end, s.end), s.rate_q16, s.gain,
                 s.rate_numerator, s.rate_denominator,
                 None if s.source_position is None else
                 s.source_position + (max(note.start, s.start) - s.start) * s.source_step,
                 s.source_segment_end)
            for s in note.spans if max(note.start, s.start) < min(note.end, s.end)]
