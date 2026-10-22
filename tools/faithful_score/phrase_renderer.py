# SPDX-License-Identifier: MIT
"""Render measured internal notes of original one-shot samples.

No transcription is inferred here. Source-frame boundaries, pitch and amplitude
come from accepted calibration evidence. The original DMA cursor and period map
those boundaries into output frames; orchestral sample phase begins there.
"""
import math
import numpy as np
from timeline import clipped_spans


def _number(value, name, high=math.inf, positive=False):
    if isinstance(value, bool) or not isinstance(value, (int, float)):
        raise ValueError('Invalid ' + name)
    if not math.isfinite(value) or value < 0 or value > high or (positive and value == 0):
        raise ValueError('Invalid ' + name)
    return value


def _bounds(value, point, extent, name):
    if not isinstance(value, list) or len(value) != 2:
        raise ValueError('Missing ' + name)
    if any(type(v) is not int for v in value) or not 0 <= value[0] <= point <= value[1] <= extent:
        raise ValueError('Chosen source boundary outside ' + name)


def _validate_part(part, extent):
    if not isinstance(part, dict):
        raise ValueError('Invalid phrase note')
    start, end = part.get('source_start'), part.get('source_end')
    if type(start) is not int or type(end) is not int or not 0 <= start < end <= extent:
        raise ValueError('Invalid phrase source gate')
    _bounds(part.get('onset_bounds'), start, extent, 'onset_bounds')
    _bounds(part.get('end_bounds'), end, extent, 'end_bounds')
    _number(part.get('root_cycles_per_sample'), 'phrase root', high=.5, positive=True)
    _number(part.get('weight'), 'phrase weight', high=1, positive=True)
    if not isinstance(part.get('family'), str) or not part['family']:
        raise ValueError('Missing phrase instrument family')
    if not isinstance(part.get('evidence'), dict) or not part['evidence']:
        raise ValueError('Missing phrase measurement evidence')
    curve = part.get('gain_curve')
    if not isinstance(curve, dict):
        raise ValueError('Missing measured phrase gain curve')
    frames, gains = curve.get('source_frames'), curve.get('gains')
    if not isinstance(frames, list) or not isinstance(gains, list) or len(frames) != len(gains) or len(frames) < 2:
        raise ValueError('Invalid phrase gain curve arrays')
    for frame in frames: _number(frame, 'gain curve source frame', high=extent)
    for gain in gains: _number(gain, 'gain curve amplitude', high=1)
    if any(a >= b for a, b in zip(frames, frames[1:])) or not any(gains):
        raise ValueError('Unresolved or unordered phrase gain curve')


def _source_controls(note, source):
    length = note.end - note.start
    if length <= 0:
        raise ValueError('Empty phrase trigger')
    # Original one-shots finish on a cleared two-byte DMA loop. Never repeat an
    # internal phrase when the original reader enters that silent tail.
    if source.loop_length and not (source.loop_start == 0 and source.loop_length == 2
                                   and np.all(source.pcm[:2] == 0)):
        raise ValueError('Phrase orchestration requires an original one-shot')
    cursor = np.full(length, np.nan)
    steps = np.zeros(length)
    gain = np.zeros(length)
    previous_end = note.start
    previous_position = None
    for span in clipped_spans(note):
        if span.start != previous_end:
            raise ValueError('Missing or overlapping phrase DMA spans')
        if span.source_position is None or span.source_segment_end is None:
            raise ValueError('Original DMA cursor is required for phrase orchestration')
        step = _number(span.source_step, 'source step', positive=True)
        _number(span.gain, 'source gain', high=1)
        _number(span.source_position, 'source cursor', high=len(source.pcm))
        _number(span.source_segment_end, 'source segment end', high=len(source.pcm), positive=True)
        values = span.source_position + np.arange(span.end - span.start) * step
        if previous_position is not None and values[0] < previous_position:
            raise ValueError('Phrase source cursor loops or moves backward')
        if np.any(values >= span.source_segment_end):
            raise ValueError('Phrase extends beyond the original one-shot DMA segment')
        begin, end = span.start - note.start, span.end - note.start
        cursor[begin:end], steps[begin:end], gain[begin:end] = values, step, span.gain
        previous_end, previous_position = span.end, values[-1]
    if previous_end != note.end or not np.all(np.isfinite(cursor)):
        raise ValueError('Incomplete phrase source controls')
    return cursor, steps, gain


