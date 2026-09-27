# Captain's wagon, crew and control panel: reverse-engineering notes (2026-09-27)

Offsets refer to `reference-private/unpacked/<script>.alis`. Listings are regenerated with `tools/alis_disasm.py --all-entries` and `tools/claude/alis_pretty.py`. Script IDs come from the header word: 0 main, 2 souris, 3 yoda, 4 train, 5 carte, 8 texte(k), 14 berta, 16 texte2(k), 19 room, 32 son, 45 sbras. `main+0x1c` is the hotspot code under the mouse ("matsou" at souris 0x440; the value comes from `ctstform` at souris 0x3bc via the form set chosen by `cforme`). The manual (Lemon Amiga, fetched in a browser) has no "captain's quarters", "command room" or "journal". Its wagons are **A engine, B private wagon "BOUDOIR", C GENERAL QUARTERS, D missile launcher**.

## 1. Control panel (yoda main loop 0x401–0x66b) — proven, labels from the manual
- **Train bar** (mouse y 41–48 from the bottom, 0x408): at x<14 or x>304 it scrolls `main+0x21` (0x1ac7). Otherwise, holding a wagon shows the textek −1 card (WAGON/TARE/STATE/TRANSPORT, 0x1b7c). The bar is drawn by 0x1979 from x=300 towards the left, with wagon 0 on the right. Sprite 92+type−1. Width 27 for types 5,10,17,21,23,25 and 33 for the others (0x1a90). State 1 adds cross image 121, state 2 adds two crosses, state 3 shows axle image 122.
- **Codes when a map is showing** (`main+0x2faa` 1..9, 0x43c): 1 = map icon (detailed→overall; overall→back to the wagon); 2 = clock (`main+0x2fce` toggles, time step `0x2fb8` 1↔3); 3 = direction reverser (0x18b9); 4 = detailed map; 5 = brake (`main+0x614a`); 6/7/8 = wagon icons (`main+0x20 = code−5`); 9 = D. D works only if `main+0x62c1` (missile launcher bought, glieu 0x27c3) and missiles (goods 2) are >0. Otherwise textek 15. The launcher is scene −2, which loads berta and sbras (yoda 0x10e1).
- **Codes in a wagon or city** (0x522): 1 = detailed map (from a city/scene: leave); 2 = clock; 3–5 do nothing (the manual confirms only the map icon is active); 6–8 = change wagon; 9 = D.
- **Which script each wagon uses:** `main+0x20 == 3` → `room.AO` (0x2eae); otherwise `train.AO` (0x2ece). train draws the engine when `main+0x20==1` (train 0x161) and the GQ otherwise (0x1bd). **Code 6 → engine and 8 → boudoir are proven. Code 7 → GQ is inferred.** Which icon (A/B/C) carries which code is set by form data that is not decoded.
- **Panel art (yoda):** base image 5 (0x3c7). Action-icon sets 57 (wagon), 58 (scene 0), 56/90 (maps), with form sets 2 or 6 (0x732). Image 91 greys out D. Brake indicator 120 and reverse indicator 124 (0x305a). Clock hands 20+h and 32+m/5 (0x2fc3, 0x300e).

## 2. Boudoir = room.alis (ID 19) — proven
Entry at 0x38: child processes for the stoup lamp (−7) and the alarm (−6). Then `cput 1` (background), `cput 19` if `main+0x64f5` (meaning unknown), `cputnat 16` on layer 3, form set 5. The hotspot switch is at 0xc0:
| code | object (manual) | effect |
|---|---|---|
| 10 | STOUP | if messages waiting (`main+0x614f`), pop one from `main[0x6152]` and show textek 98 (0x267) |
| 11 | Kolotov, secretary | fade out, then texte msg **100 = INVENTORY** (0xe4). Sets `main+0x651b=1` and `main+0x2fcc=0`; that this pauses time is inferred |
| 12 | revolver | textek 97 "…LEFT BUTTON… RIGHT TO CANCEL". Confirming shows image 21 on layer 77 and sends yoda msg 26 with 100 (0x121). That runs the mort.AO game-over (yoda 0x27d8) with texte2k 100 "THE CAPTAINS' BODY WAS DISCOVERED… KOLOTOV" |
| 13 | book | **save** (0x191): name of up to 8 chars A–Z/0–9 (0x55e, textek 38), backup-disk prompts (37/39/32), file `<NAME>.SAV` |

Save contents (0x787–0x8e7): 63 scalars plus the wagons, spies, mines, stoup, stocks, enemy trains, flags and map blocks. Loading happens in option 0x6c3.

