# SPDX-License-Identifier: MIT
"""Render source-clock notes using recorded orchestral timbres, with no new notes."""
import argparse
from dataclasses import dataclass, field
import hashlib
import json
from pathlib import Path
import wave
import numpy as np
from sample_bank import load_bank, choose_sample, Sample
from timeline import Note, Timeline, clipped_spans, read_timeline
from source_pcm import load_source, render_source
from phrase_renderer import render_phrase


@dataclass
class RenderContext:
    rate: int
    slots: dict
    banks: dict
    evidence: list
    sources: dict = field(default_factory=dict)
    allow_preserved_source: bool = False


def calibrations(path: Path, cue: str) -> dict:
    slots = json.loads(path.read_text())["cues"][cue]["slots"]
    return slots


def calibrated_roots(tuning: dict) -> list[float]:
    roots = tuning.get("roots_cycles_per_sample") or [tuning.get("root_cycles_per_sample")]
    if not roots or any(root is None or not np.isfinite(root) or root <= 0 for root in roots):
        raise ValueError("Missing source pitch calibration")
    return roots


def component_weights(tuning: dict, count: int) -> np.ndarray:
    if count == 1:
        return np.ones(1)
    measured = tuning.get("components", [])
    if len(measured) != count:
        raise ValueError("Chord component weights are missing")
    weights = np.array([component["weight"] for component in measured], dtype=float)
    if not np.all(np.isfinite(weights)) or np.any(weights <= 0):
        raise ValueError("Chord component weights must be positive and finite")
    return weights / weights.sum()


def note_controls(note: Note, root: float, rate: int) -> tuple[np.ndarray, np.ndarray]:
    length = note.end - note.start
    frequency = np.zeros(length, dtype=np.float64)
    gain = np.zeros(length, dtype=np.float64)
    for span in clipped_spans(note):
        begin, end = span.start - note.start, span.end - note.start
        # ALIS rate_q16 is source samples per generated output frame.
        frequency[begin:end] = root * rate * span.source_step
        gain[begin:end] = span.gain
    return frequency, gain


def sample_note(sample: Sample, controls: tuple[np.ndarray, np.ndarray], rate: int) -> np.ndarray:
    frequency, gain = controls
    steps = frequency / sample.root_hz
    position = np.concatenate(([0.0], np.cumsum(steps[:-1])))
    audible = gain > 0
    if np.any(position[audible] > len(sample.pcm) - 1):
        raise ValueError("Recording too short for source note: " + sample.path.name)
    indexes = np.arange(len(sample.pcm))
    pcm = np.column_stack([
        np.interp(position, indexes, sample.pcm[:, channel], right=0)
        for channel in range(2)
    ])
    gain = gain.copy()
    # Apply the recorded instrument's onset inside the unchanged source gate.
    # SFZ release begins AFTER note-off (sfzformat.com/opcodes/ampeg_release/),
    # so it must not fade the written note early. Source voice stops remain exact.
    attack = min(len(gain), round(sample.attack * rate))
    if attack:
        gain[:attack] *= np.linspace(0, 1, attack)
    return pcm * (gain * sample.gain)[:, None]


def render_note(note: Note, context: RenderContext) -> np.ndarray | None:
    if note.end <= note.start or not any(span.gain > 0 for span in clipped_spans(note)):
        return None
    tuning = context.slots.get(str(note.slot))
    mode = tuning.get("rendering", {}).get("mode") if tuning else None
    if mode == "original_pcm" and context.allow_preserved_source:
        source = context.sources[note.slot]
        context.evidence.append(dict(voice=note.voice, serial=note.serial, slot=note.slot,
                                     start=note.start, end=note.end, mode=mode,
                                     source_sha256=source.sha256,
                                     reason=tuning["rendering"]["reason"]))
        return render_source(note, source)
    if mode == "phrase_orchestra":
        pcm, components = render_phrase(note, context, choose_sample=choose_sample,
                                        sample_note=sample_note)
        context.evidence.extend(components)
        return pcm
    if not tuning or tuning["status"] != "accepted":
        raise ValueError(f"Unresolved audible instrument slot {note.slot}")
    family = tuning["vsco"]["family"]
    roots = calibrated_roots(tuning)
    weights = component_weights(tuning, len(roots))
    return sum(_render_component(note, root, family, context) * weight
               for root, weight in zip(roots, weights))


def _render_component(note: Note, root: float, family: str, context: RenderContext) -> np.ndarray:
    controls = note_controls(note, root, context.rate)
    frequency = controls[0][controls[0] > 0]
    if not len(frequency):
        raise ValueError("Audible source note has no positive playback frequency")
    sample = choose_sample(context.banks[family], controls)
    pcm = sample_note(sample, controls, context.rate)
    context.evidence.append(dict(voice=note.voice, serial=note.serial, slot=note.slot,
                                 start=note.start, end=note.end, family=family,
                                 sample=sample.path.name, sample_sha256=sample.sha256,
                                 root_cycles_per_sample=root, root_hz=sample.root_hz))
    return pcm


