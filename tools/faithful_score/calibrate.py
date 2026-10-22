#!/usr/bin/env python3
"""MIT. Continuous pitch evidence from post-load ALIS signed-eight-bit PCM.

Source: YIN: de Cheveigne/Kawahara, JASA 111 (2002), doi:10.1121/1.1458024,
steps 2-5; https://librosa.org/doc/main/api/generated/librosa.yin.html.
The published 0.1 trough threshold is a candidate detector, not a probability.
Our conservative acceptance protocol additionally requires agreement between
whole-region and half-region measurements, and a resolved fundamental peak.
That protocol deliberately leaves missing fundamentals/chords for review.
No equal-tempered tuning or assumed original sample rate enters this analysis.
"""
import argparse
import hashlib
import json
from pathlib import Path

import numpy as np

YIN_THRESHOLD = 0.1  # source: de Cheveigne/Kawahara (2002), YIN step 4.
SOURCES = ['https://doi.org/10.1121/1.1458024',  # source: YIN publication DOI
           'https://librosa.org/doc/main/api/generated/librosa.yin.html',
           'https://dsprelated.com/freebooks/sasp/Spectrum_Analysis_Windows.html',
           'original Amiga T.X hunk 2: sample DMA setup 0x232a..0x237a; startup 0x1f34']


def difference(signal):
    """Fixed-width YIN squared difference, FFT correlation with linear padding."""
    x = np.asarray(signal, dtype=float)
    width = len(x) // 2
    size = 1 << (len(x) + width - 2).bit_length()
    correlation = np.fft.irfft(np.fft.rfft(x, size) *
                             np.conj(np.fft.rfft(x[:width], size)), size)[:width]
    energy = np.concatenate(([0.0], np.cumsum(x * x)))
    shifted = energy[width:width * 2] - energy[:width]
    return np.maximum(energy[width] + shifted - 2 * correlation, 0)


def parabola(values, index):
    """Three-point parabolic vertex, in array-index units."""
    left, center, right = values[index - 1:index + 2]
    denominator = left - 2 * center + right
    return float(index + (left - right) / (2 * denominator)) if denominator else float(index)


def yin(signal):
    x = np.asarray(signal, dtype=float)
    if len(x) < 8 or not np.ptp(x):
        return None
    d = difference(x - np.mean(x))
    cumulative = np.cumsum(d[1:])
    normalized = np.ones(len(d))
    np.divide(d[1:] * np.arange(1, len(d)), cumulative,
              out=normalized[1:], where=cumulative > 0)
    minima = np.flatnonzero((normalized[1:-1] < normalized[:-2]) &
                           (normalized[1:-1] <= normalized[2:])) + 1
    minima = minima[minima >= 2]  # Nyquist: at least two samples per cycle.
    if not len(minima):
        return None
    below = minima[normalized[minima] < YIN_THRESHOLD]
    index = int(below[0] if len(below) else minima[np.argmin(normalized[minima])])
    lag = parabola(normalized, index)
    return {'cycles_per_sample': 1 / lag, 'lag_samples': lag,
            'normalized_difference': float(normalized[index]),
            'below_yin_threshold': bool(len(below))}


def spectrum(signal):
    """Hann peaks above the exact worst-case half-LSB quantization bound.

    A signed8 value represents an interval of width one; the DFT error bound
    is sum(abs(window))/2 by the triangle inequality. This is not a noise
    estimate and deliberately retains strong non-harmonic peaks for review.
    """
    x = np.asarray(signal, dtype=float)
    window = np.hanning(len(x))
    magnitude = np.abs(np.fft.rfft((x - x.mean()) * window))
    bound = float(window.sum() / 2)
    peaks = np.flatnonzero((magnitude[1:-1] > magnitude[:-2]) &
                          (magnitude[1:-1] >= magnitude[2:]) &
                          (magnitude[1:-1] > bound)) + 1
    return [{'cycles_per_sample': parabola(magnitude, int(i)) / len(x),
             'magnitude': float(magnitude[i]), 'quantization_bound': bound}
            for i in sorted(peaks, key=lambda i: -magnitude[i])]


