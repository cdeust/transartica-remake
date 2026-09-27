# Original city and map visuals (Amiga ECS), 27 Sep 2026

Private images: `reference-private/art-direction/decoded-20260927/`. Decoders: `tools/claude/visuals/` (`alisimg.py`, `compose.py`, `mapr.py`, `screens.py`, `sheet.py`) (read-only over `reference-private/unpacked/*.alis` and `CARTE.FIC`). The PNGs contain ORIGINAL art. Keep them private.

## Decoding method (high confidence)
- The resource table is at header `+0x0e` (`script.c:549`, `export.c`). Type `00` is a 4-bit chunky sprite with colour 0 transparent. Type `02` is the same but opaque. Type `01` is a solid rectangle in colour `byte[1]`. `fe` is a 16-colour Amiga palette (`0RGB`, `export.c:save_palette`). `ff` is a composite whose entries are `(elem, dx, depth, z)`, and a negative `elem` flips the element horizontally (`image.c:1040`). Sprites are centred (`image.c:1602`).
- The chunky decoding reproduces coherent pictures. That rules out the planar interpretation.
- Screen y = `199 − z`. This is verified two ways: the room (`room.co`) background is 320×149 at z=125 and matches the top 149 lines of `art-direction/original-command-room.png`, and the rows match the line-palette splits below. Draw order by depth is a working assumption (medium confidence).
- The screen is 320×200 with three copper palette bands. ville/mamesc/usine/mine use `clinepalet 0 3` + `clinepalet 39 0`, and yoda uses `clinepalet 149 2`:
  - lines 0–38: banner, palette 3 (`glieu` res 20);
  - lines 39–148: picture, palette 0 (per background);
  - lines 149–199: common instrument strip, palette 2.
- The common strip in my composites is **cropped from the original capture**, not decoded.

## City screen (high confidence unless noted)
Vertical layout: a 39-line banner, then a 109-line picture (320×109), then the common 51-line strip.
- **Banner:** `glieu` composite 19 is placed at z+27. It is a blue-steel art-nouveau frame with ornate corners. A thin rail across the top and a second rail at y≈20 enclose the upper strip (y≈4–19), probably where the city name goes (the textek −95 banner text is not resolved, so this is unknown). Buttons sit on the second row, y≈25–37: brass cartouches 32×13 with brown pictograms, centred.
- **Menus per type** (menu composites drawn, then 21 = EXIT):
  - TOWN (1): comp 24, clock/scroll and open-book pictograms, then EXIT.
  - COMMERCIAL (2), MAMMOTH (5), SLAVE (6): comp 22, "hand→" (buy) and "←hand" (sell), then EXIT.
  - GARRISON (4): comp 25, two soldier pictograms (enlist, spy), then EXIT. Comp 22 is used when no spy is possible.
  - INDUSTRIAL (10–16): comp 47, buy plus EXIT.
  - Gare-atelier: comp 73, EXIT only (the tool buttons are unknown).
- **Transaction bar** (comp 23, replaces the menu): `OK`, `−`, a quantity slot, `+`, `EXIT`. This confirms the 50–53 labels that city-scripts.md had inferred.
- **Backgrounds** (all 320×109, each with its own palette):
  - `ville` res 3 (TOWN: square, crowd, domed buildings);
  - `ville` res 0 (COMMERCIAL: cargo yard, crane, crates);
  - `ville` res 6 (GARRISON: soldiers, flag, barracks);
  - `mamesc` res 0 (MAMMOTH FAIR: mammoths, tents);
  - `mamesc` res 3 (SLAVE MARKET: chained people);
  - `usine` res 0 (INDUSTRIAL: green-grey foundry). Wagon composites 29–50 are drawn on its rails when a wagon type is selected.
  - `mine` res 3 (109-high) and res 0 (320×149): gare-atelier.
  - City 45 (nomads) uses `scene3`, a full-height perspective view of the track.
  - Type 3 in `ville` loads palettes only, and no ville bitmap is used because industrial cities go to usine.
