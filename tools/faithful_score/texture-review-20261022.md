# Original texture retention review, 22 October 2026

This read-only review inspected the nine retained PCM identities against their
existing original-CPU calibration measurements. It supports preserving their
original timbres and resonances. It does not establish that every retained sound
is unpitched, or that every internal musical identity has been resolved.

## Inputs and provenance

Both input files are under the project-owned directory
`disk-hygiene-9t1vpqpm/pitch-calibration/`:

| File | SHA-256 |
| --- | --- |
| `original-preservation-reviews.json` | `3ac28eaa6794668aed13b69c62030104eda754379fea611e84864312ecfb76f3` |
| `calibration-original-cpu.json` | `aea0b3efe68786cb0609f2e610aeabf7b0955f455403b95286dde28b6f25b712` |

The PCM identifiers below are complete `pcm_sha256` values in those files.
Measurements come from the named cue and slot, under `windows`. Their order is
whole extent, first half, then second half. Frequencies are cycles per source
sample; RMS uses signed 8-bit PCM amplitude units. YIN differences and spectral
peak bounds are the existing measured values, rounded here for readability.
No audio was regenerated for this review.

## Findings

| Cue and slot | PCM SHA-256 | Existing measurement evidence | Assessment |
| --- | --- | --- | --- |
| BOJEU slot 5 | `7adc9ae39a693bdebf6fc7c487e1930abdbb42dfc9ab2f3ce9ff37e95e76ddcb` | Stable bands near 0.01977, 0.02898 and 0.03955. YIN differences 0.122/0.125/0.087; fundamental unresolved in every window. RMS 15.63 to 5.03 between halves. | Decaying resonances with late periodicity. Preserve the measured resonances; a claim of absent pitch would exceed this evidence. |
| BOJEU slot 7 | `a5498d1020d377016ab5bf26b60abf4d44aa0bd722c9a367a0be6ec5bd06e206` | YIN differences 0.758/0.797/0.739. First-half peaks span much of the spectrum; final half has no peaks above the recorded quantization bound. | Broadband decaying transient. |
| BOJEU slot 8 | `72fc87eec0ae3d11057c956d56d3c333e9229c5c0b06ff3b40f2aa5301d91070` | YIN differences 0.564/0.612/0.385. Persistent bands near 0.0099, 0.0148 and 0.0471; other bands decay. RMS 17.76 to 6.45. | Resonant transient without a resolved periodic fundamental. |
| BOJEU slot 9 | `2a20ab7da8b968916f89d09238d6796cbc709ff9abde4eea6cf2fd21986971eb` | Original loop begins at 2152 with length 4022. YIN differences 0.324/0.275/0.380. Multiple changing bands around 0.022 to 0.026, with additional energy near 0.034. | Looped texture containing tonal bands. The first two windows have a spectral peak near the YIN estimate, but consistent periodicity remains unresolved. |
| BOLIEU slot 6 | `7ab395e99b9725722461f0b6bd2b7f5c62af91b860487a68fb8c3c8e791f03de` | YIN differences 0.734/0.806/0.503. Spectral peak counts 145/164/71, with changing low-frequency resonances. | Broadband transient with resonant content. |
| BOPRES slot 7 | `61622ddf0904e00e7c34a46fabf76b37692708a22640fd77895292863d95ab9a` | Initial extent 2166 samples. First-half dominant band 0.003723; RMS falls from 59.38 to 2.35. Final half has no peaks above its quantization bound. | Short decaying low resonance. |
| BOPRES slot 8 | `9131a4947dbc1c1b6dc1dd45c6f8e11e025974fa6067644dd7b5eda6daa28f9c` | Initial extent 2944 samples. First-half band 0.008538 reaches 45.6 times the quantization bound; late band 0.009286 reaches 1.9 times. RMS falls from 49.08 to 2.53. YIN differences 0.139/0.131/0.445. | Clearly tonal early resonance followed by decay. Its changing frequency does not establish a separate later note. |
| BOPRES slot 9 | `d2a29c67aacd8a202b560ab8ebf02374cfda1f96d70c49b70ff79cbc382bb36b` | YIN differences 0.683/0.713/0.657. Early peaks are distributed across the spectrum. Final half has no peaks above its quantization bound. | Broadband decaying transient. |
| BOPRES slot 12 | `8221592b57d102dffcbc14762624a0c5d8adeee563fd940aff16d1b88e70ee1d` | Original loop begins at 2 with length 18482. YIN differences 0.666/0.950/0.581. Broad bands around 0.018 to 0.022 persist with changing strengths; half-window RMS 7.51 and 7.95. | Sustained looped texture with drifting spectral bands. |

## Scope of the conclusion

The existing measurements do not positively identify an internal melodic phrase
in these nine resources. Three coarse windows cannot prove the absence of such
a phrase. BOJEU slot 5 and BOPRES slot 8 especially retain measurable tonal
resonances. Keeping the original PCM preserves those details without choosing
replacement pitches or adding onsets.

The resulting asset can be described as an orchestral arrangement with retained
original resonant and percussive textures. A claim that every timbre has been
replaced would be inaccurate. The renderer must retain the original trigger gate
and the measured DMA phase for each preserved source.