def measure_window(signal, bounds):
    start, end = bounds
    x = np.asarray(signal[start:end], dtype=float)
    result = {'start': start, 'end': end, 'bin_width': 1 / len(x),
              'hann_half_main_lobe': 2 / (len(x) - 1),
              'rms': float(np.sqrt(np.mean(x * x))), 'yin': yin(x),
              'spectral_peaks': spectrum(x)}
    candidate = result['yin']
    root = candidate['cycles_per_sample'] if candidate else None
    result['fundamental_resolved'] = bool(root and any(
        abs(p['cycles_per_sample'] - root) <= result['hann_half_main_lobe']
        for p in result['spectral_peaks']))
    return result


def accept_windows(windows):
    if not all(w['yin'] and w['yin']['below_yin_threshold'] for w in windows):
        return False, 'not consistently periodic under published YIN threshold'
    if not all(w['fundamental_resolved'] for w in windows):
        return False, 'fundamental absent or unresolved; harmonic/chord ambiguity'
    root = windows[0]['yin']['cycles_per_sample']
    if not all(abs(w['yin']['cycles_per_sample'] - root) <= w['bin_width']
               for w in windows):
        return False, 'root differs between independent sample regions'
    return True, 'whole region and both halves agree with resolved fundamental'


def analyze_pcm(signal):
    """Candidate pitch, never a claim that every periodic sample is monophonic."""
    result = {'status': 'ambiguous', 'classification': 'unknown',
              'root_cycles_per_sample': None, 'roots_cycles_per_sample': [],
              'windows': [], 'candidates': [],
              'reason': 'insufficient samples for two independent YIN windows'}
    if len(signal) < 16:
        return result
    middle = len(signal) // 2
    bounds = [(0, len(signal)), (0, middle), (middle, len(signal))]
    windows = [measure_window(signal, pair) for pair in bounds]
    result['windows'] = windows
    result['candidates'] = [w['yin'] for w in windows if w['yin']]
    accepted, result['reason'] = accept_windows(windows)
    if accepted:
        result.update(status='accepted', classification='tonal',
                      root_cycles_per_sample=windows[0]['yin']['cycles_per_sample'],
                      roots_cycles_per_sample=[windows[0]['yin']['cycles_per_sample']])
    return result


def component_window(window, seed):
    # source: Julius O. Smith, Spectrum Analysis Windows, Hann main lobe 4/(N-1).
    radius = 2 / (window['end'] - window['start'] - 1)
    peaks = window['spectral_peaks']
    near = [p for p in peaks if abs(p['cycles_per_sample'] - seed) <= radius]
    if not near:
        raise ValueError('reviewed component has no resolved fundamental')
    fundamental = min(near, key=lambda p: abs(p['cycles_per_sample'] - seed))
    root = fundamental['cycles_per_sample']
    harmonics = []
    for peak in peaks:
        multiple = round(peak['cycles_per_sample'] / root)
        # Propagate the measured fundamental's bin uncertainty to its harmonics.
        if multiple >= 2 and abs(peak['cycles_per_sample'] - multiple * root) <= radius * multiple:
            harmonics.append(dict(peak, multiple=multiple))
    if not harmonics:
        raise ValueError('reviewed component has no independently observed harmonic')
    return {'start': window['start'], 'end': window['end'],
            'fundamental': fundamental, 'harmonics': harmonics, 'radius': radius}


def reviewed_component(windows, seed):
    evidence = [component_window(w, seed) for w in windows]
    frequencies = [e['fundamental']['cycles_per_sample'] for e in evidence]
    # The whole-region peak has the finest DFT resolution; halves corroborate it.
    root = frequencies[0]
    return {'cycles_per_sample': root, 'observed_range': [min(frequencies), max(frequencies)],
            'fundamental_magnitude': evidence[0]['fundamental']['magnitude'],
            'windows': evidence}


