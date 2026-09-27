# Obstacle unknowns — static decode (27 Sept 2026)

Unpacked-file offsets; listings regenerated with `tools/claude/xdisasm.py`, reference scan with `tools/claude/find_ref.py`.

## 1. Answering NO: **proven**
- Every handler first runs the prelude `YODA 0x2318`: brake `0x614a=1`, normal clock (`0x2fce=0`, `0x2fb8=1`), then draws the brake (TRAIN message −5, or `0x3037`).
- NO at `0x2390` (`0x258c`): clears `0x651b`, then `cret`. There is no scene change, no reverse (`0x18e3`) and no map write. Too few rails or slaves (`0x2470`/`0x24ae`) shows text 92–94 and exits the same way.
- TIME kept phase 2 (`0x063f`), so **the train waits in front of the cell, heading unchanged**.
- While braked, `TIME 0x02e4` forces speed `0x2fb4=0`. Progress `0x614c` stays 0 and the phase stays 2, so the **message is not re-sent each cycle**.
- After release, speed ramps up (`0x02d1`) and phase 3 re-checks the cell. The same message is re-sent, so tile questions 22/24/25/26 are asked again.
- Exceptions:
  - The herd (23) moves before the question (`0x24d4`).
  - The nomads (27) move at `0x2984`, before the answer is tested.
  - Spy (21): NO applies `rec[13]%=100` (`0x2713`). Bit 64 never blocks TIME; only the brake stops the train.
- Unverified: a possible duplicate check in the send→brake tick.
- All `0x614a` writers (listing plus raw-byte scan):
  - TABLE `0x01cb` (=1); OPTION `0x0742` (load)
  - YODA `0x2318` (=1, every scene change and event)
  - YODA `0x04d9`/`0x04e3` (toggle, click code 5; in the trace)
  - YODA `0x18d8` (=0 on reverse, message 5)
  - TRAIN `0x037f`/`0x0389` (toggle, click 16); `0x045d`/`0x0466` (temporary)
- `0x18e3` does not release the brake, so the train stays braked after YES (`0x975`) and after leaving a city (`0x864`).

## 2. Buttons: **proven**
- Every question draws TEXTEK resource 11 (`cputnat 0 0 0 11 34`). It is a composite: element 9 at dx 135 and element 10 at dx 185, both 32×13.
- Both bitmaps are type 0: chunky 4-bit, data at +6, high nibble first (`image.c:1943`, `draw_st_4bit_0`). Decoded, they read **NO** (element 9) and **OK** (element 10).
- `0x2d6b` click zones:
  - OK: x 170–201, y 6–18 → L0x20=0 → proceed.
  - NO: x 120–151 → L0x20=1 → decline.

## 3. Countdown L0x16b (TEXTEK): **mechanics proven; time cost unknown**
- `0x41d6` spends the rails, then computes W = slaves + 30×mammoths (+150 with a crane).
  - Texts 74/75: L0x16b = max(0, 420−W)/3 + 144.
  - Text 76: L0x16b = max(0, 175−W)/3 + 12.
- `0x45e6–0x462d` lowers it by 1 per TEXTEK tick while waiting for a click. **Only the click exits.**
- At expiry it only sets normal clock speed, which is already active. The 74–76 path never sets fast clock; text 79 does (`0x1a7c`).
- Shown: text plus scene2.AO. **The map is written after the text is dismissed**: YODA `0x25c2` waits for `0x62c0=0`, then writes at `0x25ce`.

## 4. TIME `0x2687`: **proven**
- `mainw[0x6070]` is 1-D (`cdim 24688 0 2`; alis.c:1394). With T=[x%10]:
  `T==−1 | (((day−1 > T/50) | (day > T/50 & hour ≥ T%50)) & rnd(6)==0)`
- So it fires on the first visit, then after 24 h or more with a 1 in 6 chance. It stores T=day×50+hour and sends message 127.
- Cells are set at TABLE `0x0463–0x04b7`: (50,44) (74,38) (92,57) (83,27) (44,59) (5,28) (66,40). 44 and 74 share slot 4, and there is no overflow.
- Message 127: scene −11, text 78 "MOLE MEN AMBUSH", then 79.

## 5. `main+0x2fad` = clock hour: **proven**
- The YODA post-tick handler (header+6 = `0x3359`) advances minutes `0x2fb0` += `0x2fb8`, then hour `0x2fad`, then day `0x2fb2`. Also gated by unidentified `L0x24b==0`.
- Cell (110,33) becomes −121 (passable) at hour 12 and −120 (blocked, text 52, reverse) at hour 14. So it is open 12:00–13:59 daily.

## 6. Mine table `main[0x6082]`: **proven**
- TABLE `0x00e7` zeroes it.
- YODA `0x1e2a` runs when the day changes and day%3==0 (`0x3446`):
  - Each active mine loses 5 from rec[3]. Below 1, its tile becomes 79.
  - If day ≤127, a new mine goes in the first free slot (0–35). A straight track next to an off-track diagonal becomes a switch, and 78 goes on the diagonal. The record is (x−40, y, ±day, rnd(10)+40).
- rec[2]<0 means ANTHRACITE, otherwise LIGNITE. rec[3] is the "WEALTH INDEX" (TEXTEK `0x1675`).
- YES sets tile 79 and rec[3]=−1 (`0x25e2`).
- **TABLE `0x0679`** is reached only through `cswitch2 L0x0c` at `0x060c`, case 3 ("super scenar").
  - Byte 12 is written only by a hidden OPTION cheat (`0x0828–0x08fa`): modifier mask 12, button 2 and a corner click. Top-right gives 3.
  - The live MAIN launch at `0x02ef` writes nothing.
  - In the trace, `0x060c` took the default path (`0x0699`), and `0x1294–0x138a` never ran.
- **So the 12 bridge writes at `0x12ea–0x137c` do not happen in a normal new game.** Those cells keep their CARTE.FIC values, e.g. (54,5)=−116, (25,24)=67, (70,19)=114.
- Contradicts rail-network.md and the ported initial state; re-run `explore_network.py` without them.
