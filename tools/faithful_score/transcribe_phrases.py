#!/usr/bin/env python3
"""MIT. Source-bounded reviewed phrase transcription from original PCM.

Attack search intervals are explicit visual review selections from the original
partial-envelope plots, not a beat grid. Inside each interval the largest rise
of the resolved fundamental selects an onset support bracket. Its midpoint is
the rendering estimate; the full finite-window uncertainty remains in evidence.
"""
import argparse
import copy
import hashlib
import json
import statistics
from pathlib import Path


# Source: original-partial-envelopes-10/bojeu2-0-slot-N.{json,png}, reviewed by
# calibration owner and root. Separate upper-band attacks are evidenced by
# growing even partial families while lower fundamentals/odd families decay.
PHRASES = {
    '6': [(0.0334, None), (.0375, (870, 3045)), (.0398, (2175, 4785)), (.04995, (3480, 5655))],  # source: reviewed slot-6 envelope
    '11': [(.01653, None), (.01967, (955, 2863)), (.02485, (2545, 4453)),
           (.03306, (3817, 5725)), (.03934, (4135, 6679)), (.04970, (5725, 7951))],
    '12': [(.018635, None), (.0235, (682, 2271)), (.0279, (2498, 4087)),
           (.0470, (5449, 7038)), (.0558, (6811, 8854))],
    '13': [(.022262, None), (.02642, (964, 2650)), (.033345, (2650, 4578)),
           (.044524, (4337, 6265)), (.05284, (5301, 7229)), (.06669, (6506, 8675))],
}


def measured_attack(points, interval):
    pairs = [(b['amplitude_pcm'] - a['amplitude_pcm'], a, b)
             for a, b in zip(points, points[1:])
             if interval[0] <= b['source_frame'] <= interval[1]
             and b['cycles_per_sample'] is not None]
    # Source: positive first difference defines a measured rise; no fitted
    # amplitude threshold or invented note-grid tolerance is introduced.
    if not pairs or max(pair[0] for pair in pairs) <= 0:
        raise ValueError('reviewed attack has no measured fundamental rise')
    rise, before, after = max(pairs, key=lambda pair: pair[0])
    bounds = [before['support_start'], after['support_end']]
    start = round(sum(bounds) / 2)
    attack = {'search_interval': list(interval), 'rise_pcm': rise,
              'before': before, 'after': after,
              'basis': 'largest measured fundamental rise in independently reviewed source attack'}
    return start, bounds, attack


def active_gains(points, start, peak):
    return [p['amplitude_pcm'] / peak if p['source_frame'] >= start else 0.0 for p in points]


def measured_note(component, interval, extent, refinement=None):
    points = component['points']
    if refinement is not None:
        start = refinement['source_start']
        bounds = refinement['onset_bounds']
        if not 0 <= bounds[0] <= start <= bounds[1] <= extent:
            raise ValueError('refined onset lies outside measured source support')
        attack = refinement
    elif interval is None:
        start, bounds, attack = 0, [0, 0], {'basis': 'first note begins at the original sample trigger'}
    else:
        start, bounds, attack = measured_attack(points, interval)
    active = [p for p in points if start <= p['source_frame'] < extent and p['cycles_per_sample']]
    if not active:
        raise ValueError('reviewed note has no resolved active fundamental')
    peak = max(p['amplitude_pcm'] for p in active)
    if peak <= 0:
        raise ValueError('reviewed note has no measurable amplitude')
    frequencies = [p['cycles_per_sample'] for p in active]
    frames = [0.0] + [p['source_frame'] for p in points] + [float(extent)]
    gains = [0.0] + active_gains(points, start, peak) + [0.0]
    return {'source_start': start, 'source_end': extent,
            'root_cycles_per_sample': statistics.median(frequencies),
            'family': 'harp', 'onset_bounds': bounds, 'end_bounds': [extent, extent],
            'gain_curve': {'source_frames': frames, 'gains': gains},
            'evidence': {'attack': attack, 'observed_frequency_range': [min(frequencies), max(frequencies)],
                         'root_estimator': 'median of resolved active source fundamental frequencies',
                         'end_basis': 'original sample cutoff; source decay is represented by measured gain',
                         'measured_peak_pcm': peak}, '_peak': peak}