def partial_matches(peaks, seed, multiple, radius):
    return [p for p in peaks
            if abs(p['cycles_per_sample'] - seed * multiple) <= radius * multiple]


def periodic_component(windows, seed):
    evidence = []
    for window in windows:
        candidate = window['yin']
        radius = window['hann_half_main_lobe']
        if (not candidate or not candidate['below_yin_threshold'] or
                abs(candidate['cycles_per_sample'] - seed) > radius):
            raise ValueError('missing-fundamental component lacks consistent periodicity')
        partials = []
        for multiple in (2, 3):
            matches = partial_matches(window['spectral_peaks'], seed, multiple, radius)
            if not matches:
                raise ValueError('missing-fundamental component lacks partial 2 or 3')
            partials.append(dict(max(matches, key=lambda p: p['magnitude']), multiple=multiple))
        evidence.append({'start': window['start'], 'end': window['end'], 'radius': radius,
                         'yin': candidate, 'harmonics': partials})
    roots = [e['yin']['cycles_per_sample'] for e in evidence]
    return {'cycles_per_sample': roots[0], 'observed_range': [min(roots), max(roots)],
            'fundamental_magnitude': sum(p['magnitude'] for p in evidence[0]['harmonics']),
            'fundamental_absent': True, 'windows': evidence}


def dominant_component(windows, seed):
    """Explicit review of a near-pure tone, without inventing absent harmonics.

    Each independent window must have its strongest measured band at the
    reviewed frequency within its Hann resolution. This supports the identified
    dominant tone; it does not classify all lower-level energy as noise.
    """
    evidence = []
    for window in windows:
        peaks = window['spectral_peaks']
        radius = window['hann_half_main_lobe']
        if not peaks or abs(peaks[0]['cycles_per_sample'] - seed) > radius:
            raise ValueError('reviewed dominant tone is not strongest in every region')
        evidence.append({'start': window['start'], 'end': window['end'],
                         'fundamental': peaks[0], 'radius': radius, 'harmonics': []})
    frequencies = [item['fundamental']['cycles_per_sample'] for item in evidence]
    return {'cycles_per_sample': frequencies[0], 'observed_range': [min(frequencies), max(frequencies)],
            'fundamental_magnitude': evidence[0]['fundamental']['magnitude'],
            'dominant_single_band': True, 'windows': evidence}


