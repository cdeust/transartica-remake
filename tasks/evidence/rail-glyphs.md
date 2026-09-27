# Ports de rendu des tuiles ferroviaires de CARTE.FIC

Cette table sert à tracer des **glyphes lisibles sur la carte**, sans déclarer une règle de déplacement. La grille privée `reference-private/CARTE.FIC` a 160 colonnes et 73 lignes, en ordre `data[x×73+y]` (voir `reference-private/map/map.json`, provenance SHA-256 `8e1067619b254d57717348fefedc1b5013eb1d7ba23200a815e36f9b856d811a`). Les directions sont les huit côtés/coins de la cellule affichée : N, NE, E, SE, S, SW, W, NW. Chaque paire de ports ci-dessous est étayée par les voisins ferroviaires des occurrences originales; ce n'est pas une lecture directe des pixels du sprite.

Le moteur original saute le code 0 au rendu (`src/image.c:4130–4144`), ce qui justifie un fond vide. Le code 1 n'apparaît pas dans les 11 680 cellules de cette CARTE.FIC : son glyphe demeure inconnu. Les codes 2 à 5 forment les quatre voies droites dominantes :

| Code | Ports de glyphe | Appui dans CARTE.FIC |
| ---: | --- | --- |
| 0 | aucun, fond | 6 566 cellules; le moteur ne dessine pas de sprite pour 0 |
| 1 | indéterminés | 0 cellule |
| 2 | E–W | 997 cellules; 973 ont un voisin ferroviaire E et 986 W |
| 3 | N–S | 249; 241 N et 237 S |
| 4 | NE–SW | 192; 192 NE et 192 SW |
| 5 | NW–SE | 132; 132 NW et 132 SE |

Les huit courbes disposent de deux ports. Le `cswitch2` de TIME à `0x14c9` traite les codes 6 à 13 par paires avant de changer une direction locale (`0x168c–0x17d4`), corroborant leur rôle de courbes. La forme précise ci-dessous est déduite des voisins de la carte :

| Code | Ports | Appui (voisins ferroviaires de chaque côté / occurrences) |
| ---: | --- | --- |
| 6 | W–SE | 46 W, 47 SE / 47 |
| 7 | E–SW | 50 E, 57 SW / 57 |
| 8 | E–NW | 51 E, 55 NW / 55 |
| 9 | W–NE | 40 W, 42 NE / 42 |
| 10 | S–NW | 34 S, 34 NW / 34 |
| 11 | S–NE | 38 S, 38 NE / 38 |
| 12 | N–SW | 35 N, 41 SW / 41 |
| 13 | N–SE | 39 N, 40 SE / 40 |

Les codes 14 à 17 sont des glyphes à ports multiples ou variantes de droites. Leur géométrie est étayée par tous leurs voisins disponibles; leur aspect visuel distinctif (croisement, surplomb, décor) reste à relever dans les sprites originaux.

| Code | Ports visibles déduits | Appui |
| ---: | --- | --- |
| 14 | N, E, S, W | 21/21 voisins sur chacun des quatre côtés |
| 15 | N–S | 5 N et 6 S / 6 |
| 16 | E–W | 4 E et 4 W / 4 |
| 17 | NE, SE, SW, NW | 11/11 sur chacune des quatre diagonales |

Les codes 18 à 33 regroupent huit **paires de variantes d'aiguillage**. Les deux membres de chaque paire ont les mêmes ports déduits. TIME `0x14c9` regroupe directement 18/19 et 20/21; les autres variantes sont surtout justifiées par les voisinages originaux. Cette table autorise le dessin d'une ligne principale et d'une branche; elle ne spécifie ni la branche active, ni une commande de bascule.

