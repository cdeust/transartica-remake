#!/usr/bin/env python3
"""MIT. Hash-bound temporal evidence for components inside original PCM.

This measures spectral components, not a guessed MIDI transcription. An octave
partial and a separately played octave are not distinguished by frequency alone.
Null points mean unsupported pitch and must not be filled with invented notes.

Sources: Julius O. Smith, Spectral Audio Signal Processing, Hann window and
Sinusoidal Peak Interpolation sections, equations 6.30 and 6.31:
https://www.dsprelated.com/freebooks/sasp/Hann_Hanning_Raised_Cosine.html
https://www.dsprelated.com/freebooks/sasp/Sinusoidal_Peak_Interpolation.html
"""
import argparse
import json
from pathlib import Path

import numpy as np

import calibrate


def component_point(signal, peaks, seed, start):
    size = len(signal)
    window = np.hanning(size)
    radius = 2 / (size - 1)
    candidates = [peak for peak in peaks if abs(peak['cycles_per_sample'] - seed) <= radius]
    peak = min(candidates, key=lambda p: abs(p['cycles_per_sample'] - seed)) if candidates else None
    point = {'source_frame': start + (size - 1) / 2,
             'support_start': start, 'support_end': start + size,
             'cycles_per_sample': None, 'amplitude_pcm': 0.0, 'harmonics': []}
    if peak:
        root = peak['cycles_per_sample']
        # Direct DTFT at the interpolated peak avoids FFT-bin amplitude loss.
        amplitude = 2 * abs(np.sum((signal - signal.mean()) * window *
                            np.exp(-2j * np.pi * root * np.arange(size)))) / window.sum()
        harmonics = []
        for partial in peaks:
            multiple = round(partial['cycles_per_sample'] / root)
            if multiple >= 2 and abs(partial['cycles_per_sample'] - root * multiple) <= radius * multiple:
                harmonics.append(dict(partial, multiple=multiple))
        point.update(cycles_per_sample=root, amplitude_pcm=float(amplitude),
                     harmonics=harmonics, fundamental=peak)
    return point


def component_tracks(pcm, seeds, source_start=0, window_frames=None):
    """Measure tracked fundamentals with explicit finite-window uncertainty.

    The Hann main-lobe width 4/(N-1) must resolve the closest seed separation.
    A single-component analysis uses four periods. Half-window spacing samples
    the envelope without asserting a precise note onset inside any window.
    """
    if not seeds or any(not 0 < value < 0.5 for value in seeds):
        raise ValueError('component seeds must lie inside the Nyquist interval')
    seeds = sorted(set(seeds))
    separation = min(np.diff(seeds)) if len(seeds) > 1 else seeds[0]
    size = max(16, int(np.ceil(4 / separation)) + 1) if window_frames is None else window_frames
    if size < 16:
        raise ValueError('insufficient analysis window')
    if len(pcm) < size:
        raise ValueError('sample is shorter than required component resolution')
    starts = list(range(0, len(pcm) - size + 1, size // 2))
    if starts[-1] != len(pcm) - size:
        starts.append(len(pcm) - size)
    radius = 2 / (size - 1)
    components = [{'seed_cycles_per_sample': seed, 'points': []} for seed in seeds]
    for start in starts:
        signal = np.asarray(pcm[start:start + size], dtype=float)
        peaks = calibrate.spectrum(signal)
        for component in components:
            component['points'].append(component_point(signal, peaks, component['seed_cycles_per_sample'],
                                                       source_start + start))
    return {'window_frames': size, 'hop_frames': size // 2,
            'frequency_resolution_cycles_per_sample': radius,
            'onset_uncertainty_frames': size / 2,
            'components': components,
            'limitation': 'Spectral support is not proof of a note onset; null pitch is unsupported. '
                          'Octave partials may be separate source notes or timbre changes.'}


def locally_resolved_tracks(pcm, seeds):
    """Use each fundamental's nearest neighbor to set its Hann resolution.

    A close pair of low fundamentals need not smear independently separated
    higher note attacks. The same 4/(N-1) resolution criterion applies per band.
    """
    components = []
    result = None
    for seed in seeds:
        neighbors = [abs(other - seed) for other in seeds if other != seed]
        separation = min(neighbors) if neighbors else seed
        size = max(16, int(np.ceil(4 / separation)) + 1)
        result = component_tracks(pcm, [seed], window_frames=size)
        component = result['components'][0]
        component.update(window_frames=size,
                         frequency_resolution_cycles_per_sample=result['frequency_resolution_cycles_per_sample'])
        components.append(component)
    result.update(components=components, window_frames=max(c['window_frames'] for c in components),
                  frequency_resolution_cycles_per_sample=max(c['frequency_resolution_cycles_per_sample'] for c in components),
                  onset_uncertainty_frames=max(c['window_frames'] for c in components) / 2,
                  resolution_policy='Each component uses its nearest reviewed fundamental separation.')
    return result


def generate(captures, calibration, review_seeds, local_resolution=False):
    evidence = {'format': 'alis-temporal-evidence-v1', 'samples': {}}
    for directory in sorted(captures.glob('*-final')):
        cue = calibrate.capture_identity(directory / 'score.ndjson')
        metadata = json.loads((directory / 'samples/manifest.json').read_text())
        for slot, measured in calibration['cues'][cue]['slots'].items():
            pcm_hash = measured['pcm_sha256']
            if pcm_hash not in review_seeds:
                continue
            if pcm_hash in evidence['samples']:
                evidence['samples'][pcm_hash]['uses'].append({'cue': cue, 'slot': slot})
                continue
            pcm, region = calibrate.load_sample(directory / 'samples', metadata[slot])
            item = review_seeds[pcm_hash]
            # Include the attack before a mixer loop; it is still part of the source note.
            extent = measured['source_playback']['initial_pcm_end']
            analyzer = locally_resolved_tracks if local_resolution else component_tracks
            tracks = analyzer(pcm[:extent], item['roots_cycles_per_sample'])
            evidence['samples'][pcm_hash] = dict(
                tracks, pcm_sha256=pcm_hash, resource_sha256=measured['resource_sha256'],
                source_frames=extent, mixer_region=region,
                uses=[{'cue': cue, 'slot': slot}], review=item)
    missing = set(review_seeds) - set(evidence['samples'])
    if missing:
        raise ValueError(f'no source PCM for reviewed hashes: {sorted(missing)}')
    return evidence


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--captures', type=Path, required=True)
    parser.add_argument('--calibration', type=Path, required=True)
    parser.add_argument('--reviews', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--local-resolution', action='store_true')
    args = parser.parse_args()
    result = generate(args.captures, json.loads(args.calibration.read_text()),
                      json.loads(args.reviews.read_text()), args.local_resolution)
    args.output.write_text(json.dumps(result, indent=2, allow_nan=False) + '\n')
    print(json.dumps({'samples': len(result['samples']),
                      'components': sum(len(s['components']) for s in result['samples'].values())}))


if __name__ == '__main__':
    main()
