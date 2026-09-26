# Circulation sur le réseau : règles TIME décodées (26 septembre 2026)

Offsets dans `reference-private/unpacked/time.alis` (listing `time-listing.json`),
`table.alis` et `carte.alis`. Vue lisible produite par
`tools/claude/alis_pretty.py` (hypothèses de lecture en tête du fichier :
`acc = acc OP arg`, `opile` dépile, index de tableau = pile puis acc).

## Pas de déplacement (TIME 0x0486–0x067d)

| Étape | Règle | Preuve |
|---|---|---|
| Vitesse de progression | `v = vitesse` ; `2×vitesse` si tuile courante 15 et direction 4/6, tuile 16 et direction 2/8, ou tuile 38–52, 55–57 ; plafond 450 | `0x0486–0x0575` (`cswitch1` `0x0496`, tests `0x04ee`, `0x051f`) |
| Reliquat | `reste += v/20` ; si `reste > 22` : `reste -= 23`, `phase += 1` | `0x057c–0x059b` |
| Phase 1 et 2 | appel `0x1444` avec `L33 = phase` ; la direction n'est modifiée que si `phase == 1` | `0x0649–0x066f`, `0x14bd` |
| Phase 3 | case candidate = position + delta(direction) ; contrôles `0x1b9d`, `0x2392` ; si `L3e == 0` : commit, `phase = 0` ; sinon `phase = 2` (nouvel essai au pas suivant) | `0x05a6–0x063f` |

Deltas (`0x1a34`) : 1(−1,+1) 2(0,+1) 3(+1,+1) 4(−1,0) 6(+1,0) 7(−1,−1) 8(0,−1) 9(+1,−1),
soit la disposition du pavé numérique, `y` croissant vers le sud.

## Changement de direction (TIME 0x1444–0x1918)

`cswitch2 abs(tuile)` base 6, 52 entrées. Courbes (direction entrante → sortante) :

| Tuiles | Règle |
|---|---|
| 6, 42, 51 | 6→3, 7→4 |
| 7, 43, 57 | 9→6, 4→1 |
| 8, 45 | 3→6, 4→7 |
| 9, 44 | 6→9, 1→4 |
| 10, 47 | 8→7, 3→2 |
| 11, 46 | 8→9, 1→2 |
| 12, 55 | 2→1, 9→8 |
| 13, 48 | 2→3, 7→8 |

Aiguillages, paire (pair = voie directe, impair = déviée) pour le train du joueur
(`L37 = 0`, condition `abs(tuile) == impair` en `0x169c`…`0x18da`) :

| Paire | Entrée en pointe | Déviée | Talon |
|---|---|---|---|
| 18/19 | 6 | 9 | 1→4 |
| 20/21 | 4 | 7 | 3→6 |
| 22/23 | 6 | 3 | 7→4 |
| 24/25 | 4 | 1 | 9→6 |
| 26/27 | 2 | 3 | 7→8 |
| 28/29 | 2 | 1 | 9→8 |
| 30/31 | 8 | 9 | 1→2 |
| 32/33 | 8 | 7 | 3→2 |

Toute autre tuile conserve la direction. Clic d'aiguillage (CARTE `0x123f–0x1270`) :
une tuile 18–33 paire devient +1, impaire −1, écrite dans la carte.

## État initial (TABLE 0x12ea–0x137c)

Écritures inconditionnelles au démarrage : (54,5)=−121, (144,4)=−121, (6,9)=64,
(70,19)=−117, (25,24)=63, (134,40)=63, (94,37)=64, (71,54)=−121, (139,57)=64,
(83,67)=63, (116,55)=70, (114,55)=81.

## Contrôles de la case candidate (TIME 0x2392–0x257e, 0x1b9d–0x2044)

- `−105 < tuile < 0` : blocage (`L3e = 1`), message 81. Tuile ferroviaire détruite (CARTE `0x2852` rend une tuile négative).
- Tuiles −120, −116, 34–37, 65, 67, 69, 78, 79, 114 : sous-routines d'événement (gares 34–37 : `0x26fb` puis blocage).
- Zones d'histoire : x 39–58 × y 20–33, x 139–157 × y 47–68, ligne y = 67, case (11,10) ; modifications ponctuelles de tuiles et drapeau `main+0x614b`.

## Portage retenu et frontière

Portés : vitesse de progression, phases, courbes, aiguillages, clic d'aiguillage, état initial,
blocage des tuiles détruites. **Frontière** (le train s'arrête avant la case, message explicite) :
tuiles d'événement, tuiles ≤ −105, déclencheurs d'histoire listés ci‑dessus, sortie des colonnes 0–159.
Aucun contenu de ville, d'événement ou d'histoire n'est inventé.

## Vérification

`tools/claude/explore_network.py` : depuis (12,62) direction 6, en prenant les deux branches
de chaque aiguillage : 2 240 états, 1 566 cases, **0 sortie vers une tuile 0**. Fins : gares 34–37
(48), 65 (4), −120 (1). 31 des 48 gares sont à ≤ 4 cases d'une ancre de ville décodée.
Limite : validation de cohérence statique ; aucune trace d'exécution d'un trajet n'a encore été enregistrée.
