# Launcher completion, 1 October 2026

The optional equipment launcher is distinct from the inspection-car missile command.
YODA 0x672..0x6d6 requires purchased wagon13 and positive goods2 cargo. Missing
launcher silently refuses entry; purchased launcher without ammunition invokes
TEXTEK15. The common panel's original code9 opens the production launcher.

BERTA source form8 defines bearing buttons245/15 and245/31, four digit cells
261/269/277/285 at17, ARM261/40 and FIRE285/40. BERTA0xf0/0xfd subtracts/adds
a 32-step bearing index;0x10a..0x162 cycles decimal distance digits. Minimum0050,
angle113/10 and wrap correction come from0x249..0x4c3. ARM/disarm flash plus four
linkage poses and launch flash plus frames54..68 are represented by explicit
continuation phases. ECS callbacks use source sloc[-2]=3 on the PAL50Hz scheduler.

CARTE0x15b0..0x1a69 supplies the asymmetric integer coefficient tables, strict
square homing bounds and first matching slot0..29 with state !=2. Integer divisions
retain source order. CARTE0x1a86..0x1b83 tests previous drawn positions and scrolls
18 columns or8 rows. CARTE0x1b91 removes the matched enemy once;0x1c97 debits the
first positive goods2 wagon only after TEXTEK60+status is dismissed. Source status0
still reaches the enemy-removal block. No extra cargo change occurs on loading.

One explicit boundary: a homing enemy exactly at the player can make both integer
steps zero. Pinned ALIS opernames.c `odiv` has no zero-divisor guard. The remake
rejects that undefined trajectory before mutation instead of inventing a hit.

BERTA click0x568, ignition0x574 and ARM/disarm0x596 are the actual csound offsets.
The old arm call used helper entry0x580 and played nothing; corrected against the
reachable instruction. Native mixer priority100 now verifies the ARM sound. Impact
uses CARTE0x1c43 SON selector5. Root owns broader combat cue integration.

The SBRAS fallback is not required by ECS MAIN25915=0. Original private sbras.co
is an uncompressed container: header0100286a0001, six-byte header followed by
script identity002d. Its original SHA256 is
c18f66f960090a7242740c27c8deb35ddf2fdeb4efeeff03e40baad7c1853367.
The unchanged payload SHA256 is
df1a39edec4811989e0d10d70ea1747a63c7f47dde64e2c5408f83953a2243e0.
The source payload's header entries are[24], resource table36; reachable decode
has no errors. Entry0x18 executes csound(0,100,127,1,15), then exits. Existing
reference-private/unpacked/sbras.alis lacks identity and has further header/data
differences; it was preserved. Corrected audit copy/listings remain ignored in
.cache/launcher-sbras-corrected.*. No historical artifact was silently overwritten.

Authored launcher background and rocket replace historical pixels. Measured rocket
solid body rectangle398,29,228,1402 excludes most surrounding glow; runtime keeps
its aspect while fitting source96-pixel height. The scene clips at logical149
rows so map trees/cities cannot paint over the original common panel. Flight uses
source camera/trajectory and authored terrain, revealing only its selected
homing target (CARTE0x1d24..3f). Impact uses authored explosion art
for the source two/four poses, then removes the rocket before the report. Controls retain the source rectangles inside the shared authored ornamental
frame. ARM/disarm interpolate the four source linkage poses using an authored
gantry-beam region; ignition uses authored flame artwork. Native captures make
these artistic adaptations reviewable.

Verification: production viewport mouse tests cover actual source bearing/digit,
ARM/FIRE, native sample mixer, OPTIONS suspend/resume and Enter dismissal. Real
SessionSaves round trips cover arming, armed, launch, ascent, flight, impact and
report; malformed/missing schema9 fields reject atomically and legacy8 restores
an inactive launcher. Named book-loader continuation is visible after restore.
This is a source-valid equipment regression fixture, not evidence of earning the
launcher in a campaign. Native65 assertions passed in launcher-controls-native-20261001.log;
source and craftsmanship file gates each reported zero errors/warnings.
Model174 assertions separately cover source geometry,
all continuation snapshots and identical30/60/144 display-rate outcomes.
Logs/captures: tasks/validation/launcher-*-20261001.log and launcher-*-native.png.
