# Original Amiga score execution

`amiga_capture.py` executes the original T.X music routines and sample decoder
with machine68k 0.4.0 (Musashi), then records their register output. It does not
implement substitute tracker effects. The game build does not depend on this
emulator; it consumes the rendered resources.

The input executable is extracted from original `disk1.adf` OFS file header 1148.
Its SHA256 must equal
`741f28adae86c8954cfeb90de6f9ba8f64f98abadb4eafab1d018381b4505071`.
Four original hunks are relocated into separate harness regions. Hunk2 begins
at file offset0xb3a4, with 10172 bytes. Addresses below are hunk-relative.

## Primary executable evidence

| Behavior | Original location |
|---|---|
| Music called from level3 interrupt | hunk0:0xbc0..0xbf8, music call0xbdc |
| Instrument decompression: only resource types 1/2 | hunk0:0xdee..0xef2 |
| Resource lookup returns address without modifying data | hunk1:0x450a..0x452c |
| CMUSIC argument setup and direct resource+6 pointer | hunk1:0x46d2..0x4796 |
| Startup zeroes first 4 PCM bytes per instrument | hunk2:0x1f2a..0x1f3a |
| F00 stops on next tick, mutes volume and disables DMA | hunk2:0x2118..0x211e,0x2006..0x2052 |
| Row processing overwrites the entire raw word, including zeros | hunk2:0x230e |
| Instrument-only setup resets volume without retrigger | hunk2:0x2314..0x2392 |
| Initial DMA length and loop registers | hunk2:0x2334..0x237a |
| Note retrigger resets vibrato phase | hunk2:0x23b6..0x23d6 |
| Effect 4 vibrato and effect 6 combined vibrato/volume slide | hunk2:0x2498..0x24e0,0x2560..0x256a,0x25da |
| E writes parameter bit 0 to CIAA PRA bit 1 | hunk2:0x266a..0x2682 |
| F clamps parameter to 31 and scales by original tempo/32 | hunk2:0x26c8..0x26e4 |
| Pattern completion copies original restart byte | hunk2:0x21e4..0x2218 |

The original restart byte is 0x7f in all nine resources. The executable copies
it into the order position when reaching the declared order count. The next
row therefore reads order 127, whose table entry is 0, before wrapping to order 0.
BOJEU2's B01 command instead returns to order 1. These observed transitions are
retained. The host reader previously skipped order 127.

BOPRES byte 0xc8 calls music with resource 0, volume 127, tempo 32, attack 20,
duration 10000 and release 100, followed by sleep at 0xd6 and exit at 0xd7. The
captured original player reaches its native stop before completing two cycles.
Its trace is finite; it does not authorize looping the delivered title track.

## Samples and timing

`amiga_samples.py` executes original hunk0:0xdee to decompress each bank.
The source cinstru mapping is checked against a corresponding prefix of the
historical host dump, accounting for the host's zero-to-one mutation. This
comparison corroborates routing; original CPU output supplies the new samples.
Original PCM hashes are recorded beside the old host hashes. The host's
`invdigit` length subtraction and tail mutations are not applied.

Original sample metadata is big-endian: total length at+2, loop start at+8,
loop end at+12, PCM at+16. Initial DMA length is `(total-16)/2` words when loop
start is zero, otherwise `loop_end/2`. Loop length is
`(loop_end-loop_start)/2+1` words. The integer divisions are the original shifts.
A zero-start/zero-end sample returns to a silent two-byte loop because startup
clears its first 4 bytes. The capture emits the exact output-frame boundary at
which that initial sample ends.

The PAL sample clock is 3546895 Hz and sample rate is clock divided by period.
The rational step is retained as 3546895/(period*44100), with no MIDI rounding.
Volume comes directly from AUDxVOL/64. These register interpretations follow
Commodore's [Hardware Reference Manual, chapter5, pp137–139](https://www.amigarealm.com/computing/knowledge/hardref/ch5.htm).

A trace tick uses nominal 50 Hz PAL scheduling, or 882 frames at 44100 Hz. The
original first row occurs on the sixth tick. Original CIA setup handlers run,
but their delay within a tick is omitted from the musical timeline. DMA sample
positions are calculated from the recorded period and original loop registers.
This is original score execution with a musical sample-clock model, not a
cycle-accurate Amiga audio or analog-filter recording. Simultaneous sound effects
are outside an isolated music cue.

## Reproduction

Install pinned `machine68k==0.4.0` in an owned tool environment. Its source is
[cnvogelg/machine68k](https://github.com/cnvogelg/machine68k). Keep original data
outside published tooling. Run serially through the project's 1 GiB guard:

```sh
python3 tools/faithful_score/amiga_capture.py \
  --source /absolute/project/reference-private \
  --host-capture /absolute/owned/alis-capture \
  --cue bojeu-0 --output /absolute/new/capture/bojeu-0-final
```

The host capture supplies authenticated cue initialization and historical slot
corroboration; original T.X supplies sample decompression and playback behavior.
Run tests with `ALIS_REFERENCE_SOURCE` pointing to reference-private and
`ALIS_CAPTURE_ROOT` pointing to the original alis-capture audit directory.
The pinned machine68k module must be on that Python interpreter's import path.

## Trace additions

Version 2 keeps canonical cue identities and original instrument SHA metadata.
Each active voice includes `gain`, `rate_numerator`, `rate_denominator`,
`source_position` and `source_segment_end`. The last two are relative to the
instrument PCM payload. A span advances to its current segment end, then wraps
to `loop_pcm_start` for `loop_pcm_length`. `playback_zero_prefix=4` applies only
when reading playback PCM; the archived source bytes and hashes remain intact.
A source note is closed by the next trigger, an endvoice event, or native stop.
The source does not acquire an additional note when an instrument-only command
resets its current volume.
