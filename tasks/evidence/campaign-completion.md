# ECS campaign port — 30 September 2026

Target: English Amiga ECS unpacked scripts; offsets refer to the unpacked files.
The campaign fixture follows actual dispatch and persisted states. It is distinct
from driving the whole train across the original network in a normal new game.

## Primary evidence

- MAIN `0x7b3..7ea` reads HIMA.FIC (240 bytes), TRANS.FIC (276), OASIS.FIC (27).
  TIME `0x1b9d..2044` consumes these three-byte records to reveal hidden `-115`
  tiles. TRANS uses signed x+256, the other tables use x directly.
- TIME `0x1c31..82`: a DRILL (type8) must be first or last; `(32,67)` tile35
  becomes2. Other equipment conditions are not added.
- TIME `0x1c82..1d15`: oasis cells `(28,67)`88→54, `(29,67)`89→−114,
  `(30,67)`90→−113. TIME `0x1fc8`: `(39,32)`34→2.
- TIME `0x26fb..2796`: special station23,67 dispatch22 (Urga), 35,4 dispatch23
  (Oslo), 53,32 dispatch24 (mausoleum), 148,60 dispatch25 (power station).
  The first three also write their landmark at the cell immediately west.
- SCENE3 `0xea..167`: first Urga visit sets `main64f5`, presents TEXTEK86/87;
  repeat presents88. The mausoleum presents TEXTEK51 (YODA `0x12d7`).
- SCENE4 `0x22..46` writes ASCII53,56,57,52,55: **58947**. This agrees with
  TEXTEK51; it is not a number imported from an unverified walkthrough.
  Keyboard code0x17e accepts digits/backspace, maximum5; Return checks each
  position. First success sets `main6514`, `main6516`, wolf position126,15,
  heading4 and emits126 once (`main6536`). TEXTEK91 identifies the Geiger counter.
- TIME `0x1f1a..1fa2`: heading1, `(152,48)`, more than5 wagons and no type25
  causes skid message18. It does not test boiler damage or a weight threshold.
- CARTE `0x1dc9..1e93` sends first aboard spy, decrements first loaded type22.
  TIME `0x976..0c85` moves spies each third invocation straight towards target.
  Arrival state3, heading5. Arrival within signed recordx24..26 and y19..21
  reveals central−124 at destination and west neighbor, emits127.
- CARTE `0x27a4..2921` refuses travelling spies and field13>99; confirmed action33
  adds100 to field13. Central−124 sets `main6515` and emits125. No Urga/Geiger
  prerequisite is present in this sabotage branch. Normal track/bridge demolition
  writes exactly the dispatch codes; same spy cannot trigger it twice.
- TIME `0x1e6c..1eaf` opens `(157,68)`36→3 only if `main6515=1`.
- TIME `0x1bf7`, YODA `0x13d7..14ca`: `(11,10)` while flag6517 is set asks28.
  An intact harpoon(type9,state<3) presents53, clears6517 and reverses. Continuing
  without it causes death104; declining retains the whale.
- TIME `0xc91..1126`: inspection car dispatch uses100 iterations, phase3 rail
  steps, consumes one goods3 and for missile one goods2; stop before station,
  mine, destroyed rail, bridge, player or enemy. Missile weakens enemy by one
  third of strength%100, with slot29 excluded.
- YODA `0x2765..27d7`: power station displays TEXTEK19 and runs IFEBO then BOPRES.
  IFEBO `0x18..372` contains lighting flashes, opening cloud layers after tick35,
  palette restoration at tick200 and completion after tick240.
- YODA26 `0x27d8..2865` preserves death reason100..105, presents TEXTE2K epitaph,
  then MORT. CampaignState retains every cause instead of always showing suicide.

## Decoder repair

The previous listings stopped on `csound`, hiding Urga's key writer. The decoder
now reads csound/cmsound's five expressions (opcodes.c3340), cpalette's one
(opcodes.c2345), cinstru's three (opcodes.c4071) and ccancall's zero
(opcodes.c4430). `tests/test_alis_disasm.py` independently checks byte boundaries,
Urga86/87 and the finale's tick200 transition. Regenerated listings live only in
ignored `.cache/campaign`; private bytecode/dialogue/maps remain uncommitted.

## Delivery and verification

- `tools/build_campaign_data.py --source reference-private --output
  game/private-data/campaign.json` derives private runtime text and region data.
- New modules: CampaignState for story flags/gates; CampaignSpies for dispatch,
  travel and sabotage; CampaignSnapshot for atomic validation; CampaignSession
  for scene transitions/input/save presentation; CampaignScreen for authored art;
  InspectionCar for source car dispatch. Boudoir/GQ callbacks use these modules.
- State gate before implementation: Godot parse error because campaign_state.gd
  was absent (`.cache/campaign/before.log`). After implementation: clean native
  PASS under the escalated Godot launcher (`.cache/campaign/state-tests.log`).
- Eleven disassembler tests pass. The real app suite
  `test_campaign_session.gd` requires root composition wiring and checks keyboard
  input, an interrupted Oslo save, visible finale transition and death reason.

## Scope still requiring integrated proof

Full traversal from normal starting resources, all commerce/works/combat outcomes,
spy report observations and retrieval, random car ambushes and mine traps, wolf
movement after Oslo, and source-matched finale animation/audio remain required.
The shipped state fixture proves its tested gates; it does not certify campaign
completion or all original game rules. SOLEIL/VIKING are manual-based antipiracy
checks (TEXTEK54), distinct from SCENE4's story delivery code. Their preservation
or intentional removal must be decided explicitly, not turned into story gates.

## Root wiring

Create `campaign` before BoudoirSession callbacks can be invoked, attach it after
BoudoirSession. Before journey advance evaluate campaign before-entry; after
station lookup let campaign handle indices−2..−5. Route key input to campaign
before other dialogs and include its simulation block. Each original TIME spy
call (phases2/5/8) runs `advance_spies`. Reset on new journey. Save/restore the
session snapshot; validate it before any app state mutation. After loading network
and trade, apply campaign.restore so presentation/code/pages resume. Connect
CityScreen.town_message_requested to campaign.show_town. Add both campaign tests
to the central runner; build_preview must include generated campaign.json.
