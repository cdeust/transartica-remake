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
