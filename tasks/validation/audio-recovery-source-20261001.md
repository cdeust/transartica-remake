# Audio recovery, 1 October 2026

Reference: original English ECS private ALIS scripts, original interpreter
`reference-private/alis-source/src/audio/music_v2.c` and
`src/sys/sys.c` (music-buffer copy at611..676).

## Original score loops

Four looping selections (BOJEU0/1, BOJEU2 and BOPRES) now preserve the first
attack once, then repeat the captured second source cycle. The observer calls
the native callback and score fill unchanged; it records source order-zero
wraps at exact generated sample positions after existing buffer leftovers.
Both wraps require `attack_remaining=0`; SDL_QUIT occurs after the second wrap.
All four logs attest completion and native VM memory release. Their source
sample boundaries and PCM hashes are in `music-loop-boundaries-20261001.json`.
`music-loop-package-proof-20261001.log` compares every packaged PCM byte with
native capture, checks WAV format and loop end, and confirms both private
mirrors retain all nine source score selections. These are recordings of the
native ALIS mixer, not original Amiga hardware recordings.

The observer C file passes clang `-Wall -Wextra -Werror -fsyntax-only` with the
pinned source headers. The packaging tool stages validation of all four native
captures before writing replacements. It also updates measured capture/loop
seconds instead of retaining the old single-cycle durations.

## Effects connected to source transitions

| Source | Production transition |
|---|---|
| SCENE1 selector1, sound92 | Actual mammoth question opens once; UI restore does not replay it |
| SCENE1 selector2, sounda1 | Campaign wolf scene entry |
| SCENE1 selector3, soundb0 | Original heavy-train slope scene |
| SCENE2 selectors2..4, soundb5 | Crevasse/lake/destroyed-track question24..26 |
| YODA1323/134b, SCENE2 selector1 → SBAL18 | Timed bridge `inform(52)`; original scene already existed outside CampaignState |
| SCENE4 header task3d4, selector1, rnd10 gate | Oslo random native sound at original50Hz callback cadence |
| SCENE4 selector2 | Mole scene stays silent; Oslo-only randomized cue is not reused |
| TRAINc78/d5a andc9e/d7f | Source shovel pickup/deposit calls at poses1/4, source wait5−2×rate ticks |
| TRAINd3..128 → SON2/8 | Moving entry selectsSON8; stationary reserve≥1500 selectsSON2; low-reserve idle is silent |
| WDECOR51eb/5640 →60ab/60b7 | Player/enemy machine gun at source reload12 |
| WDECOR52df/5715 →60c3/60cf | Player/enemy cannon onset at source reload23 |
| WDECOR5373/5791 →60db | Cannon impact before hull change |
| WDECORccb→60f5 | Wagon destruction |
| YODA18c7/18cc → SON1 | Actual city/nomad departure and workshop exit |
| YODAc70..c93 → SON3 | First successful Oslo dismissal; prior25910 flag distinction retained in pending state |
| YODA1d64..1d71 → SON3 | Positive room footer dispatch once; integrated by room owner |

Tactical audio dispatch is a model signal observed by the scene. It consumes no
combat RNG and changes no combat rules or snapshot structure. Opening OPTIONS
and returning to the same tactical state does not reconnect/restart battle
ambient. The native full-host cadence regression and tactical rules/JSON
regression pass after these additions.

SON reads pitch from local12. Both the helper and JSON operand boundary now use
that source offset. Numeric JSON offsets are canonicalized to integer keys;
otherwise12.0 looked up a nonexistent string key and silently discarded pitch.
The native regression previously measured0.8 instead of requested1.2; it now
passes the source pitch comparison. SON cancellation verification waits for
the source sequence completion signal instead of an arbitrary0.15-second delay.

## Final validation

`test_game_audio-audio-final-20261001.log` checks actual nonzero native mixer
output, four channels, source rates, supplied SON pitch, initial attack and
second-cycle player loop bounds, and restored cursor position within that loop.
`test_source_audio_events-audio-final-20261001.log` checks actual bridge/mammoth
transitions, wolf/slope cues, silent mole, Oslo callback, tactical cannon source
signals and native waveform, TRAIN pickup/deposit phase pitches, and positive room
footer dispatch. Negative footer codes remain silent. First-Oslo cue validation
includes actual schema9 JSON staging, invalid-marker atomic rejection, and
exactly one dismissal after resume.
`test_restore_city-audio-final-20261001.log` retains real nomad/hunt save behavior.
`test_application_cadence-audio-final-20261001.log` retains30/60/144Hz equivalence.
`test_works_commit-audio-final-20261001.log` retains original map commit behavior.
Native audio schema9 and routing logs also pass in the final recovery series.

No remote publication or commit performed by this worker. Historical datasets
and original waveforms remain inside ignored private directories.


Reproduction from the project root (all generated fixtures stay private):

```sh
mkdir -p .cache/music-loop
clang -dynamiclib -Ireference-private/alis-source/src -I/opt/homebrew/include \
  -L/opt/homebrew/lib -lSDL2 tools/capture_alis_music_loop.c \
  -o .cache/music-loop/observe.dylib
python3 tools/prepare_music_preview.py --source reference-private \
  --output .cache/music-loop/bojeu-1 --script bojeu --selection 1
DYLD_INSERT_LIBRARIES="$PWD/.cache/music-loop/observe.dylib" \
  ALIS_CAPTURE_PCM="$PWD/.cache/music-loop/bojeu-1.raw" \
  ALIS_CAPTURE_LOOP_METADATA="$PWD/.cache/music-loop/bojeu-1.json" \
  .toolchain/alis/alis .cache/music-loop/bojeu-1/ \
  > .cache/music-loop/bojeu-1.log 2>&1
```

Repeat with `(script,selector,key)` equal to `(bojeu,0,bojeu-0)`,
`(bojeu2,0,bojeu2-0)` and `(bopres,0,bopres-0)`, then run
`python3 tools/package_music_loops.py --captures .cache/music-loop --output reference-private/audio`.
No wall-clock limit decides acceptance; the source wrap triggers completion.
Executed observer/interpreter hashes and observer source hash are retained in
`music-loop-execution-identities-20261001.json`.

First-delivery source cue validation passes through actual schema9 staging:
its optional pending boolean survives JSON restore, invalid values leave live
state unchanged, dismissal consumes it once, and repeat delivery stays silent.
The message91 guard normalizes integer JSON values before comparing; direct
Array comparison rejected the valid float-decoded integer IDs initially.
Older saved pending events without the optional flag remain accepted without
inventing an unrecoverable prior source flag.

Owned native source-loop capture fixtures removed after checking no open handles: 54,008,574 bytes. Final private WAVs, source-boundary metadata and byte-comparison evidence are retained.

Native room regression surfaced two assertions for the room owner: obsolete
original plan_texture requirement after authored overview replacement, and
full save snapshot equality while the independently processed audio cursor
advances. See `test_boudoir-audio-final-20261001.log`. These are not accepted
as passing room verification; parent received the exact failures.
