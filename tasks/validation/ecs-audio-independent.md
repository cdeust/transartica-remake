# Independent ECS audio branch audit

2026-10-01. Read-only audit of the English ECS unpacked MAIN, YODA, OPTION,
BOJEU, BOJEU2 and BOPRES scripts against the pinned interpreter. No application
code changed. The corrected campaign-owner `alis_disasm.py` decoded the missing
no-payload `ofree` and `oconfig` operands; older `.cache/city-scripts/main.txt`
omits these blocks and must not be used to infer their absence.

## Verified platform path

`reference-private/alis-source/src/sys/sys.c:1240`, `sys_get_model`, returns 3000
for EPlatformAmiga. `script.c:888` zeroes the script virtual RAM on activation.
MAIN 0x3a0 tests model < 2000; its false branch at 0x3a8 jumps to 0x412. Therefore
the setter of local 25936 to 1 at 0x3b8 belongs to the Atari path and is skipped
by ECS. MAIN 0x412 tests model < 3000; ECS skips the setter of 25915 at 0x41e.
MAIN 0x48e tests model < 4000, entering the ECS branch at 0x49a and setting the
main direct byte 15 to 1, local 25918 to 4, local 25935 to 16 and volume 25934
to 50 at 0x4b0. The local capability flag 25936 remains zero on this path.

MAIN 0x4c3 tests `ofree(0) > 700`. Success sets 25917 to 1 at 0x4d1; failure sets
25916 to 1 at 0x4db. `opernames.c:540` defines this operation as
`(finmem - finprog) / 1000` for argument zero. MAIN 0x4e1 separately tests > 720,
setting direct byte 19 at 0x4ef. These are memory conditions, not platform names.

## Original MAIN native observation

The existing `.toolchain/alis/alis` ran original
`reference-private/game-data/main.co` through the normal game-data entry point.
A temporary SDL_RenderPresent observer read original VM memory and posted quit
after the first rendered frame with the initialized volume and memory flag.
It wrote no game state and injected no input or capability flags. Process exited
0. Observer source and raw log are in `.cache/audio-main-audit/`.

Measured line:

```text
MAIN_NATIVE_FLAGS model_kind=2 version=22 volume=50 music_disabled=0 hardware25915=0 lowmem25916=0 highmem25917=1 capability25936=0 current_free_k=3925 finmem=4157080 finprog=231336
```

The current free-memory number is observed at rendering, after the script's
threshold decision; it is not claimed as the exact accumulator at 0x4c3.
`alis.c:258` sets finmem from host RAM rather than the platform table's nominal
Amiga RAM. This run proves the pinned native interpreter's default ECS startup
path. A physical Amiga 500 memory measurement was not performed.

## Music dispatch and toggle

YODA 0x2f9 checks 25917; 0x319 checks music-disabled 25912 = 0 and 25936 = 0.
It loads BOJEU2 and BOLIEU at 0x32f/0x33c. YODA 0x383 checks those capability
conditions and starts BOJEU2 at 0x399. This path is enabled by the measured
startup flags. A conclusion that default ECS always blocks BOJEU is false.
YODA 0xb54 alternates BOJEU/BOJEU2 when memory flag 25917 is set, 25936 is zero,
music is enabled and local 0x29 is zero. The matching playback checks are at
0xd04. BOJEU 0x5c/0x6f selects music resource 13/14; BOJEU2 0x4e selects resource
14. Both use MAIN volume 25934, which is 50 on the ECS path.

ABOJEU loading at YODA 0x2bc/0x2c4 follows the alternative 25915 != 0 branch.
YODA 0xba4/0xbc2 and 0xd47 repeat that hardware branch with direct byte 20 != 0.
These do not establish an ECS ABOJEU path.

OPTION 0xf3 reads 25912. 0xfb sets it to zero and erases overlay 3; 0x108 sets
it to one and draws resource 19 at z=3. Neither branch immediately executes
cdelmusic. TABLE 0x24f initializes this flag to zero. ROOM 0x863 writes the flag
to saves. YODA scene guards consult the same byte. YODA 0x1031 starts BOLIEU only
when music is enabled, direct byte 15 is nonzero, absolute city kind differs
from 3 and city index differs from 45. The selectors at 0x1082/0x10a0/0x10be
are 3 for kind 1, 1 for kind 2 and 0 for kind > 3. Negative city kinds must not
be silently treated as positive in the selector comparisons.

Loss YODA 0x2870 chooses BOLOST when 25915 = 0, otherwise BOPRES. 0x289f guards
playback with music enabled; 0x28ac chooses BOLOST playback at 0x28b9 on ECS.

## Title timing

MAIN 0x555 loads BOPRES for 25915 = 0 and 0x593 starts it before PRESENT2 at
0x599. BOPRES 0xc8 uses resource 0 at volume 127, independently of MAIN's
journey-volume 50. MAIN 0x5cc waits for Space/Return/mouse or the loop counter
to exceed 30000 at 0x5fc; 0x608 calls cdelmusic(50), then 0x611/0x612 waits 60
script stops before killing title playback. MAIN's prior ctiming is 1 at 0x377.
No wall-clock title duration is claimed without scheduler measurement.

No original MAIN-to-journey input replay or physical ECS audio capture was
performed in this bounded audit. The original score captures independently
prove waveform/order completion; they must not be described as campaign branch
reachability evidence by themselves.