def _configuration(note, context):
    tuning = context.slots.get(str(note.slot), {})
    rendering = tuning.get('rendering', {})
    if (rendering.get('mode') != 'phrase_orchestra' or
            rendering.get('transcription_status') != 'accepted_measured_inference'):
        raise ValueError('Unresolved phrase transcription')
    source = context.sources.get(note.slot)
    if source is None or tuning.get('resource_sha256') != source.sha256:
        raise ValueError('Phrase calibration belongs to a different source sample')
    parts = rendering.get('notes')
    if not isinstance(parts, list) or not parts:
        raise ValueError('Missing measured phrase notes')
    extent = tuning.get('source_playback', {}).get('initial_pcm_end', len(source.pcm))
    if type(extent) is not int or not 0 < extent <= len(source.pcm):
        raise ValueError('Invalid original initial PCM extent')
    for part in parts: _validate_part(part, extent)
    # Full-precision measured peak/sum weights should sum to one. Allow only
    # accumulated floating-point rounding, one unit at 1.0 per input term.
    total = math.fsum(part['weight'] for part in parts)
    if abs(total - 1) > len(parts) * math.ulp(1.0):
        raise ValueError('Measured phrase weights must sum to one')
    _number(context.rate, 'output sample rate', positive=True)
    return source, parts


def _evidence(note, source, part, index):
    return dict(voice=note.voice, serial=note.serial, slot=note.slot,
                start=note.start, end=note.end, mode='phrase_orchestra',
                component=index, family=part['family'], source_sha256=source.sha256,
                source_start=part['source_start'], source_end=part['source_end'],
                onset_bounds=part['onset_bounds'], end_bounds=part['end_bounds'],
                root_cycles_per_sample=part['root_cycles_per_sample'], weight=part['weight'],
                measurement=part['evidence'], rendered_start=None, rendered_end=None,
                audible=False)


def _recording(context, part, controls, functions):
    choose_sample, sample_note = functions
    if part['family'] not in context.banks:
        raise ValueError('Missing phrase sample family: ' + part['family'])
    sample = choose_sample(context.banks[part['family']], controls)
    pcm = sample_note(sample, controls, context.rate)
    if pcm.shape != (len(controls[0]), 2) or not np.all(np.isfinite(pcm)):
        raise ValueError('Malformed phrase component PCM')
    return pcm, dict(audible=True, sample=sample.path.name,
                     sample_sha256=sample.sha256, root_hz=sample.root_hz)


def render_phrase(note, context, choose_sample, sample_note):
    """Return (stereo PCM over the full trigger gate, component evidence).

    Inject the renderer's existing sample selection/synthesis functions to avoid
    circular imports. The caller appends evidence only after successful return.
    """
    source, parts = _configuration(note, context)
    cursor, steps, source_gain = _source_controls(note, source)
    output = np.zeros((note.end - note.start, 2))
    evidence = []
    for index, part in enumerate(parts):
        active = np.flatnonzero((cursor >= part['source_start']) & (cursor < part['source_end']))
        record = _evidence(note, source, part, index)
        evidence.append(record)
        if not len(active):
            continue
        first, last = int(active[0]), int(active[-1]) + 1
        record.update(rendered_start=note.start + first, rendered_end=note.start + last)
        curve = part['gain_curve']
        gain = np.interp(cursor[first:last], curve['source_frames'], curve['gains'], left=0, right=0)
        gain *= source_gain[first:last] * part['weight']
        frequency = part['root_cycles_per_sample'] * context.rate * steps[first:last]
        if np.any(gain > 0):
            pcm, recording = _recording(context, part, (frequency, gain), (choose_sample, sample_note))
            output[first:last] += pcm
            record.update(recording)
    return output, evidence