| Codes | Ports de glyphe | Appui le plus discriminant |
| --- | --- | --- |
| 18, 19 | W, E, NE | NE sur 45/45 et 6/6 cellules; E/W sur la plupart |
| 20, 21 | W, E, NW | NW sur 2/2 et 28/28; E/W sur la plupart |
| 22, 23 | W, E, SE | SE sur 18/18 et 6/6; E/W sur la plupart |
| 24, 25 | W, E, SW | SW sur 9/9 et 25/25; E/W sur toutes ou presque |
| 26, 27 | N, S, SE | SE sur 10/10 et 5/5; N/S sur la plupart |
| 28, 29 | N, S, SW | SW sur 5/5 et 9/9; N/S sur la plupart |
| 30, 31 | N, S, NE | NE sur 13/13 et 2/2; N/S sur la plupart |
| 32, 33 | N, S, NW | NW sur 6/6 et 1/1; N/S sur la plupart |

Méthode vérifiable : pour chaque cellule de code `t`, compter parmi ses huit voisins ceux dont le code absolu est entre 1 et 33, sans boucler la carte à ses bords. Les grandes séries 2–5 ont une direction dominante sans ambiguïté; les rares voisins latéraux reflètent les croisements, les aiguillages ou des tracés proches. Un voisin manquant peut être un bord de carte, une case de ville ou un autre code de raccordement : le décompte seul ne prouve donc pas la circulation. Pour restituer les **pixels originaux** et distinguer visuellement les variantes, il reste à décoder la banque de sprites référencée par `CARTE 0x128` (`cdefmap`) et le chemin de rendu `src/image.c:4074–4144`. Aucun glyph inconnu ne doit devenir une voie franchissable par simple dessin.

## Codes 38–58 et croisements 15/16 (27 septembre 2026)

Constat du propriétaire : le train roulait sans rails visibles, par exemple en (41,59) où la ligne y = 59, x 35–47, est en code 39. `ports_for_code` renvoyait une liste vide pour 38–41, 49, 50, 52–54, 56 et 58. TIME les traite pourtant comme voie : règle de vitesse double sur 38–52 et 55–57 (`0x0486`), et toute tuile hors courbes et aiguillages conserve la direction (`0x14c9`).

Le décompte précédent ne comptait que les voisins de codes 1 à 33, ce qui masquait l'axe E–W de 15 (ligne de 39) et l'axe N–S de 16. Recompté avec l'ensemble ferroviaire complet (|code| 1–33 et 38–58, gares et tuiles d'événement exclues) par `tools/claude/glyph_ports.py reference-private/CARTE.FIC <codes>` :

| Code | Occurrences | Voisins ferroviaires | Ports retenus |
| ---: | ---: | --- | --- |
| 15 | 6 | N5 E6 S6 W6 | N, E, S, W (croisement ; TIME double la vitesse en direction 4/6) |
| 16 | 4 | N4 E4 S4 W4 | N, E, S, W (croisement ; vitesse double en direction 2/8) |
| 38 | 19 | N19 S19, diagonales 2 | N–S |
| 39 | 114 | E114 W114, autres ≤ 9 | E–W |
| 40 | 17 | SE17 NW17 | NW–SE |
| 41 | 20 | NE20 SW20 | NE–SW |
| 49 | 2 | NE2 SE2 SW2 NW2 | quatre diagonales, comme 17 |
| 50 | 2 | E2 W2 | E–W |
| 52 | 1 | N1 S1 | N–S, appui unique |
| 53 | 1 | N1 S1 | N–S, appui unique |
| 54 | 2 | E2 W2 | E–W |
| 56 | 3 | E3 W3 | E–W |
| 58 | 3 | E3 W3, SE1 | E–W |

Les courbes 42–48, 51, 55, 57 gardent leurs ports de 6–13 ; le décompte les confirme (48 : N2 SE2 avec NE2 NW2 parasites sur 2 occurrences). Les codes 49, 52, 53 et 54 ont un appui de 1 ou 2 cellules seulement ; leur forme reste une déduction de voisinage, pas une lecture des sprites d'origine.

Vérification native : `game/tests/review_rail_glyphs.gd` place le train en (36,59) vers l'est et capture `tasks/validation/rails-fast-line-row59.png` puis `rails-curves-49-55.png` ; les voies apparaissent entre les courbes signalées par le propriétaire.