def render(timeline: Timeline, context: RenderContext) -> np.ndarray:
    output = np.zeros((timeline.frames, 2), dtype=np.float64)
    for note in timeline.notes:
        pcm = render_note(note, context)
        if pcm is not None:
            output[note.start:note.end] += pcm
    return output


def verify_render_events(timeline: Timeline, evidence: list[dict]) -> dict:
    expected = {
        (note.voice, note.serial): (note.slot, note.start, note.end)
        for note in timeline.notes
        if note.end > note.start and any(span.gain > 0 for span in clipped_spans(note))
    }
    actual = {}
    for component in evidence:
        key = component["voice"], component["serial"]
        bounds = component.get("slot"), component["start"], component["end"]
        if key not in expected or expected[key] != bounds:
            raise ValueError("Rendered event changes a source trigger or its gate")
        if component.get("mode") in ("original_pcm", "phrase_orchestra"):
            source = timeline.instruments.get(component["slot"], {})
            if not source.get("sha256") or component.get("source_sha256") != source["sha256"]:
                raise ValueError("Rendered event substitutes its original source sample")
        actual[key] = bounds
    if actual != expected:
        raise ValueError("Rendered score omits an audible source trigger")
    return dict(source_triggers=len(timeline.notes), audible_source_triggers=len(expected),
                matched_source_triggers=len(actual), rendered_components=len(evidence))


def write_master(output: Path, pcm: np.ndarray, rate: int, evidence: dict) -> None:
    peak = float(np.max(np.abs(pcm)))
    if peak <= 0 or not np.all(np.isfinite(pcm)):
        raise ValueError("Silent or nonfinite orchestral render")
    # Retain the project's existing artistic mastering headroom of -3 dBFS.
    # tools/compose_orchestral_score.py:_render_phrase, documented 2026-10-06.
    gain = 10 ** (-3 / 20) / peak
    quantized = np.rint(pcm * gain * 32767).astype("<i2")
    output.parent.mkdir(parents=True, exist_ok=True)
    with wave.open(str(output), "wb") as wav:
        wav.setnchannels(2)
        wav.setsampwidth(2)
        wav.setframerate(rate)
        wav.writeframes(quantized.tobytes())
    evidence.update(frames=len(pcm), rate=rate, channels=2, mastering_gain=gain,
                    peak_dbfs=20 * float(np.log10(np.max(np.abs(quantized.astype(float))) / 32768)),
                    sha256=hashlib.sha256(output.read_bytes()).hexdigest())
    output.with_suffix(".render.json").write_text(json.dumps(evidence, indent=2) + "\n")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--trace", type=Path, required=True)
    parser.add_argument("--calibration", type=Path, required=True)
    parser.add_argument("--samples", type=Path, required=True)
    parser.add_argument("--cue", required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--allow-preserved-source", action="store_true",
                        help="Explicitly retain reviewed original timbres; reports label each retained note")
    args = parser.parse_args()
    timeline = read_timeline(args.trace)
    if timeline.header.get("cue") != args.cue:
        raise ValueError("Trace belongs to a different cue")
    slots = calibrations(args.calibration, args.cue)
    for slot in {note.slot for note in timeline.notes}:
        tuning = slots.get(str(slot))
        if tuning and tuning["resource_sha256"] != timeline.instruments[slot]["sha256"]:
            raise ValueError(f"Calibration belongs to a different source sample: {slot}")
    families = {s["vsco"]["family"] for s in slots.values() if s["status"] == "accepted"}
    families.update(
        part["family"] for slot in slots.values()
        if slot.get("rendering", {}).get("mode") == "phrase_orchestra"
        for part in slot["rendering"]["notes"]
    )
    banks = {family: load_bank(args.samples, family, timeline.header["rate"]) for family in families}
    sources = {slot: load_source(args.trace.parent / "samples", metadata)
               for slot, metadata in timeline.instruments.items()}
    context = RenderContext(timeline.header["rate"], slots, banks, [], sources,
                            args.allow_preserved_source)
    pcm = render(timeline, context)
    event_check = verify_render_events(timeline, context.evidence)
    evidence = dict(cue=args.cue, trace_sha256=hashlib.sha256(args.trace.read_bytes()).hexdigest(),
                    calibration_sha256=hashlib.sha256(args.calibration.read_bytes()).hexdigest(),
                    loops=timeline.loops, notes=context.evidence, event_check=event_check)
    write_master(args.output, pcm, context.rate, evidence)
    print(json.dumps(dict(cue=args.cue, notes=len(context.evidence), frames=len(pcm))))


if __name__ == "__main__":
    main()
