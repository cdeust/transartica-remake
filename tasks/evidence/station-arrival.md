# Arrivée en gare, écran de ville et départ : chaîne décodée (26 septembre 2026, Claude)

Offsets = offsets dans `reference-private/unpacked/<script>.alis`. Lecture : `tools/claude/alis_pretty.py`
sur les listings de `tools/alis_disasm.py` (listings de travail dans `.cache/listings/`).
Correspondance trace → fichier : offset = adresse après lecture de l'opcode − adresse de chargement
(`runtime.trace.gz` : « yoda.co ID 03 AT 036940 » ; `1e 72 14 34` trouvé à l'offset 0x1c de yoda.alis).
Ajout au désassembleur : l'opérateur `oscan` (0x72) ne lit aucun opérande (`opernames.c:485`).

## 1. TIME : entrée sur une gare (tuiles 34–37)

`TIME 0x247a` appelle `0x26fb`, puis bloque (`L3e = 1`).

`0x26fb` renvoie `L0x2fb` :
- cinq cases particulières : (23,67)→−2 (et écrit −122 en (22,67)), (35,4)→−3 (écrit 80 en (34,4)),
  (53,32)→−4 (écrit −123 en (52,32)), (148,60)→−5, (51,47)→40 ;
- sinon recherche d'une tuile de ville 71–76 dans le voisinage 3×3 de la case candidate, conversion
  en ancre (décalages 71:(+2,+1) 72:(+1,+1) 73:(0,+1) 74:(+2,0) 75:(+1,0) 76:(0,0)), puis recherche
  de l'enregistrement VILLE.FIC (`main+0x5fe4`, 46 enregistrements) : `L0x2fb` = index de ville ;
- sinon −1.

Messages envoyés (`TIME 0x2483–0x24c3`) : −1 → `csend 34` ; valeur négative → `csend abs+20`
(22–25) ; index de ville → `csend 76 <index>`.

## 2. Récepteur : yoda.co

`yoda 0x1c` : `L0x34 = oscan`, puis `cswitch1 L0x34` (35 cas). Message 76 → `0x1ef` :
`L0x30 = oscan` (index de ville), `L0x1f = −1`, `cstart 0xdae`.

`0xdae` (changement de scène) : `main+0x2faa = L0x1f` (scène courante), puis `cswitch2 main+0x2faa`.
Scène −1 (ville) → `0xe56` :
- index 5–9 : `soleil.AO` une seule fois (`main+0x6519`) ; index 12 : `viking.AO` une seule fois (`main+0x651a`) ;
- charge `glieu.AO` ; index 10–16 : `usine.AO` ; index 45 : `scene3.AO` ; index < 5 : `mamesc.AO` ;
  autres : `ville.AO` ;
- `abolieu.AO`/`bolieu.AO` selon des drapeaux et le type de ville (`main[0x5fe4][i][2]`) ;
- `clive 15` (glieu) avec `shimb[66,12] = index de ville`.

## 3. Départ : glieu → message 9 → demi-tour

`glieu 0x2b5c` : `csend 9`. `yoda` message 9 → `0x811` : `cswitch2 main+0x2faa` ; scène −1 → `0x864` :
détruit les processus de scène, décharge les scripts, puis `cjsr 0x18e3`.

`yoda 0x18e3` (demi-tour du train du joueur) :
- `main+0x2fb4 = 0` (vitesse effective, cf. `locomotive-rules.md`) ;
- `main+0x614c = 0` (non identifié) ; `main+0x2fbc = −main+0x2fbc` (non identifié) ;
- cap `main+0x2fbb` inversé : 1↔9, 2↔8, 3↔7, 4↔6 ;
- phase `main+0x2fba = abs(phase − 2) − 1` ; reliquat `main+0x2fbd = 23`.

Avec la phase 2 conservée au blocage (`TIME 0x063f`), la phase devient −1 et le reliquat 23 :
au pas suivant, `reste > 22` fait passer la phase à 0.

Le message 5 (`yoda 0x190` → `0x18b9`) fait le même demi-tour et remet aussi `main+0x614a`
(frein) à 0 ; son émetteur n'est pas identifié.

## Limites

- Le contenu de `glieu.co`, `ville.co`, `usine.co`, `mamesc.co` (menus, commerce, recrutement) n'est pas décodé :
  le désassemblage atteignable de `ville.alis` s'arrête à 22 instructions.
- Message 34 (gare sans ville) → `yoda 0x225` puis `0x2318` : non lu.
- Aucune observation en jeu de cette chaîne : la trace de ville du 25 septembre a disparu avec `/private/tmp`.