**Inventory** (textek 0x2be7–0x3171) — proven. The page shows DAY `main+0x2fb2`, "PAGE n", NUMBER OF WAGONS, destroyed wagons, PTAV (tare, 10 per destroyed wagon), PTAC, TENDER CAPACITY (5000 per intact tender) and PRESENT CONTENTS (lignite+anthracite). Then one "NAME: count" line per intact type, in this order: 1,2,3,21,8–13,4,16,20,22–24,5–7,14,15,17–19. Each line is followed by "CONTAINING n unit" (0x33d4): 5/6 SLAVE(S), 7 MAMMOTH(S), 15 OIL, 19 PLANTS, 22 SPY (SPIES), 23/24 SOLDIER(S); goods are grouped by commodity. A new page starts with a click (0x3809). There are no actions.

**Stoup and radio.** The queue holds 10 entries; 0x1d1a pushes one, rings the bell (son 3) and lights the lamp. Ids 101+k are reports from spy k (0x27f4); 125–127 are story; <51 are not read. **No diary, journal or log screen is attested anywhere.** The "book" is the save.

## 3. General Quarters (train.alis, `main+0x20==2`, 0xe19) — proven
Background `cput 4`, plus 175 if `main+0x6514`, form set 19. Codes: 10 stoup; 11 radio operator → spy menu; 12 mock-up map → yoda msg 1 (overall map); 13 right-hand character → line-inspection-car menu.
- Spy menu (0xfb5, images 160/162/163, form set 34): send a spy (needs a slot with state 1 → yoda msg 12); dynamite (needs state 2 or 3 → msg 13); exit. With no spies it shows textek 9.
- Car menu (0x1042, images 157/161, form set 30): plain car (msg 10), car with missile (msg 11, needs goods 2), exit. Without cars (goods 3) it shows textek 8.
- 0x10fb: when `main+0x6514` is set, image 171–174 depends on the distance to (65,20). Meaning unknown.

## 4. Crew — mixed
| category | lives in (type: capacity, glieu) | source |
|---|---|---|
| slaves | 5 PRISON:60, 6 ALCATRAZ:100 | proven |
| soldiers | 23 BARRACKS:50, 24 XL BARRACKS:80 | proven |
| mammoths | 7 LIVESTOCK:3 | proven |
| spies | 22 SPY:5, plus 20 records `main[0x5d84]` (states 0 free, 1 aboard, 2 travelling, 3 posted) | proven (carte 0x1dc9 sets 1→2 and removes 1 from the type-22 load; TIME 0x0b43 sets 3) |

- Crew counts are wagon load `[3]`. The start is a six-wagon train with 10 soldiers in the BARRACKS (TABLE 0x699–0x6f4), proven.
- **There is no crew screen** where you assign, move or feed crew. Crew are seen only in the inventory, the wagon card, combat potential (textek 44) and HUMAN LOSSES (textek 81, 0x1c9f). Note: `personnel-story.md` calls 0x1dc3 a roster; it is actually part of the losses message.
- Uses: slaves as works labour (obstacles.md, yoda 0x2390); slaves and soldiers as beaters in the mammoth hunt (textek 0x1e50, partial); soldiers and mammoths in combat (manual).
- **Upkeep, food and morale: unattested.** No script lowers crew counts over time. The only writers are trade, losses, hunt and combat (textek 0x4d22+). Wages: soldiers cost only at enrolment (glieu).
- Train overview or reorder screen: no separate screen. Reordering is the workshop "move" action (glieu 0x21ea, code 50, msg 90). The algorithm is not decoded (partial).

## 5. Current remake
`travel_hud.gd` has hotspots pause/room/instruments/follow/journal/brake/regulator/fuel. "room" only toggles off instruments (`main.gd:_open_panel`). "journal" is a fixed intro text, labelled "CAPTAIN'S JOURNAL", with no original counterpart. `engine_panel.gd` is not referenced anywhere. `train_wagons.gd` holds the `0x2e1a` table and mass. **Missing:** wagon icons A–D, clickable and scrollable train bar with wagon cards, clock acceleration, reverser, boudoir (stoup, Kolotov inventory, save book, revolver), GQ (stoup, spy menu, car menu, map mock-up), stoup queue.

## Confidence
Proven: §1 codes and effects, room/GQ codes, save format, inventory, capacities, spy states. Manual: object names (Kolotov, revolver, book, radio operator). Inferred: code 7 = GQ, `651b` pause. Unknown: icon↔code placement, `main+0x64f5`/`0x6514`, stoup ids <51, reorder algorithm.
