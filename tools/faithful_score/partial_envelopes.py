#!/usr/bin/env python3
"""MIT. Inspect independently resolved odd/even partial envelopes.

This is evidence for source-note attribution, not an automatic transcriber.
Independent odd/even changes can suggest a later octave attack, but can also
come from changing timbre. No correlation threshold converts this into a note.

Sources: the Hann resolution and DTFT measurement references documented in
temporal_evidence.py; original Amiga PCM layout documented in calibrate.py.
"""
import argparse
import html
import json
from pathlib import Path

import numpy as np

import calibrate


def nearby_peak(peaks, expected, radius):
    near = [p for p in peaks if abs(p['cycles_per_sample'] - expected) <= radius]
    return min(near, key=lambda p: abs(p['cycles_per_sample'] - expected)) if near else None


def possible_collisions(seed, expected, radius, context):
    collisions = []
    for other in context['seeds']:
        if other == seed:
            continue
        for multiple in range(1, context['partials'] + 1):
            if abs(other * multiple - expected) <= 2 * radius:
                collisions.append({'other_seed': other, 'partial': multiple})
    return collisions


def measure_harmonics(seed, root, peaks, context):
    x = context['signal']
    size = len(x)
    radius = 2 / (size - 1)
    window = np.hanning(size)
    harmonics = []
    for order in range(1, context['partials'] + 1):
        expected = root * order
        if expected >= .5:
            break
        peak = nearby_peak(peaks, expected, radius)
        amplitude = None
        if peak:
            frequency = peak['cycles_per_sample']
            amplitude = float(2 * abs(np.sum((x - x.mean()) * window *
                              np.exp(-2j * np.pi * frequency * np.arange(size)))) / window.sum())
        collisions = possible_collisions(seed, expected, radius, context)
        harmonics.append({'order': order, 'cycles_per_sample': peak['cycles_per_sample'] if peak else None,
                          'amplitude_pcm': amplitude, 'possible_collisions': collisions})
    return harmonics


def measure_record(seed, peaks, context):
    size, start = len(context['signal']), context['start']
    fundamental = nearby_peak(peaks, seed, 2 / (size - 1))
    root = fundamental['cycles_per_sample'] if fundamental else seed
    harmonics = measure_harmonics(seed, root, peaks, context)
    return {'source_frame': start + (size - 1) / 2,
            'support_start': start, 'support_end': start + size,
            'fundamental_resolved': fundamental is not None, 'harmonics': harmonics}


def measure(pcm, seeds, partials):
    separation = min(np.diff(sorted(seeds))) if len(seeds) > 1 else seeds[0]
    size = max(16, int(np.ceil(4 / separation)) + 1)
    if len(pcm) < size:
        raise ValueError('source too short for independent fundamental bands')
    hop = max(1, size // 4)
    starts = list(range(0, len(pcm) - size + 1, hop))
    if starts[-1] != len(pcm) - size:
        starts.append(len(pcm) - size)
    radius = 2 / (size - 1)
    records = [{'seed_cycles_per_sample': seed, 'points': []} for seed in seeds]
    for start in starts:
        x = np.asarray(pcm[start:start + size], dtype=float)
        peaks = calibrate.spectrum(x)
        for record in records:
            context = {'seeds': seeds, 'partials': partials, 'start': start, 'signal': x}
            record['points'].append(measure_record(record['seed_cycles_per_sample'], peaks, context))
    return {'window_frames': size, 'hop_frames': hop,
            'half_main_lobe_cycles_per_sample': radius,
            'source_frames': len(pcm), 'components': records}


def groups(point):
    values = [p['amplitude_pcm'] or 0 for p in point['harmonics']]
    # Root-sum-square of resolved partial amplitudes; absent peaks remain listed
    # as null in JSON. The plot's zero means unmeasured, not proven silent.
    return (values[0] if values else 0,
            float(np.linalg.norm(values[1::2])),
            float(np.linalg.norm(values[2::2])))


def plot_svg(result, title):
    width, panel_height, margin = 1200, 260, 70
    height = panel_height * len(result['components']) + 90
    colors = ['#2468b4', '#b7392e', '#27804d']
    svg = [f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}">',
           '<rect width="100%" height="100%" fill="white"/>',
           f'<text x="20" y="28" font-size="20">{html.escape(title)}</text>',
           '<text x="20" y="52" font-size="14">Blue: fundamental. Red: even partial RSS. Green: odd partial RSS excluding fundamental. Zero: no resolved peak.</text>']
    for index, component in enumerate(result['components']):
        top = 90 + index * panel_height
        points = component['points']
        data = [groups(point) for point in points]
        ymax = max(max(values) for values in data) or 1
        plot_height = panel_height - 70
        xscale = (width - margin - 20) / result['source_frames']
        svg.append(f'<text x="20" y="{top-8}" font-size="15">Candidate {component["seed_cycles_per_sample"]:.6f} cycles/source-frame; amplitude top {ymax:.2f} PCM units</text>')
        for fraction in [0, .25, .5, .75, 1]:
            x = margin + fraction * (width - margin - 20)
            svg.append(f'<path d="M{x},{top} V{top+plot_height}" stroke="#ddd"/>')
            svg.append(f'<text x="{x}" y="{top+plot_height+20}" font-size="12">{round(fraction*result["source_frames"])}</text>')
        for channel, color in enumerate(colors):
            xy = ' '.join(f'{margin+p["source_frame"]*xscale:.2f},{top+plot_height-v[channel]/ymax*plot_height:.2f}' for p, v in zip(points, data))
            svg.append(f'<polyline points="{xy}" fill="none" stroke="{color}" stroke-width="2"/>')
        svg.append(f'<path d="M{margin},{top} V{top+plot_height} H{width-20}" fill="none" stroke="black"/>')
    svg.append('</svg>')
    return '\n'.join(svg)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--captures', type=Path, required=True)
    parser.add_argument('--reviews', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--partials', type=int, default=7,
                        help='inspection extent, not an acceptance threshold')
    args = parser.parse_args()
    if args.partials < 2:
        parser.error('inspect at least fundamental and second partial')
    reviews = json.loads(args.reviews.read_text())
    args.output.mkdir(exist_ok=True)
    for pcm_hash, review in reviews.items():
        cue, slot = review['seed_source']['cue'], review['seed_source']['slot']
        directory = args.captures / f'{cue}-final' / 'samples'
        metadata = json.loads((directory / 'manifest.json').read_text())[slot]
        if metadata['payload_sha256'] != pcm_hash:
            raise ValueError('review hash differs from supplied decoded PCM')
        pcm, _ = calibrate.load_sample(directory, metadata)
        layout = calibrate.original_playback((directory / metadata['resource_file']).read_bytes())
        result = measure(pcm[:layout['initial_pcm_end']], review['roots_cycles_per_sample'], args.partials)
        result.update(cue=cue, slot=slot, pcm_sha256=pcm_hash,
                      source_playback=layout, limitation=__doc__)
        name = f'{cue}-slot-{slot}'
        (args.output / f'{name}.json').write_text(json.dumps(result, indent=2, allow_nan=False) + '\n')
        (args.output / f'{name}.svg').write_text(plot_svg(result, name))
    print(json.dumps({'sample_plots': len(reviews), 'partials_examined': args.partials}))


if __name__ == '__main__':
    main()
