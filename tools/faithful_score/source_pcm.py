# SPDX-License-Identifier: MIT
"""Preserve explicitly reviewed source transients at original DMA positions.

Source layout: original T.X hunk 2, 0x232a..0x237a, and first-four-byte clear
at 0x1f34. The trace supplies actual DMA cursor and segment boundaries.
This is a timbre-preservation path, never an automatic ambiguous-pitch fallback.
"""
from dataclasses import dataclass
import hashlib
from pathlib import Path

import numpy as np

from timeline import Note, Span, clipped_spans


@dataclass
class SourcePCM:
    pcm: np.ndarray
    loop_start: int
    loop_length: int
    sha256: str


def load_source(directory: Path, metadata: dict) -> SourcePCM:
    name = Path(metadata["resource_file"])
    if name.is_absolute() or len(name.parts) != 1:
        raise ValueError("Source sample must be a direct child")
    path = directory / name
    if path.is_symlink():
        raise ValueError("Source sample must not be a symlink")
    raw = path.read_bytes()
    digest = hashlib.sha256(raw).hexdigest()
    if digest != metadata["sha256"] or len(raw) != metadata["resource_bytes"]:
        raise ValueError("Source sample hash or size mismatch")
    pcm = np.frombuffer(raw[metadata["payload_offset"]:], dtype=np.int8).copy()
    pcm[:4] = 0  # Original Amiga instrument initialization, T.X hunk2:0x1f34.
    start, length = metadata["loop_pcm_start"], metadata["loop_pcm_length"]
    if start < 0 or length < 0 or start + length > len(pcm):
        raise ValueError("Source DMA loop outside PCM")
    return SourcePCM(pcm.astype(float) / 128, start, length, digest)


def positions(span: Span, source: SourcePCM) -> np.ndarray:
    if span.source_position is None or span.source_segment_end is None:
        raise ValueError("Original DMA cursor is required for source preservation")
    values = span.source_position + np.arange(span.end - span.start) * span.source_step
    wrapped = values >= span.source_segment_end
    if np.any(wrapped):
        if source.loop_length <= 0:
            raise ValueError("Source voice extends past a non-looping DMA segment")
        values[wrapped] = source.loop_start + (
            values[wrapped] - span.source_segment_end) % source.loop_length
    if np.any(values < 0) or np.any(values >= len(source.pcm)):
        raise ValueError("Original DMA cursor outside PCM")
    return values


def render_source(note: Note, source: SourcePCM) -> np.ndarray:
    pcm = np.zeros((note.end - note.start, 2))
    for span in clipped_spans(note):
        values = source.pcm[np.floor(positions(span, source)).astype(int)] * span.gain
        pcm[span.start - note.start:span.end - note.start] = values[:, None]
    return pcm
