#!/usr/bin/env python3
"""MIT. Transfer pitch candidates across verified host/original PCM correspondence.

This never transfers an acceptance result. All candidates must be measured again
by calibrate.py or temporal_evidence.py on the original-CPU-decoded samples.
The byte audit records known host zero substitutions and divergent suffixes.
Other differences require an explicit original script/resource identity in the
original-CPU manifest. Such migration still transfers candidate seeds only.
"""
import argparse
import copy
import hashlib
import json
from pathlib import Path


def compare_payloads(old, new, valid_host_bytes=None):
    if len(new) < len(old):
        raise ValueError('original PCM unexpectedly shorter than host dump')
    extent = len(old) if valid_host_bytes is None else valid_host_bytes
    if not 0 < extent <= len(old):
        raise ValueError('invalid host-proven playback extent')
    replacements = 0
    for index, before in enumerate(old[:extent]):
        after = new[index]
        if before != after:
            if (before, after) != (1, 0):
                raise ValueError(f'unexplained PCM difference at byte {index}: {before} -> {after}')
            replacements += 1
    return {'common_prefix_bytes': extent, 'host_zero_to_one_bytes': replacements,
            'host_uncompared_suffix_bytes': len(old) - extent,
            'original_uncompared_suffix_bytes': len(new) - extent,
            'original_suffix_bytes': len(new) - len(old),
            'old_pcm_sha256': hashlib.sha256(old).hexdigest(),
            'new_pcm_sha256': hashlib.sha256(new).hexdigest()}


def divergent_indices(old, new):
    return [index for index, (a, b) in enumerate(zip(old, new))
            if a != b and (a, b) != (1, 0)]


def compare_source(old, new, old_metadata, metadata):
    old_hash = old_metadata['payload_sha256']
    # The host dump labels trailing allocation bytes as payload although
    # its mixer does not play them. Do not claim correspondence there.
    audible_extent = max(old_metadata['initial_pcm_end'],
                          old_metadata['loop_pcm_start'] + old_metadata['loop_pcm_length'])
    try:
        comparison = compare_payloads(old, new, audible_extent)
    except ValueError as error:
        required = ('original_script', 'original_resource', 'decoder', 'host_payload_sha256')
        if any(key not in metadata for key in required) or metadata['host_payload_sha256'] != old_hash:
            raise ValueError('different PCM lacks explicit original resource identity') from error
        differences = divergent_indices(old, new)
        comparison = {
            'old_pcm_sha256': hashlib.sha256(old).hexdigest(),
            'new_pcm_sha256': hashlib.sha256(new).hexdigest(),
            'byte_audit': str(error), 'non_zero_substitution_differences': len(differences),
            'first_difference': differences[0] if differences else None,
            'last_difference': differences[-1] if differences else None,
            'correspondence_basis': 'Original script/resource identity; byte equality not claimed.',
            'original_script': metadata['original_script'],
            'original_resource': metadata['original_resource'], 'decoder': metadata['decoder']}
    return comparison


def migrate(host_captures, original_captures, reviews):
    migrated, comparisons = {}, []
    matched = set()
    for directory in sorted(original_captures.glob('*-final')):
        original_dir = directory / 'samples'
        host_dir = host_captures / directory.name / 'samples'
        original = json.loads((original_dir / 'manifest.json').read_text())
        host = json.loads((host_dir / 'manifest.json').read_text())
        for slot, metadata in original.items():
            old_metadata = host[slot]
            old_hash = old_metadata['payload_sha256']
            if old_hash not in reviews:
                continue
            old = (host_dir / old_metadata['resource_file']).read_bytes()[16:]
            new = (original_dir / metadata['resource_file']).read_bytes()[16:]
            comparison = compare_source(old, new, old_metadata, metadata)
            new_hash = metadata['payload_sha256']
            if (comparison['old_pcm_sha256'] != old_hash or
                    comparison['new_pcm_sha256'] != new_hash):
                raise ValueError('migration source hash mismatch')
            comparison.update(cue=directory.name.removesuffix('-final'), slot=slot)
            comparisons.append(comparison)
            matched.add(old_hash)
            if new_hash not in migrated:
                review = copy.deepcopy(reviews[old_hash])
                review['migration'] = dict(comparison, acceptance_transferred=False,
                                           requires='Recompute all source-spectrum evidence on new PCM.')
                migrated[new_hash] = review
    if matched != set(reviews):
        raise ValueError(f'review seeds without source correspondence: {sorted(set(reviews)-matched)}')
    return migrated, comparisons


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--host-captures', type=Path, required=True)
    parser.add_argument('--original-captures', type=Path, required=True)
    parser.add_argument('--reviews', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    migrated, comparisons = migrate(args.host_captures, args.original_captures,
                                    json.loads(args.reviews.read_text()))
    args.output.write_text(json.dumps(migrated, indent=2, allow_nan=False) + '\n')
    args.output.with_suffix('.migration.json').write_text(json.dumps(comparisons, indent=2) + '\n')
    print(json.dumps({'candidate_hashes': len(migrated), 'verified_correspondences': len(comparisons),
                      'acceptance_transferred': False}))


if __name__ == '__main__':
    main()