- **Trade list** (glieu `0x157c`, comp 26): a 5×4 grid of 64×27 brass-riveted cells covers the picture area (x = 31+64k, z = 146−27r). Each cell shows a goods icon (sprites 31–46, 48 px wide) placed by `cputnat` with mouse hit `(3−(y−53)/27)·5 + x/64` (glieu `0x409`). Selection overlay: comps 29/30. Whether the city picture stays visible behind the grid is **unknown**, because composite depths conflict.
- **Workshop list** (comp 105): 5×2 cells with 64×16 side-view wagon icons (sprites 48–69).
- Prices and quantities are text drawn at runtime, and their exact positions are **unknown**. The quantity slot sits between − and + (comp 23). The small 9×7 and 17×7 bars (sprites 117/118) sit at cell corners.
- A message box (comp 70: rects 320×59 and 215×57 with frame pieces) sits at z≈82, which is the lower picture area (medium confidence).

## Detailed map (high confidence)
- `cdefmap` (CARTE `0x128`) sets 16×16 tiles with tile code c equal to resource c (codes 1–151, 0 skipped). `csetmap` sets a 320×150 window. Tiles taller than 16 px are vertically centred in their cell (`image.c:4074–4144`).
- The background is the rect res 152, colour 9 (white snow).
- Rails are dark lines with orange rails and blue sleeper edges. Codes 38–58 draw as **light-blue dotted lines**.
- Terrain decoration (mountains, crevasses, lakes, green forest patches, ice) comes from the tile codes themselves.
- Cities (71–76) appear as blue building clusters. Bridges and tunnels have their own tiles.
- The view is a top-down, non-isometric 20×9.3-tile window above the common strip.

## General map (high confidence)
- `carte` res 192: one 320×149 hand-drawn bitmap (palette 196) on beige/cream paper.
- It shows an olive rail network, blue city label boxes, a compass rose at the bottom right and a "700 Km" scale bar at the bottom left.
- Overlay sprites (res 198–247) include red 8-heading arrows (train marker), scroll arrows, train/wagon sprites for 8 headings, explosions, missiles, a red X and a 32×32 EXIT icon (res 237).

## Decoded PNGs
- `decoded-city-{town-type1,commercial-type2,garrison-type4,mammothfair-type5,slavemarket-type6,industrial-workshop-type3}.png`: full 640×400 composites (banner, menu, background and the captured strip).
- `decoded-city-trade-list-layout.png`, `decoded-city-workshop-list-layout.png`: list grids with sample icons and the OK/−/+/EXIT bar.
- `decoded-gare-atelier-mine-{full,109}.png`, `decoded-scene3-nomads.png`.
- `decoded-general-map-screen.png`: the general map plus the strip.
- `decoded-detailed-map-screen-start.png`, `decoded-detailed-map-window-start-x2.png`: the window around (12,62).
- `decoded-detailed-map-full.png`: all 160×73 tiles at 2560×1168.
- `raw/`: single backgrounds, `carte_tiles_1_151_pal0.png` (16 per row, code = 1 + 16·row + col), `carte_198_247_pal196.png`, glieu icons/menus sheets, `glieu_menus_sheet_x2.png`.

## Gap list: remake vs original
1. **City screen is a modal dialog over the travel map.** The original replaces the whole view with a banner, a 320×109 painted scene per type and the common strip. (High)
2. **Menus are text buttons.** The original uses pictogram cartouches in the banner row and OK/−/+/EXIT for transactions. (High)
3. **Goods are a text list.** The original uses a 5×4 icon grid over the picture area. (High)
4. **Six background kinds are missing:** town, commercial, garrison, mammoth, slave, foundry, plus mine and nomads. (High)
5. **Detailed map is a 3/4-view painted terrain with an isometric train.** The original is a top-down 16-px tile map on white snow, with terrain from the tiles, dotted 38–58 lines and blue city clusters. (High)
6. **The remake has no general map, only a "Known area" diagnostic with fog.** The original is a static beige plan with a compass, a scale bar and a red heading arrow. (High)
7. **Fog/"known area"** has no source in the original map render. (High, per map-discovery.md)
8. **Top HUD text bar** (coordinates, speed) is not in the original. (High)
9. **Text positions** (city name, prices, quantities): unknown. They need a runtime capture.

Not done: I did not run the ALIS runner or capture screens from it. The Lemon Amiga manual page returned a bot-block, so its content is not re-verified here.