def describe_contract(result):
    counts = {}
    for cue in result['cues'].values():
        for slot in cue['slots'].values():
            mode = slot['rendering']['mode']
            counts[mode] = counts.get(mode, 0) + 1
    result['render_mode_slot_counts'] = counts
    result['render_contract'] = {
        'source_basis': 'Original Amiga CPU decompression and Paula layout; apply source_playback.startup_zero_bytes.',
        'static': 'Use independently measured component roots and weights; no MIDI pitch snapping.',
        'phrase': 'Render only notes in phrase_orchestra entries. Onsets are midpoints of recorded finite-window '
                  'support bounds; first notes use original trigger zero. Measured gains retain internal decay.',
        'analysis': 'Other spectral candidates remain analysis-only; rejected candidates do not become notes.',
        'retained_source': 'Original resonant/percussive textures remain PCM. Some have pitched resonances; '
                           'their retention is not a claim that all are unpitched.',
        'limitations': 'Phrase transcription is measured musical inference with explicit frequency/onset uncertainty, '
                       'not recovered published sheet music. This arrangement does not replace every original timbre.',
        'status': 'ready_for_render_validation'}
    return result


def add_phrases(contract, temporal, selected=None, refinements=None):
    result = copy.deepcopy(contract)
    for slot, candidates in PHRASES.items():
        if selected and slot not in selected:
            continue
        source = result['cues']['bojeu2-0']['slots'][slot]
        measurement = temporal['samples'][source['pcm_sha256']]
        extent = source['source_playback']['initial_pcm_end']
        if extent != measurement['source_frames']:
            raise ValueError('phrase measurement differs from original PCM extent')
        notes = []
        for seed, interval in candidates:
            # The candidate seeds are exactly the stored review values; float
            # representation differences from doubling are handled by nearest
            # identity plus its measured Hann resolution, not by MIDI snapping.
            component = min(measurement['components'], key=lambda c: abs(c['seed_cycles_per_sample'] - seed))
            if abs(component['seed_cycles_per_sample'] - seed) > measurement['frequency_resolution_cycles_per_sample']:
                raise ValueError('reviewed phrase component absent from temporal evidence')
            refinement = (refinements or {}).get(source['pcm_sha256'], {}).get(str(seed))
            notes.append(measured_note(component, interval, extent, refinement))
        denominator = sum(note['_peak'] for note in notes)
        for note in notes:
            note['weight'] = note.pop('_peak') / denominator
            note['evidence'].update(pcm_sha256=source['pcm_sha256'],
                                    frequency_resolution_cycles_per_sample=measurement['frequency_resolution_cycles_per_sample'])
        rendering = {'mode': 'phrase_orchestra', 'transcription_status': 'accepted_measured_inference',
                     'notes': notes, 'weight_basis': 'relative resolved fundamental peak amplitudes',
                     'source_basis': 'Original CPU decoded PCM and separately reviewed odd/even partial attacks',
                     'timing_limitation': 'Onsets are measured finite-window estimates, not decoded sub-sample note words.'}
        if slot == '12':
            rendering['rejected_spectral_candidates'] = [{
                'cycles_per_sample': .03727,
                'reason': 'No resolved 2f/6f/10f attack family at source centers3633..4995. '
                          'Weak nearby bands at5222/5449/5676 drift .038139/.038580/.039146 '
                          'with amplitudes1.249/2.295/2.000 PCM units and no resolved6f/10f. '  # source: slot-12 envelope JSON
                          'A separate musical note is unestablished; this is not claimed an exact lower-note harmonic.'}]
        source['rendering'] = rendering
    return describe_contract(result)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--contract', type=Path, required=True)
    parser.add_argument('--temporal', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--slots', nargs='+')
    parser.add_argument('--onset-refinements', type=Path)
    args = parser.parse_args()
    refinements = json.loads(args.onset_refinements.read_text()) if args.onset_refinements else None
    result = add_phrases(json.loads(args.contract.read_text()), json.loads(args.temporal.read_text()), args.slots, refinements)
    result.setdefault('evidence_sha256', {})[args.temporal.name] = hashlib.sha256(args.temporal.read_bytes()).hexdigest()
    if args.onset_refinements:
        result['evidence_sha256'][args.onset_refinements.name] = hashlib.sha256(args.onset_refinements.read_bytes()).hexdigest()
    args.output.write_text(json.dumps(result, indent=2, allow_nan=False) + '\n')
    print(json.dumps(result['render_mode_slot_counts']))


if __name__ == '__main__':
    main()
