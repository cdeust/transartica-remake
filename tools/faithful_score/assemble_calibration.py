#!/usr/bin/env python3
"""MIT. Merge measured pitch evidence and explicit source-preservation decisions.

No ambiguous pitch becomes a static chord. Temporal components preserve null
intervals and share one amplitude normalization. Original PCM remains under the
analysis because frequency evidence cannot distinguish every later octave
attack from a changing harmonic. Temporal candidates are not orchestral notes.
"""
import argparse
import copy
import hashlib
import json
from pathlib import Path


# These are orchestration choices, not claims about the original instrument.
# They follow measured ranges in calibration-original-paula.json and row periods.
FAMILIES = {
    ('bojeu-0', '6'): 'horn', ('bojeu-0', '10'): 'timpani',
    ('bojeu-0', '11'): 'cello', ('bojeu-0', '12'): 'cello',
    ('bojeu2-0', '3'): 'horn', ('bojeu2-0', '4'): 'cello',
    ('bolieu-0', '0'): 'cello', ('bolieu-0', '1'): 'cello',
    ('bolieu-0', '5'): 'timpani', ('bolieu-0', '7'): 'horn',
    ('bolost-0', '10'): 'horn', ('bopres-0', '0'): 'cello',
    ('bopres-0', '10'): 'flute',
}


def attach_temporal(slot, sample):
    measured = copy.deepcopy(sample)
    if measured['source_frames'] != slot['source_playback']['initial_pcm_end']:
        raise ValueError('temporal evidence uses a different original DMA extent')
    components = measured['components']
    divisor = sum(max(p['amplitude_pcm'] for p in c['points']) for c in components)
    if divisor <= 0:
        raise ValueError('temporal review has no resolved component energy')
    for component in components:
        if not any(p['cycles_per_sample'] for p in component['points']):
            raise ValueError('temporal component lacks measured support')
        for point in component['points']:
            point['amplitude_gain'] = point['amplitude_pcm'] / divisor
    mode = 'original_pcm'
    slot['temporal_analysis'] = {
        'family_if_notes_verified': measured['review']['family'],
        'components': components, 'amplitude_normalizer_pcm': divisor,
        'window_frames': measured['window_frames'],
        'frequency_resolution_cycles_per_sample': measured['frequency_resolution_cycles_per_sample'],
        'onset_uncertainty_frames': measured['onset_uncertainty_frames'],
        'reason': measured['review']['reason']}
    slot['rendering'] = {
        'mode': mode, 'source_mask': 'entire_original_sample',
        'reason': 'Unresolved internal note-versus-harmonic attribution. '
                  'Temporal spectral candidates must not be rendered as new notes.'}
    return mode


def assemble(calibration, temporal, preservation, families_by_route=None):
    result = copy.deepcopy(calibration)
    result['format'] = 'alis-orchestration-calibration-v1'
    result['render_contract'] = {
        'source_basis': 'Original Amiga Paula layout; apply source_playback.startup_zero_bytes',
        'static': 'Use only calibrated roots and component weights, never MIDI rounding.',
        'temporal': 'Analysis only. Source-frame candidates are not verified original notes. '
                    'Use original PCM throughout; do not overlay these candidates as orchestral notes.',
        'amplitude': 'Temporal amplitude_gain is measured amplitude divided by the sum of component maxima. '
                     'This common denominator preserves changing component balance.',
        'limitation': 'Unresolved pitched phrases retain their original timbre. '
                      'This contract does not complete full re-instrumentation.'}
    families = {}
    for (cue, slot), family in (FAMILIES if families_by_route is None else families_by_route).items():
        source = calibration['cues'][cue]['slots'][slot]
        families[source['pcm_sha256']] = family
    counts = {}
    for cue in result['cues'].values():
        for slot in cue['slots'].values():
            pcm_hash = slot['pcm_sha256']
            if slot['status'] == 'accepted':
                family = families.get(pcm_hash, slot['vsco']['family'])
                slot['vsco'].update(family=family, artistic_choice=True,
                                    reason='Orchestral family chosen for the measured pitch range.')
                mode = 'static_orchestra'
                slot['rendering'] = {'mode': mode, 'family': family}
            elif pcm_hash in temporal['samples']:
                mode = attach_temporal(slot, temporal['samples'][pcm_hash])
            elif pcm_hash in preservation:
                mode = 'original_pcm'
                slot['rendering'] = dict(preservation[pcm_hash], mode=mode)
            else:
                raise ValueError(f'unresolved source hash {pcm_hash}')
            counts[mode] = counts.get(mode, 0) + 1
    result['render_mode_slot_counts'] = counts
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--calibration', type=Path, required=True)
    parser.add_argument('--temporal', type=Path, required=True)
    parser.add_argument('--preservation', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    inputs = [args.calibration, args.temporal, args.preservation]
    result = assemble(*(json.loads(path.read_text()) for path in inputs))
    result['evidence_sha256'] = {path.name: hashlib.sha256(path.read_bytes()).hexdigest() for path in inputs}
    args.output.write_text(json.dumps(result, indent=2, allow_nan=False) + '\n')
    print(json.dumps(result['render_mode_slot_counts']))


if __name__ == '__main__':
    main()
