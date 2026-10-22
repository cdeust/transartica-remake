# Original music calibration, 22 October 2026

The frozen render contract covers nine cues and 83 route-specific slots from 43
original PCM hashes. It assigns 59 slots to static orchestral notes, four to
measured internal phrases and twenty to preserved original textures. The four
BOJEU2 phrases contain respectively 4, 6, 5 and 6 notes in slots 6, 11, 12 and 13.
The contract SHA256 is
`9db16b736c312f824f62eb0c72f3013f923dbb941a904d5f2c29574965cb9719`.

The authoritative captures are `effects-review/amiga-final-v2` under the owned
session scratch directory. They execute the original T.X decompressor at
hunk 0 `0xdee..0xef2` and player under Musashi. The host ALIS reader changes zero
PCM samples to one and truncates sixteen bytes. Its old acceptance results were
not transferred: candidate seeds were migrated by source identity and then
remeasured on original CPU output. The immutable resource and payload hashes
remain distinct from playback PCM, whose first four bytes the original startup
at hunk 2 `0x1f34` clears.

DMA extents follow original T.X hunk 2 `0x232a..0x237a`. For BOJEU slot 0 the
original resource contains 8560 bytes; initial playback is 8516 PCM bytes, and
the loop starts at PCM byte 3100 for 5418 bytes. These values supersede the
intermediate host-decoded measurements. Instrument-only original words are
included in the calibration inventory.

Pitch evidence uses full-region and independent half-region spectra, together
with YIN periodicity where applicable. Near-pure tones have an explicit
strongest-band review instead of invented missing harmonics. The analysis uses
Julius O. Smith's [Hann window](https://www.dsprelated.com/freebooks/sasp/Hann_Hanning_Raised_Cosine.html)
and [quadratic peak interpolation](https://www.dsprelated.com/freebooks/sasp/Sinusoidal_Peak_Interpolation.html),
equations 6.30 and 6.31. Magnitude acceptance is tied to the signed-eight-bit
quantization bound. Reviewed frequencies are not snapped to MIDI notes.

Internal phrases use independently reviewed fundamental and partial-envelope
attacks. Each note stores absolute source-frame support, an onset uncertainty
interval and a measured gain curve. Per-band Hann resolution prevents a close
low-frequency pair from blurring separate upper-note attacks. Slot 6's middle
notes use independently resolved third-partial support: starts 1740 and 3190,
with bounds [1450, 2031] and [2900, 3481]. Slot 11's upper notes start at 4944,
5264 and 6693. Gain weights retain the relative measured peak amplitudes.
Orchestral instrument families are arrangement choices, not identified source
instruments.

Slot 12 supports five notes. Its proposed sixth frequency near 0.03727 lacks a
resolved independent 2f/6f/10f attack family. Weak nearby bands drift through
0.038139, 0.038580 and 0.039146; the contract records them as unresolved timbral
or attack energy. It neither invents a sixth note nor claims that residual to
be an exact lower-note harmonic.

The retained source samples require qualified descriptions:

| Source sample | Evidence and limit |
| --- | --- |
| BOJEU 7, BOPRES 9 | Broadband transient spectra and poor periodicity support a percussion/noise interpretation. |
| BOJEU 5, 8; BOPRES 7, 8 | Decaying inharmonic or resonant transients; some resonances are pitched. |
| BOJEU 9, BOPRES 12 | Looped, drifting spectral textures; tuned material cannot be excluded. |
| BOLIEU 6 | Changing low resonances and broadband energy; original instrument identity is unresolved. |

This is an orchestral arrangement with retained original resonant/percussive
textures. The phrase transcription is measured musical inference within stated
frequency and onset bounds. It is not recovered published sheet music, and it
does not replace every original timbre.

## Reproduction

Use the session's NumPy environment and the existing 1 GiB process-group guard
for spectral commands. Set `capture_dir` to the final-v2 capture directory and
`evidence_dir` to the retained pitch-calibration artifacts. Run from
`tools/faithful_score`; review JSON inputs are also preserved beside this file.

```sh
python calibrate.py --captures "$capture_dir" --reviews "$evidence_dir/original-reviews.json" --output "$evidence_dir/calibration-original-cpu.json"
python temporal_evidence.py --captures "$capture_dir" --calibration "$evidence_dir/calibration-original-cpu.json" --reviews "$evidence_dir/original-temporal-reviews.json" --output "$evidence_dir/temporal-original-cpu.json"
python assemble_calibration.py --calibration "$evidence_dir/calibration-original-cpu.json" --temporal "$evidence_dir/temporal-original-cpu.json" --preservation "$evidence_dir/original-preservation-reviews.json" --output "$evidence_dir/orchestration-original-cpu-contract.json"
python temporal_evidence.py --captures "$capture_dir" --calibration "$evidence_dir/calibration-original-cpu.json" --reviews "$evidence_dir/original-phrase-candidates.json" --local-resolution --output "$evidence_dir/phrase-original-cpu-measurements-local.json"
python transcribe_phrases.py --contract "$evidence_dir/orchestration-original-cpu-contract.json" --temporal "$evidence_dir/phrase-original-cpu-measurements-local.json" --onset-refinements "$evidence_dir/original-onset-refinements.json" --output "$evidence_dir/orchestration-final-contract.json"
python -m unittest test_calibrate test_temporal_evidence test_assemble_calibration test_migrate_review_seeds test_transcribe_phrases
```

The final test run passed 32 tests in 0.075 seconds with no failures or skips.
The source and craftsmanship checkers each reported zero errors and warnings.
After helper refactoring, the final JSON contract regenerated byte-for-byte
identically. The short test run undersampled peak RSS, so it is not a memory
benchmark. Artifact paths and SHA256 hashes are recorded in `receipt.json`.

The final hash-bound phrase control check passed all 50 original triggers and
228 component mappings. It validates source extents and onset/gain contracts
using deterministic injected PCM. Its receipt is
`phrase-control-validation-final.json`; orchestral listening is a separate check.