def pitch_contour(signal, root_hint):
    """Time-varying evidence, with nulls wherever periodicity is unsupported.

    Four candidate periods give the fixed-width difference two periods to
    compare; half-window hops provide independent comparison reference blocks.
    This is an analysis protocol, not a claim that arbitrary audio is voiced.
    """
    size = max(16, int(np.ceil(4 / root_hint)))
    result = []
    for start in range(0, len(signal) - size + 1, size // 2):
        window = measure_window(signal, (start, start + size))
        candidate = window['yin']
        accepted = bool(candidate and candidate['below_yin_threshold'] and
                        window['fundamental_resolved'])
        lag = candidate['lag_samples'] if candidate else 0
        # Mean location of the sample pairs used by the fixed-width difference.
        center = round(start + size / 4 + lag / 2)
        result.append({'source_frame': center, 'start': start, 'end': start + size,
                       'cycles_per_sample': candidate['cycles_per_sample'] if accepted else None,
                       'yin': candidate, 'fundamental_resolved': window['fundamental_resolved']})
    return result


def spectral_residual(window, components):
    total = residual = 0.0
    unmatched = []
    for peak in window['spectral_peaks']:
        power = peak['magnitude'] ** 2
        total += power
        matches = False
        for component in components:
            root = component['cycles_per_sample']
            multiple = round(peak['cycles_per_sample'] / root)
            radius = component['windows'][0]['radius'] * max(multiple, 1)
            matches |= multiple >= 1 and abs(peak['cycles_per_sample'] - multiple * root) <= radius
        if not matches:
            residual += power
            unmatched.append(peak)
    return residual / total if total else 1.0, unmatched


def apply_review(measured, review):
    """Check hash-scoped human-selected candidates; never infer chord labels."""
    seeds = review['roots_cycles_per_sample']
    if not seeds or any(not 0 < s < 0.5 for s in seeds) or not review['reason'].strip():
        raise ValueError('review requires evidenced component candidates and rationale')
    estimators = {'periodic_harmonics': periodic_component,
                  'dominant_single_band': dominant_component}
    if review.get('mode') == 'dominant_single_band' and len(seeds) != 1:
        raise ValueError('dominant single-band review requires exactly one root')
    estimator = estimators.get(review.get('mode'), reviewed_component)
    components = [estimator(measured['windows'], seed) for seed in seeds]
    total = sum(c['fundamental_magnitude'] for c in components)
    for component in components:
        component['weight'] = component['fundamental_magnitude'] / total
        component['weight_basis'] = 'relative resolved fundamental DFT amplitude, not source loudness'
    residual, unmatched = spectral_residual(measured['windows'][0], components)
    roots = [c['cycles_per_sample'] for c in components]
    measured.update(status='accepted', classification='polyphonic' if len(roots) > 1 else 'tonal',
                    roots_cycles_per_sample=roots, root_cycles_per_sample=roots[0] if len(roots) == 1 else None,
                    components=components, spectral_peak_residual_fraction=residual,
                    unmatched_spectral_peaks=unmatched, review=review,
                    reason='reviewed components corroborated in all sample regions',
                    vsco={'family': review['family'], 'artistic_choice': True,
                          'reason': review['reason']})
    return measured


def original_playback(data):
    """Original 68000 Paula word counts, distinct from the host ALIS mixer.

    Source: Amiga T.X hunk 2, 0x232a..0x237a. The total resource length and
    loop pointers are big-endian. Paula lengths are words; the loop adds one
    word after halving its byte difference. Startup 0x1f34 zeroes four PCM bytes.
    """
    total = int.from_bytes(data[2:6], 'big')
    start = int.from_bytes(data[8:12], 'big')
    end = int.from_bytes(data[12:16], 'big')
    if total != len(data) or total < 20:
        raise ValueError('original resource total/header mismatch')
    initial = 2 * ((end if start else total - 16) // 2)
    loop_length = 2 * ((end - start) // 2 + 1)
    if not 0 < initial <= total - 16 or loop_length < 2 or start + loop_length > total - 16:
        raise ValueError('original DMA extent outside decoded PCM')
    return {'initial_pcm_end': initial, 'loop_pcm_start': start,
            'loop_pcm_length': loop_length, 'startup_zero_bytes': 4,
            'source': 'Amiga T.X hunk2 0x232a..0x237a and 0x1f34'}


def load_sample(directory, metadata):
    name = Path(metadata['resource_file'])
    if name.is_absolute() or len(name.parts) != 1:
        raise ValueError('sample path must be a direct child')
    path = directory / name
    if path.is_symlink() or not path.is_file():
        raise ValueError('sample must be a regular decoded resource')
    data = path.read_bytes()
    if len(data) != metadata['resource_bytes'] or metadata['payload_offset'] != 16:
        raise ValueError('decoded resource length/header mismatch')
    payload = data[16:]
    if (hashlib.sha256(data).hexdigest() != metadata['sha256'] or
            hashlib.sha256(payload).hexdigest() != metadata['payload_sha256']):
        raise ValueError('decoded resource hash mismatch')
    if len(payload) != metadata['pcm_bytes']:
        raise ValueError('invalid PCM extent')
    playback = original_playback(data)
    start, length = playback['loop_pcm_start'], playback['loop_pcm_length']
    region = {'start': start, 'end': start + length if start else playback['initial_pcm_end'],
              'kind': 'original_paula_loop' if start else 'original_initial_playback'}
    pcm = np.frombuffer(payload, dtype=np.int8).copy()
    pcm[:playback['startup_zero_bytes']] = 0
    return pcm, region


def analyze_slot(directory, metadata):
    pcm, region = load_sample(directory, metadata)
    result = analyze_pcm(pcm[region['start']:region['end']])
    playback = original_playback((directory / metadata['resource_file']).read_bytes())
    result.update(resource_sha256=metadata['sha256'], pcm_sha256=metadata['payload_sha256'],
                  playback_pcm_sha256=hashlib.sha256(pcm.tobytes()).hexdigest(),
                  source_playback=playback,
                  region=region, resource_file=metadata['resource_file'],
                  vsco={'family': 'strings', 'artistic_choice': True,
                        'reason': 'neutral sustained orchestral substitution; not source identity'})
    return result


def row_slots(raw_words):
    # Source: extract_score.decode_word, original four-byte sample-number fields.
    slots = set()
    for raw in raw_words:
        word = bytes.fromhex(raw)
        if len(word) != 4:
            raise ValueError('source row word must have four bytes')
        sample_number = (word[2] >> 4) | (word[0] & 0x10)
        if sample_number:
            slots.add(str(sample_number - 1))
    return slots


def used_slots(trace):
    slots = set()
    complete = False
    with trace.open() as stream:
        for line in stream:
            event = json.loads(line)
            if event['event'] == 'trigger':
                slots.add(str(event['slot']))
            elif event['event'] == 'row':
                slots.update(row_slots(event['raw']))
            complete |= event['event'] == 'complete'
    if not complete:
        raise ValueError('calibration requires a completed capture')
    return slots


def capture_identity(trace):
    with trace.open() as stream:
        header = json.loads(stream.readline())
    if header.get('event') != 'header' or not header.get('cue'):
        raise ValueError('capture lacks canonical cue identity')
    return header['cue']


def calibrate_captures(captures, reviews=None, cues=None):
    result = {'format': 'alis-sample-calibration-v1', 'sources': SOURCES, 'cues': {},
              'method': 'YIN fixed-width difference; Hann DFT; full region and two halves',
              'limitations': 'Periodic timbres and harmonic chords can be mathematically identical. '
                             'Accepted means signal evidence supports a root; instrument identity is artistic.'}
    for manifest in sorted(captures.glob('*/samples/manifest.json')):
        if cues and manifest.parent.parent.name not in cues:
            continue
        metadata = json.loads(manifest.read_text())
        trace = manifest.parent.parent / 'score.ndjson'
        identity = capture_identity(trace)
        if identity in result['cues']:
            raise ValueError('duplicate cue capture; select directories explicitly with --cues')
        selected = used_slots(trace)
        slots = {
            slot: analyze_slot(manifest.parent, metadata[slot])
            for slot in sorted(selected, key=int)}
        for slot in slots.values():
            review = (reviews or {}).get(slot['pcm_sha256'])
            if review:
                apply_review(slot, review)
        result['cues'][identity] = {'slots': slots}
    if not result['cues']:
        raise ValueError('no completed capture manifests found')
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--captures', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--reviews', type=Path, help='review objects keyed by decoded PCM SHA256')
    parser.add_argument('--cues', nargs='+', help='explicit completed capture directories')
    args = parser.parse_args()
    reviews = json.loads(args.reviews.read_text()) if args.reviews else None
    result = calibrate_captures(args.captures, reviews, args.cues)
    args.output.write_text(json.dumps(result, indent=2, allow_nan=False) + '\n')
    slots = [s for cue in result['cues'].values() for s in cue['slots'].values()]
    print(json.dumps({'cues': len(result['cues']), 'slots': len(slots),
                      'accepted': sum(s['status'] == 'accepted' for s in slots)}))


if __name__ == '__main__':
    main()
