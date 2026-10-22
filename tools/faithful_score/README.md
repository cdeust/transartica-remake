# Historical score orchestration

The native build consumes the nine committed WAV masters selected by
`game/assets/audio/orchestral/music.json`. It needs no emulator, sample-library
download or Python audio tool at runtime.

The offline renderer changes instrumentation using recorded VSCO2 CE samples.
Original T.X execution supplies the tracker events and sample playback rates.
Measured source PCM supplies tonal roots and the internal notes of sampled
phrases. It does not compose a replacement theme or round pitches onto MIDI.
Original resonant and percussive textures remain in the arrangement.

## Evidence boundary

[AMIGA_PLAYER.md](AMIGA_PLAYER.md) documents original CPU execution and its
nominal PAL timing. Sub-tick DMA startup and analog hardware coloration are
outside this arrangement. Internal phrase onsets have finite measurement
bounds; these are recorded estimates, not recovered published sheet music.
[texture-review-20261022.md](texture-review-20261022.md) identifies retained
source textures and the limits of their classification.

`timeline.py` preserves each original voice serial and its gate. Static chords
use independently measured components. `phrase_renderer.py` maps measured
internal source positions through the original changing DMA rate. Instrument
recordings start at those positions and stop at the source gate. SFZ author
pitch roots determine their transposition. A recording that cannot cover the
complete audible note is rejected; the renderer does not create a sustain loop.

Every render receipt binds its trace and calibration hashes, records each
orchestral component or retained source, and checks trigger identities against
the original trace. The WAV is stereo PCM16 at 44100 Hz with the existing
project mastering headroom of -3 dBFS. Those are rendering choices, separate
from the original score events.

## Reproduction

The validated environment uses Python 3.14, NumPy 2.5.3, FFmpeg 8.1 and
machine68k 0.4.0. The original game inputs remain separately identified reference
material. The committed masters provide the complete runtime without them.
The sample source URLs and hashes accompany the delivered cue manifest.

First capture with `amiga_capture.py` as documented in AMIGA_PLAYER.md. Rebuild
calibration from the hash-bound reviews in `calibration-evidence/`, then render
serially through the project's 1 GiB process-group guard:

```sh
python tools/faithful_score/render_score.py \
  --trace CAPTURE/bojeu-0-final/score.ndjson \
  --calibration CALIBRATION/orchestration-final-contract.json \
  --samples SAMPLE_CACHE --cue bojeu-0 \
  --output NEW_OUTPUT/bojeu-0.wav --allow-preserved-source
```

The explicit preservation flag enables only reviewed original textures. An
unresolved instrument without an approved rendering mode remains an error.
All nine cue identities require their own render. BOPRES is finite; travel and
loss themes use the original observed repeat boundaries. The four BOLIEU cues
end at the original stop.

For source-dependent tests, set `ALIS_REFERENCE_SOURCE` and `ALIS_CAPTURE_ROOT`
as described in AMIGA_PLAYER.md. The capture root for the original-loader
corroboration tests is the retained host audit. Run `unittest discover` in this
directory with the NumPy interpreter and pinned machine68k on its import path.
No skipped source test constitutes original-game validation.
