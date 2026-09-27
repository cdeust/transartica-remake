# Boudoir, inventory, save and death presentation — original ECS evidence

Verified 2026-09-27 against private unpacked ALIS scripts, existing disassembly,
and decoded resources. Original bitmaps remain private. The decoders are
`tools/claude/visuals/alisimg.py` and `compose.py`; readable listings use
`tools/claude/alis_pretty.py`. These are decoded compositions, not runtime captures.

## Coordinates and scene

Original canvas: 320×200. Resource positions use screen y = 199 − z; see
`tasks/evidence/original-visuals.md`. `cnumput` arguments are x, depth, z, element,
verified in `reference-private/alis-source/src/opcodes.c` (`cnumput`, line 3864).
Text coordinates below are anchor coordinates, not measured glyph bounds.

`reference-private/art-direction/decoded-20260927/raw/room_000_pal2.png`
is the actual boudoir background (320×149), resource 0 of `room.alis` with
palette 2. Resource 1 places it at (159,z125). Visually: Kolotov sits left
(approximately x70–100,y80–145); red curtains and a bed occupy the middle;
a book lies on the foreground desk at lower right (approximately x188–255,
y126–145); the blue-shaded lamp occupies x268–310,y85–131. These object ranges
are visual estimates, not decoded hitboxes. The command-room capture is the
map-table GENERAL QUARTERS, not this boudoir.

Additional boudoir resources provide exact sprite placements:

| Object | Resource / composite | Screen centre | Bitmap size |
|---|---|---|---|
| Revolver | 15 / 16 | (166,125) | 48×16 |
| Stoup | 7 / 11–13 | (9,120) | 32×20, clipped at left |
| Stoup overlay | 10 / 14 | (14,127) | 16×12 |
| Alarm | 3,4 / 5,6 | (74,37) | 16×12 |

`room` 0x0096 draws composite16, and 0x0151 redraws it on revolver cancellation.
The book, stoup, revolver and Kolotov are scene objects; the manual describes
clicking them, not a permanent textual action footer.

## Inventory: full black field, gold ornament, click pagination

`textek` 0x2be7–0x2c09 draws resource1 and selects palette12. Resource1 contains
an opaque **320×200** rectangle (resource0, colour index1), surrounded by corner
and edge resources3–7. Palette12 index1 is RGB(0,0,0); decorative colours include
(170,102,34), (238,170,102), (204,170,68), (238,238,136). This is a full-screen
black panel with a gold/bronze ornamental border, not a paper-coloured modal.

A decoded reference is in ignored registered scratch `.cache/original-inventory.png`.
Resource expansion and palette were inspected; no runtime text is included.

| Text | x | z | Approximate screen y | Instruction |
|---|---:|---:|---:|---|
| DAY + day | 38 | 186 | 13 | 0x2c0e |
| INVENTORY | 125 | 186 | 13 | 0x2c37 |
| PAGE 1 | 254 | 186 | 13 | 0x2c23 |
| NUMBER OF WAGONS | 38 | 168 | 31 | 0x2c4d |
| Destroyed wagons / no wagons destroyed | 38 | 159 | 40 | 0x2ccb / 0x2cfa |
| PTAV | 38 | 149 | 50 | 0x2d1a |
| PTAC | 38 | 140 | 59 | 0x2d39 |
| TENDER CAPACITY | 38 | 130 | 69 | 0x2da2 |
| PRESENT CONTENTS | 38 | 120 | 79 | 0x2dcd |

Body cursor starts at z109 (0x2dff); line advance subtracts9 (0x3809).
When z<18, 0x381f–0x3885 waits for release then a click, erases text elements
1–50, redraws DAY and PAGE, increments the page and resets the body to z169.
At the end, 0x2eb7–0x2ef0 waits for release/press/release, wakes its parent and
kills the text process. No close button or action menu is drawn here.

## Save input: conditional full-frame or bottom strip

Book handler `room`0x0191 calls the name entry0x055e, which launches textek−38.
The four lines (textek0x0e97–0x0efd) are:

    ENTER THE NAME OF YOUR BACKUP
    THEN PRESS RETURN :

    TO CANCEL TYPE F1

Text renderer `textek`0x273f–0x2774 chooses:

- If `main+0x653a == 0`: composite8, a **320×41** black framed bottom strip
  (y159–199). Four-line z anchors32,24,16,8 (0x271b–0x2736).
- If `main+0x653a != 0`: composite1, the full-screen frame. Four-line z values
  50,30,10,−10 then +80 during drawing, hence130,110,90,70
  (0x26f3–0x2717 and 0x2794).

Lines are centred horizontally at x=160−4×character_count (0x2779).
`option`0x001d sets main+0x653a=1 on entering options; 0x0191 clears it
when leaving options. Therefore the in-game book uses the bottom-strip
variant, while options loading uses the full-frame variant. Both branches
remain significant; they must not be replaced by one generic modal.

