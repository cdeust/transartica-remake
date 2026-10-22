# SPDX-License-Identifier: MIT
"""Read the existing author's SFZ pitch roots and recorded WAVs, never filename octaves."""
from dataclasses import dataclass
import hashlib
from pathlib import Path, PureWindowsPath
import re
import subprocess
import numpy as np


MAPPINGS = {"strings": "ViolinEnsSusVib.sfz", "cello": "CelloEnsSusVib.sfz",
            "horn": "FHornSus.sfz", "flute": "FluteSusVib.sfz",
            "harp": "Harp.sfz", "timpani": "Timpani.sfz"}


@dataclass
class Sample:
    path: Path
    root_hz: float
    pcm: np.ndarray
    attack: float
    release: float
    gain: float
    sha256: str


def midi_hz(key: int) -> float:
    # SFZ pitch_keycenter uses MIDI keys, A4=69 at standard tuning 440 Hz.
    # https://sfzformat.com/opcodes/pitch_keycenter/ ; existing author SFZ files.
    return 440.0 * 2.0 ** ((key - 69) / 12.0)


def opcode(text: str, name: str, default: float) -> float:
    match = re.search(r"\b" + re.escape(name) + r"\s*=\s*([-+\d.]+)", text)
    return float(match[1]) if match else default


def load_bank(cache: Path, family: str, rate: int) -> list[Sample]:
    sfz = (cache / "mappings" / MAPPINGS[family]).read_text()
    files = {p.name: p for p in (cache / "samples").rglob("*.wav")}
    global_section = sfz.split("<region>", 1)[0]
    result = []
    for region in sfz.split("<region>")[1:]:
        match = re.search(r"\bsample=([^\r\n]+)", region)
        if not match:
            continue
        name = PureWindowsPath(match[1].strip()).name
        if name not in files:
            continue
        sample = _decode(files[name], region, global_section, rate)
        if family in ("strings", "cello", "horn", "flute"):
            sample.pcm = _trim_sustain(sample.pcm)
        result.append(sample)
    if not result:
        raise ValueError("No recorded author samples for " + family)
    return result


def _trim_sustain(pcm: np.ndarray) -> np.ndarray:
    # Arrangement rule: terminal digital silence is not a sustain.
    # Keep natural decays in harp/timpani; only sustained families use this cut.
    nonzero = np.flatnonzero(np.any(pcm != 0, axis=1))
    if not len(nonzero):
        raise ValueError("Silent sustain recording")
    return pcm[:int(nonzero[-1]) + 1]


def _decode(path: Path, region: str, global_section: str, rate: int) -> Sample:
    root = opcode(region, "pitch_keycenter", -1)
    if root < 0:
        raise ValueError("Missing author pitch_keycenter: " + path.name)
    raw = subprocess.check_output(["ffmpeg", "-v", "error", "-i", str(path),
                                   "-f", "f32le", "-ar", str(rate), "-ac", "2", "-"])
    pcm = np.frombuffer(raw, dtype="<f4").reshape(-1, 2).copy()
    # Preserve the recorded attack; only exact leading zero frames are removed.
    nonzero = np.flatnonzero(np.any(pcm != 0, axis=1))
    if not len(nonzero):
        raise ValueError("Silent instrument recording: " + str(path))
    pcm = pcm[int(nonzero[0]):]
    gain = 10 ** (opcode(region, "volume", opcode(global_section, "volume", 0)) / 20)
    return Sample(path, midi_hz(int(root)), pcm, opcode(global_section, "ampeg_attack", 0),
                  opcode(global_section, "ampeg_release", 0), gain,
                  hashlib.sha256(path.read_bytes()).hexdigest())


def _covers_note(sample: Sample, controls: tuple[np.ndarray, np.ndarray]) -> bool:
    frequency, gain = controls
    # Same source-frame integration as render_score.sample_note, after zero trim.
    position = np.concatenate(([0.0], np.cumsum((frequency / sample.root_hz)[:-1])))
    return bool(np.all(position[gain > 0] <= len(sample.pcm) - 1))


def choose_sample(bank: list[Sample], controls: tuple[np.ndarray, np.ndarray]) -> Sample:
    frequency, gain = controls
    if frequency.ndim != 1 or frequency.shape != gain.shape:
        raise ValueError("Pitch and gain controls must be matching frame arrays")
    if not np.all(np.isfinite(frequency)) or not np.all(np.isfinite(gain)) or np.any(frequency < 0):
        raise ValueError("Nonfinite or negative source playback controls")
    audible = frequency[gain > 0]
    if not len(audible) or np.any(audible <= 0):
        raise ValueError("Audible source note has no positive playback frequency")
    # Owner fidelity contract: reject truncation; do not fabricate a sustain loop.
    candidates = [sample for sample in bank if _covers_note(sample, controls)]
    if not candidates:
        raise ValueError("No recorded sample covers the complete audible source note")
    target = float(np.median(audible))
    # source: SFZ pitch_keycenter, https://sfzformat.com/opcodes/pitch_keycenter/.
    # Arrangement choice: minimize transposition among recordings that fit.
    return min(candidates, key=lambda sample: abs(np.log2(target / sample.root_hz)))
