# Départ navigable attesté par TIME et TABLE

Offsets relatifs aux scripts privés décompressés. Décodage :
`reference-private/time-listing.json`, `table-listing.json`, et interpréteur
ALIS révision `19a95afdc07b45d997467806d4dd1bf83c5f8076`.
Les octets de carte sont `CARTE.FIC[x × 73 + y]`.

## Départ et pas de distance

| Fait | Preuve |
| --- | --- |
| TABLE initialise `(x,y,cap)=(12,62,6)` ; phase `main+0x2fba=0`, reliquat `main+0x2fbd=0`, vitesse effective `main+0x2fb4=0`. | `TABLE 0x708`, `0x714–0x732`. |
| Cap 6 propose `(x+1,y)` ; les autres deltas 1..9 sont dans `navigation-next.md`. | `TIME 0x1a34`, cas `0x1a7e`. |
| Sur codes de voie 2 et 18, le facteur de progression prend la vitesse effective `v` sans multiplicateur ; il est plafonné à `450`. | Lecture du code courant `TIME 0x486`, `cswitch1 0x496` (ni 2 ni 18 ne sont des cas), défaut `0x4ea→0x560`, plafond `0x567–0x575`. |
| À chaque pas de cette phase, `main+0x2fbd += trunc(min(v,450)/20)` ; si ce reliquat dépasse `22`, TIME retire `23` et incrémente `main+0x2fba`. Quand la phase devient `3`, il tente un déplacement puis remet la phase à `0` après un commit. | `TIME 0x57c`, `0x588–0x5af`, `0x5f3–0x5ff`. Le test est strict `>22`. |
| Le pas de distance est dans le même sous-programme `0xea–0x67d` que la chauffe et la mise à jour de vitesse, appelé aux phases TIME 0, 3, 6. | Appels `TIME 0x7a`, `0x96`, `0xb2`; `cret 0x67d`. `engine-cadence.md` établit une chauffe tous les trois points de phase TIME en régime ordinaire, sans durée murale certifiée. |

Les gardes de `TIME 0x300–0x481` commandent des sons, animations et états,
mais leurs branches convergent vers la lecture de tuile `0x486` ; aucun
`cret` n'interrompt cette partie avant `0x67d`. Cela n'implique pas une
distance positive : avec `v < 20`, l'ajout entier `trunc(v/20)` vaut zéro.

La phase `3` ne suffit pas à faire bouger le train : TIME recopie d'abord
coordonnées et cap dans les locaux (`0x5b3–0x5bf`), calcule une case candidate
(`0x5ca→0x1a25`), exécute les gardes (`0x5d3→0x1b9d`,
`0x5e3→0x2392` selon le drapeau), et ne valide les coordonnées qu'à
`0x5f3/0x5f9` si local `0x3e` reste nul. Le cap peut être recopié vers MAIN
à `0x66f` dans une autre branche ; le seul commit de coordonnées ne change
pas le cap. Après commit, `0x5ff` remet précisément la phase `+0x2fba` à
`0`. Si le drapeau d'échec est posé, `0x63f` la ramène à `2` et les stores
de coordonnées sont sautés.

## Corridor initial traversable sans changement externe

| Cases sur y=62 | Code CARTE.FIC | Résultat de la routine sur l'état initial |
| --- | --- | --- |
| x=12 | 2 | Départ, cap 6. |
| x=13–14 | 2 | Candidats est ; aucune garde spéciale. |
| x=15 | 18 | Variante d'aiguillage ; la voie droite reste le candidat cap 6 dans cet état. |
| x=16–20 | 2 | Candidats est. |
| x=21 | 18 | Second aiguillage ; même chemin droit tant que son état n'est pas modifié. |
| x=22–33 | 2 | Candidats est. |
| x=34 | 14 | Premier croisement : s'arrêter ici pour ce banc de preuve. |

`TABLE 0x54–0x85` remet le masque auxiliaire `main+0x3080` à zéro, puis
`0x744` place le bit de position seulement à `(12,62)`. La capture d'état
initiale `reference-private/observations/world-ram.bin` (base MAIN indiquée
dans `world-state.json`) donne zéro aux cases `(13..34,62)` ; la grille
`CARTE.FIC` fournit les codes du tableau. `TIME 0x1a25` pose le marqueur
local `0x36=1` : les branches spéciales `0x1aa8–0x1b9c` ne bloquent pas
ce marqueur. `0x1b9d` écarte les régions particulières hors de y62.
Dans `0x2392`, les codes 2 et 18 ne correspondent à aucun cas du
`cswitch1 0x243a`; selon `src/opcodes.c:713–741`, ils poursuivent à
`0x2476`, pas au premier destinataire de la table. Les tests suivants
`0x258a–0x2679` examinent les bits auxiliaires 2, 4, 8, 16, 64 et 128 ;
avec masque zéro, `0x26f5` retourne sans poser le drapeau d'échec local
`0x3e`. TIME peut alors atteindre le commit. Après entrée, le bit de
position est retiré de l'ancienne case et placé sur la nouvelle
(`0x605–0x623`).

Ce corridor est un **banc de navigation droit** dans l'état initial sans
intervention d'autre script, d'ennemi ni d'aiguillage. Il ne démontre pas
quelle branche les deux aiguillages ouvrent au clic, ni le franchissement
des courbes et croisements. Le switch `TIME 0x14c9` traite les codes 18/19
dans une autre routine avec un état local de direction et un appel qui peut
choisir une branche ; cette preuve ne suffit pas à autoriser une branche
dans le trajet du joueur. Ne pas transformer les ports graphiques de
`rail-glyphs.md` en graphe circulable sans vérifier ces gardes.