Name field `room`0x0575/0x0598: `(` at x121,z16; after incrementing
length, each letter uses x=128+8×length (0x06c7–0x06ed), and suffix
`.SAV )` uses x=135+8×length (0x06f0). Both stay at z16.
The options load-name entry uses the same x formula at **z90** (screen
y109): option0x04ad/0x04d0/0x0610/0x062c, reached from load handler0x0218. Up to8 characters;
lowercase folds uppercase; **first character must A–Z**, later A–Z/0–9
(0x05e4–0x05fd, 0x069a–0x06be). Backspace removes the final character.
Return code13 with nonempty name proceeds (0x0713); code187 sets cancellation
flag and returns (0x0632–0x0644, caller0x03aa–0x03b1). Previous helper comments
calling187 a confirm key were incorrect. Message38 identifies F1 as cancel.

## Revolver and death: two successive screens, then options

`textek`97 (0x25af–0x2616) says:

    IN ORDER TO COMMIT SUICIDE
    PRESS THE LEFT BUTTON
    OR THE RIGHT BUTTON TO CANCEL

`room`0x0131–0x0142 waits for mouse release then a fresh press. Value1 follows
the cancel branch at0x0151, restoring the revolver and returning to the room.
The other branch plays the sound dispatch, draws resource21 (a320×149 black
rectangle, palette colour1), sends yoda message26 with argument100, and ends
its process (0x0160–0x0189). This is an in-game event, not an application exit.

`yoda`0x27d8–0x2865 disables interaction, launches texte2k with the death reason,
waits for the text process completion, then loads `mort.AO`. The complete
suicide epitaph is **ten lines**, including the shared concluding paragraph:

    THE CAPTAINS' BODY WAS DISCOVERED IN
    THE MORNING BY HIS SECRETARY KOLOTOV.
    THE FACE OF THE DEAD MAN REFLECTED
    THE DESPAIR OF HIS LAST MOMENTS
    WHEN HE COULD NOT FULFIL HIS
    RESPONSIBILITIES.
    AND THE SUN CONTINUED TO SHINE
    ITS BENEVOLENT RAYS ACROSS THE TOP
    OF THE OPAQUE CLOUD LAYER,
    HIDDEN FROM HUMAN EYES.

Sources: `texte2k`0x26e6–0x2794, 0x2b12–0x2b51, 0x2c83–0x2d21.
The epitaph uses the same **full black/gold frame** as inventory:
`texte2k`0x268c draws its resource1 (`cputnat 0 -3 0 1 33`), and0x2698
selects palette9. Its composite1 corner/edge/rectangle entries match textek
composite1; palette9 matches textek palette12. Thus a gold frame is attested,
not an invented border. The subsequent Earth screen has its own full bitmap.

Its z anchors are182,165,150,135,120,105,90,75,60,45; lines are centred
(0x268c–0x26c6,0x2ace–0x2ae9,0x2cd9–0x2cf4,0x2d6e).
A mouse release/press/release dismisses it (0x2d45–0x2d64).

`mort` resource0 is a full320×200 image of **blue Earth in space with stars**,
not a body. Resource1 places it, palettes2/3 supply fades (`mort`0x0018–0x0031).
Decoded reference: ignored `.cache/original-mort.png`.
After the image, yoda0x28d6–0x290a accepts Space, Return or mouse, cleans up
and sends main−2. The manual explicitly says suicide returns to the options
page (`reference-private/observations/combat-20260927/manual.txt`, lines456–459).
Tick waits exist in yoda; their duration in seconds is not established here.

## Options and loading belong outside the save book

Decoded `option` resource15/palette16: ignored `.cache/original-options.png`.
It is a full black screen with blue riveted metal plaques joined by trusses:
LEVEL upper left, train-combat icon upper right, START centre, music lower left,
floppy disk lower right. Plaque resource0 centres (x,y): (63,34), (255,34),
(159,84), (63,160), (255,160). These are art bounds, not decoded hitboxes.

The manual's RECEPTION PAGE section (lines252–274) lists new-game difficulty,
play saved game, disable interactive train combat, and toggle music.
`option`0x004a dispatches five codes: level at0x0060, combat toggle0x00c9,
music toggle0x00f3, load path0x011d (calls0x0218), start0x0170.
The existing option.json stopped at unsupported cpalette0x0030; the above
handlers were decoded directly starting0x0034, without assuming the whole
listing was complete. No book-based list of saved games is attested.

## Verification and limits

Read original bitmaps/palettes, expanded the composites using existing tooling,
viewed the resulting inventory and options references, and cross-checked flow
against instruction offsets and local manual. No original assets were placed
in public directories. Layout evidence is not proof of native input behavior.
Unresolved: exact original hitbox polygons, precise text glyph
metrics/colours, and a running original-game capture of each transition.
