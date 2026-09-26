# TIME navigation candidate step: source-backed static trace

All addresses below are offsets in the unpacked `reference-private/unpacked/time.alis`, not runtime VM addresses. The instruction records are in `reference-private/time-listing.json`. Operand meanings follow the pinned ALIS source revision `19a95afdc07b45d997467806d4dd1bf83c5f8076` in `reference-private/alis-source/src/`.

## Predecessor of the coordinate commit

| Script offset | Verified operation |
| --- | --- |
| `0x0588–0x059b` | Continue only when `main+0x2fbd > 22`; then subtract `23` from that main byte and add `1` to `main+0x2fba`. The other branch goes to `0x0675`. |
| `0x05a6–0x05af` | Compare `main+0x2fba` with `3`; only the equal result falls through to this movement block (`cbz24` jumps on zero). |
| `0x05b3`, `0x05b9`, `0x05bf` | Copy `main+0x2fbe` (word) to local `0x24`, `main+0x2fb1` (byte) to local `0x35`, and `main+0x2fbb` (byte) to local heading `0x34`. |
| `0x05c5–0x05ca` | Set local `0x36` to `1` and call `0x1a25`. |
| `0x1a25–0x1a34` | Save candidate coordinates at local `0x26`/`0x39`; `cswitch2` uses local heading `0x34` with base `-1` to select one of nine cases. |
| `0x05d3` | Call `0x1b9d`, a further check after the candidate step. |
| `0x05df–0x05e3` | Conditionally call `0x2392` according to local `0x41`. |
| `0x05e7–0x05ef` | Compare local `0x3e` with zero. If local `0x3e` is nonzero, the comparison yields zero and `cbz24` branches to `0x063f`, skipping the coordinate commits. |
| `0x05f3`, `0x05f9` | Commit local `0x24` to `main+0x2fbe` (word) and local `0x35` to `main+0x2fb1` (byte). The block does not write the main heading field. |

`cadd` adds the immediate to its destination; `csub` negates the immediate before the same add routine (`src/opcodes.c:553-563`, `src/addnames.c:91-103`). The resulting **candidate** changes at `0x1a34` are:

| Local heading `0x34` | Case start | Local `0x24` delta | Local `0x35` delta |
| ---: | ---: | ---: | ---: |
| 1 | `0x1a50` | −1 | +1 |
| 2 | `0x1a5e` | 0 | +1 |
| 3 | `0x1a67` | +1 | +1 |
| 4 | `0x1a75` | −1 | 0 |
| 5 | `0x1aa8` | 0 | 0 |
| 6 | `0x1a7e` | +1 | 0 |
| 7 | `0x1a87` | −1 | −1 |
| 8 | `0x1a95` | 0 | −1 |
| 9 | `0x1a9e` | +1 | −1 |

The switch table and targets come from the original script bytes and the ALIS `cswitch2` handler (`src/opcodes.c:744-765`). Local `0x24` is modified as a word and local `0x35` as a byte, so arithmetic uses the VM's corresponding width. Heading `5` reaches the common check without a candidate coordinate change. The prior evidence file establishes that `main+0x2fbe` and `main+0x2fb1` index `CARTE.FIC` with stride 73; this table therefore identifies raw coordinate attempts, not permitted rail transitions.

## Boundary of this proof

The commit gate depends on checks at `0x1a25`/`0x1b9d`/`0x2392` and local `0x3e`. The listing proves the initial candidate deltas and the guarded stores, but it does not show which tile and direction combinations pass those checks during an actual movement command. The remapping routine at `0x22db` can change local heading `0x34` and restore saved candidate coordinates at `0x233c`; its preceding tile switch at `0x228c` is separately documented in `transarctica-navigation-findings.md`. This static path alone does not prove when that routine affects the candidate step or when a main heading value is committed.

To establish a rail graph, capture one actual movement input with before/after values for local `0x24`, `0x35`, `0x34`, `0x3e`, main coordinates and heading, and the `CARTE.FIC` tile. Then correlate the executed branches in `0x1a25`, `0x1b9d`, `0x2392`, and any call to `0x22db` with this table. No adjacency or turnout rule is asserted here.
