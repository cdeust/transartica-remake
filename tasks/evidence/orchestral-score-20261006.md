# Original sampled orchestral score

The owner requested orchestral music. Five new compositions cover all nine
existing scene cue keys. They are original D-centred melodies and arrangements,
not transcriptions of the historical soundtrack. The playback change is confined
to `game_audio.gd`: select the authored manifest and resolve its public WAV paths.
Effects, cue routing, signed city selectors, music preference, fades and saved
elapsed clocks retain their existing logic.

## Instruments and license

Sixteen real recorded instrument samples come from VSCO2 Community Edition:
violin ensemble, cello ensemble, French horn, flute, harp and timpani. The author
repository and its pinned license identify CC0 1.0 Universal:

- https://versilian-studios.com/vsco-community/
- https://github.com/sgossner/VSCO-2-CE
- https://raw.githubusercontent.com/sgossner/VSCO-2-CE/440300901dfe9275fd84e0b7763af1f8443ae62e/LICENSE

Author WAV revision: `440300901dfe9275fd84e0b7763af1f8443ae62e`.
Author SFZ mapping revision: `6dd651d55dde97fd4028699be9d4481f26917891`.
Recorded sources and dependency environments stay in `.cache/orchestral-score`;
public assets contain only composed stereo masters, a cue manifest and licensing
notes. Sample provenance and hashes are in
`tasks/validation/orchestral-score-20261006/sample-provenance.json`.

An attempted Apple AVAudioUnitSampler render aborted at instrument construction
(`comp != nullptr`). The tested renderer therefore uses the authorized Python
sample-based fallback. It decodes real PCM24 recordings with FFmpeg, reads exact
`pitch_keycenter` values from the author SFZ mappings, resamples recordings to
the score notes, applies articulated envelopes and stereo placement, and adds
circular hall reflections. It synthesizes no instrument oscillators. Most source
filenames use an octave convention different from scientific pitch notation;
harp uses another convention. Reading SFZ roots prevents an audible octave error.

## Artistic choices

Tempo, melody, harmony, dynamics, pan, release shapes and hall reflections are
declared composition/mixing choices rather than reconstructed game rules. Each
score contains two contrasting four-bar phrases in4/4. Exploration uses a minor
motif with flute and bowed ensemble; cities use warmer major harmony; worksite
uses faster harp figures and timpani; danger uses tense altered harmony; title
uses major ensemble/horn voicing. These are modest chamber-orchestra arrangements
whose artistic acceptance requires listening, not waveform tests.

| Composition | Cue keys | BPM | Master seconds | RMS dBFS |
|---|---|---:|---:|---:|
| Exploration | bojeu-0, bojeu-1, bojeu2-0 |84|45.714|−18.94|
| Cities | bolieu-0, bolieu-1, bolieu-3 |76|50.526|−19.80|
| Worksite | bolieu-2 |104|36.923|−17.49|
| Danger | bolost-0 |66|58.182|−17.59|
| Title | bopres-0 |92|41.739|−18.07|

Delivered masters are stereo PCM16 at44.1kHz, totaling41,116,348bytes. Measured
peak is−3.00036dBFS and clipping count is0 in all five. Source repeating flags
and source cue-duration ticks are retained. Exploration/title contain two
bit-identical periods, with the second period selected as the WAV loop region.
Circular rendering carries sample releases and hall reflections across the join.
Exploration wrap step is258 PCM16 units versus normal99th-percentile step2370;
title wrap step is122 versus1256. Non-repeating cities/worksite/danger instead
finish with an artistic two-beat fade to exact stereo zero. Their boundary
measurements are not claims about loops.

## Reproduction and checks

```sh
python3 -m venv .cache/orchestral-score/venv
.cache/orchestral-score/venv/bin/python -m pip install numpy==2.5.3
python3 tools/compose_orchestral_score.py --fetch
.cache/orchestral-score/venv/bin/python tools/compose_orchestral_score.py
.cache/orchestral-score/venv/bin/python tools/analyze_orchestral_score.py
```

The final pipeline regenerated all five WAVs and the cue manifest with identical
SHA256 hashes. `reproducibility.json`, PCM measurements and FFmpeg spectrograms
for all five compositions are retained under
`tasks/validation/orchestral-score-20261006/`. The exploration spectrogram was
visually inspected: changing harmonic stacks, ensemble texture and phrase
repetition are visible; this is not proof of musical quality.

Passing Godot headless checks: `test_orchestral_score`, `test_game_audio`,
`test_audio_session`, `test_source_audio_events`, `test_audio_routes`. The new test verifies all nine
public cue paths, stereo WAV loading, source loop policy, score save restoration,
and actual software-mixer capture (authored PCM peak0.0879543).

Before the fixture correction, `test_audio_routes` failed its single mine-close
assertion with both orchestral and original private manifests: one `_close_mine`
call advances the current mine phase rather than closing it. The owner then
authorized a minimal fixture update: exercise plaque→resources→credited result
before the actual close, checking that the worksite cue persists until departure.
The complete fixture now passes with both manifests. No world logic was changed.
Headless runs also emitted the existing macOS certificate diagnostic and some
audio teardown leak warnings. Native audible listening and exported-build
verification remain the main agent's responsibility; neither is claimed here.

## Independent review

The reviewer reproduced all five WAVs and the manifest byte-for-byte, checked author CC0 permission and SFZ root notes, and verified nine cue policies. A race in the new mixer fixture was reproduced (zero captured PCM once, passing immediately afterwards). The fixture now synchronizes on actual playback and captured PCM frame count. Two fresh runs pass; an independently muted-bus negative control advances playback but fails the nonzero-PCM assertion. This verifies an audible signal reaches the mixer; artistic listening remains separate.

## Exported macOS execution

The exact exported macOS binary passes test_orchestral_score.gd with its native audio driver: real mixer peak0.07851964980364, all nine cues, loop policy and save restoration pass. Normal book resume47212 preserves bojeu-1 and enables playback; OPTIONS input47218/47219 toggles the preference off/on. No human artistic listening is claimed. Exploration preview: .cache/public-release/orchestral-exploration-preview.mp3. Independent public-pack inspection confirms all authored score resources are present in both exports and original data is absent.

The composer was split into sample decoding, individual-note rendering, phrase accumulation and metrics to satisfy the source-tool size limits. Independent before/after rendering preserves all14 WAV/JSON outputs bit-for-bit and matches all six delivered WAV/manifest files. Proof: .cache/orchestral-refactor-proof-20261006/verification.json.
