# Historical ALIS host extraction

This host-reader audit is retained for raw resource comparison. Its sample
decoder and effect behavior are superseded for rendering by the original Amiga
CPU execution described in [AMIGA_PLAYER.md](AMIGA_PLAYER.md). Do not calibrate
or deliver new masters from these host PCM dumps.

`extract_score.py prepare` reads the nine original tracker resources and writes
an audit containing every referenced pattern word, its source offset, and hashes.
It copies ALIS into the specified new scratch directory and inserts passive calls
from `observe_score.h`. The original reader and original game data are untouched.
The preview launcher executes the original instrument setup and music calls.

```sh
python3 tools/faithful_score/extract_score.py prepare \
  --source /absolute/project/reference-private --scratch /absolute/owned/scratch/alis-capture
cmake -S /absolute/owned/scratch/alis-capture/reader \
  -B /absolute/owned/scratch/alis-capture/build -DCMAKE_BUILD_TYPE=Release
cmake --build /absolute/owned/scratch/alis-capture/build --parallel 1
SDL_VIDEODRIVER=dummy SDL_AUDIODRIVER=dummy SDL_RENDER_DRIVER=software \
  python3 tools/faithful_score/extract_score.py capture \
  --scratch /absolute/owned/scratch/alis-capture \
  --binary /absolute/owned/scratch/alis-capture/build/alis --cue bojeu-0
```

Run build/capture commands through the project's process-group memory guard,
serially. A timeout is failure, never a musical completion signal. Each capture
directory must be new. The observer stops on two source cycles for travel/title,
one cycle for BOLOST (matching the earlier capture protocol), and native stop for
BOLIEU. This protocol does not claim that BOLOST's complete duration operand has
elapsed. No wall-clock timestamp enters the score.

`capture --offline` pauses the SDL audio device while music is still inactive,
then calls the original `audio.soundrout` repeatedly after initialization. The
preview script otherwise yields forever and supplies no later music controls.
The device stays paused, preventing concurrent callbacks. BOJEU0's full event
stream was compared with a real-time SDL dummy capture: row bytes, triggers,
voice ticks, sample hashes and both cycle frames matched exactly. The comparison
excluded provenance headers and the earlier observer's redundant end markers.
`--output-name` allows retaining a separate comparison capture without overwrite.

Loop observation runs after each original fill, matching the earlier loop
observer. This matters for BOJEU2: B01 changes the internal order to zero and the
next decoded row starts at order one. Waiting for a decoded order-zero row would
miss the loop and incorrectly include the full duration-counter playback.

## Trace contract (version 1)

`captures/<cue>/score.ndjson` begins with `header`: rate 44100, cue identity,
original script SHA, source-reader file hashes, observer hash and compiled reader
hash. Frame zero is the first generated music buffer, excluding device silence.

| Event | Fields and meaning |
|---|---|
| start | Original initial tempo, speed, attack/duration/release counters, buffer frames |
| instrument | Slot, loaded memory address, type, transposition, original header bytes, dump file and hashes |
| row | Frame, order, pattern, row and four original hexadecimal words |
| trigger | Frame, voice, monotonic per-voice serial, slot, resolved period, rate_q16, sample pointers/remaining lengths |
| tick | Frame, frames, mixed, global_volume, speed, four voice states including serial/slot, period, rate_q16, volume/effect/delta and sample cursor fields |
| endvoice | Exact generated frame, voice and serial at sample exhaustion |
| loop | Frame and source order-zero cycle number |
| stop | Native music stop frame |
| complete | Semantic completion frame and reason |

`rate_q16` is the actual mixer table value after the reader's period resolution;
it is not a MIDI pitch. `volume` and `global_volume` retain the source integer
scales. `tick` is emitted before mixing. `mixed=false` means the reader skipped
mixing because speed was zero and retained its existing buffer. Source effects
must not be extrapolated across those ticks. Events emitted while mixing different
voices can be out of frame order; consumers must preserve serial identities and
order by frame when needed. A zero serial represents a voice never triggered.

Every executed row is compared with the immutable resource audit. Each nonzero
period word requires its own trigger, including identical repeated notes. Serial
gaps, omitted triggers, changed bytes and discontinuous buffer frames fail capture.
`validation.json` records the resulting counts and cycle boundaries.

## Loaded instrument data

`samples/slot-N.bin` dumps the complete resource from `tabinst.address - 16`,
after the original loader's Fibonacci/invdigit conversion. The earlier standalone
WAV exporter does not perform that conversion and must not be used for calibration.
`samples/manifest.json` maps slots to metadata and hashes. `payload_offset=16` and
`pcm_bytes=resource_bytes-16` describe the canonical signed-eight-bit PCM payload.

The actual mixer's indexing in `music_v2.c:mv2_soundcal` is:

```
absolute byte read = resource_base + resource_bytes - 17 - longsam1
payload-relative index = resource_bytes - 33 - longsam1
```

`longsam1` is decremented before reading. The `startsam1` term cancels algebraically;
its initial value at resource_base+32 does not mean the first 16 PCM bytes are
skipped. `initial_pcm_end=resource_bytes-32` marks the initial traversal endpoint
relative to PCM. The nominal looping interval is `loop_pcm_start` through
`loop_pcm_start+loop_pcm_length`, where length is header end minus header start and
start is `resource_bytes-32-length`. The mixer uses length minus one when wrapping.
Keep the raw header and cursor fields when reproducing exact sample stepping.

## Fidelity boundary

All nine scores use type 4 resources. BOJEU13 contains raw command 0472;
BOJEU2/14 contains 0471; E01 occurs in BOJEU13, BOJEU2/14 and BOLIEU10/12.
The pinned reader ignores effect 4 and E; effect 6 only slides volume. The observer
retains these commands without implementing new semantics. A trace is evidence of
this reader's execution. Original Amiga effect fidelity requires resolving those
commands separately. Periods remain source values until instrument calibration.

Sources: `reference-private/alis-source/src/alis.c:adresmus`,
`src/opcodes.c:music/cinstru`, `src/audio/music_v2.c`,
`tools/prepare_music_preview.py`, `tools/package_music_capture.py`, and
`tasks/validation/audio-recovery-source-20261001.md`.

## Measured extraction, 22 October 2026

`extraction-validation-20261022.json` preserves source/binary/trace hashes and
per-cue counts. All nine final captures passed original-word and trigger checks.
The four cyclic cues reproduce both historical raw loop boundaries exactly.
The final BOJEU0 trace matches the real-time pilot per event type, including every
field after excluding provenance headers and duplicate/zero-serial end markers.
Four unit tests pass, including compiling and executing the actual C observer
for identical repeated notes, end-marker deduplication and the B01 loop case.
All 68 original ALIS source-file hashes remain unchanged.

The real-time pilot took 170.983 seconds. The final nine offline captures took
3.873 seconds together with a process-group peak of 52,688 KiB under a 1 GiB cap.
This measures extraction scheduling only; it is not a playback or fidelity gain.
