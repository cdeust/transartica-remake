# Transartica — playable engine room preview

The engine room runs continuously while it is open. Click either stoker to cycle
its fuel feed through off, normal and fast; drag the regulator wheel to set the
target speed; use the brake lever to slow down progressively (5 speed units per cycle, a remake adaptation) until the train stops. L and A cycle the two stokers, Left
and Right adjust the target speed, B toggles the brake, and Space pauses. F5
saves the engine session and chart; F6 restores them; R restarts the engine.
Click the upper gauge board for the separate live instrument screen; its regulator
and exit are clickable. This screen does not pause simulation.
M opens the route chart, J opens the journal, and Esc closes either panel. The
chart supports city selection, dragging to pan, and wheel zoom.

The starting coal stocks, six-wagon mass, fuel consumption, heat, steam
reserve and acceleration follow the decoded original scripts; the progressive
brake is an owner-approved adaptation (the ECS lever stops on the next update). See
[locomotive-rules.md](../tasks/evidence/locomotive-rules.md). The preview runs
one engine update per real second as a **provisional presentation pace**: the
original sources establish one update per three game minutes at the initial
time factor, but not a fixed number of real seconds. See
[engine-cadence.md](../tasks/evidence/engine-cadence.md). Pausing, opening the chart or journal, losing application focus, or reaching an unported event stops automatic
updates without building a catch-up backlog.

The chart draws the original 160 × 73 tile grid and the 46 decoded city
records. Rail strokes for codes 2–33 follow the documented tile geometry in
[rail-glyphs.md](../tasks/evidence/rail-glyphs.md). They show the recorded
network but do not implement route selection, turnout state, train movement,
trade, combat, crew management, or the full campaign. Unknown tile codes are
not silently turned into traversable track.

Run locally with `game/run_local.sh` from the project root. Run the local
checks with `game/test.sh`; they inspect Godot's output as well as its exit
status. The app reads research data from `reference-private/` and writes a
local save to `game/save/view.json` in development. Packaged builds save beside
the app. The shell launcher is for macOS development; platform exports require
their own packaged runtime checks.

The discovery mask is a user-authorized modernization; its current immediate-neighbor
range is provisional. It is saved with the session. Oblique travel/combat, train
composition and city trade remain future phases, tracked in tasks/original-game-coverage.md.

## Premier trajet de test

M ouvre la carte avec commandes de conduite. Alimenter les chauffeurs, régler le
régulateur puis surveiller chauffe et ressources. B freine, Espace suspend,
F5 sauvegarde moteur et trajet, F6 reprend, R recommence. Le parcours va vers
l'est de (12,62) à (33,62) puis se met en pause. Les aiguillages traversés restent
en position droite; leurs branches, marche arrière et villes ne sont pas portées.
La vue de voyage est oblique, avec texture de glace, train détaillé et bandeau
illustré. Le convoi est encore un sprite unique; courbes et wagons indépendants
restent à réaliser. Molette: zoom; glisser: déplacer la caméra; carte du bandeau:
suivre le train.
