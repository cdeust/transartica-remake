# Chaudière et conduite : règles prouvées dans les scripts ALIS

Cette note utilise les scripts décompressés privés `table.alis`, `time.alis`, `train.alis`, leurs tables de décodage, et les opérateurs de la source ALIS révision `19a95afdc07b45d997467806d4dd1bf83c5f8076`. Tous les offsets `0x...` ci-dessous sont relatifs au script décompressé. Les mots sont de 16 bits, les octets de 8 bits; les divisions entières de l'interpréteur tronquent vers zéro (`src/opernames.c`, `odiv`).

## État initial vérifié

| Champ main | Sens établi | Initialisation |
| --- | --- | ---: |
| `0x2fb4` | vitesse effective | 0 (`TABLE 0x708`) |
| `0x2fb6` | stock de lignite, également monnaie | 2000 (`TABLE 0x6fa`) |
| `0x2fc0` | réserve motrice calculée | 0 (`TABLE 0x195`) |
| `0x2fc2` | état de chaudière borné à 600 | 0 (`TABLE 0x19b`) |
| `0x2fc4` | vitesse cible du régulateur | 0 (`TABLE 0x1a1`) |
| `0x2fc6` | chaleur accumulée | 0 (`TABLE 0x1a7`) |
| `0x2fc8` | stock d'anthracite | 500 (`TABLE 0x701`) |
| `0x2fca`, `0x2fcb` | taux de chargement lignite, anthracite | 0, 0 (`TABLE 0x1ad`, `0x1b3`) |
| `0x614a` | frein basculant | TABLE ne l'initialise pas dans ce bloc; `TRAIN` le bascule |

L'identité des deux stocks est corroborée indépendamment par les affichages de `TEXTEK 0x3100–0x3138`: `main+0x2fb6` est montré comme lignite et `main+0x2fc8` comme anthracite. Les montants de départ viennent des stores exécutables de TABLE, pas de ces textes.

Le train initial comporte six entrées (`TABLE 0x699–0x6f4`) de types `[1, 21, 2, 3, 17, 23]`; seul le champ de charge du dernier vaut `10`, les cinq autres valent `0`. `TIME 0x2a77` associe à ces types les poids de base `[1000, 50, 50, 40, 45, 80]`. Son second switch (`0x2b4a`) ajoute `floor(champ3/10)` au type 23, donc `1` au dernier wagon; les autres ajouts sont nuls. **Masse initiale calculée : 1266**. Le calcul de résistance à `TIME 0x233–0x24f` produit alors `W'=1266+floor(1266/100)^2=1410`, `H=floor(W'/2)=705`, puis `D=floor(32000/H)=45`. Ces valeurs donnent un banc initial où le dénominateur est défini.

## Commandes d'origine

- `TRAIN 0x236–0x266` et `0x67a–0x6b6`: chaque commande de combustible fait tourner indépendamment son octet de taux `0 → 1 → 2 → 0` (addition de 1, remise à 0 si supérieur à 2). Un taux est une quantité retirée par mise à jour du script TIME, pas une quantité par seconde démontrée.
- `TRAIN 0x377–0x389`: le frein bascule le drapeau `main+0x614a` entre 0 et 1. `TIME 0x2e4–0x2fa` force la vitesse effective à 0 si ce drapeau est actif.
- `TRAIN 0x628–0x665`: la commande du régulateur borne sa position à `[120, 200]`, puis stocke `trunc((position−120)×15/4)` dans `main+0x2fc4`. La cible varie donc de 0 à 300. Le script original lit une position d'interface; une autre interface peut exposer directement la cible calculée sans prétendre reproduire les pixels du contrôle.

## Une mise à jour de TIME, pour l'état ci-dessus

1. `TIME 0x0ea`: `chaleur += 10×taux_lignite + 30×taux_anthracite`. Si la chaleur dépasse `5000`, `0x0ff–0x123` déclenche un script/message et suspend l'exécution; le bloc ne démontre pas à lui seul une fin de partie irréversible.
2. `TIME 0x124–0x152`: soustrait séparément chaque taux de son stock, puis ramène tout stock négatif à 0. `0x158–0x189` émet un événement/message quand les deux stocks sont nuls alors qu'au moins un taux est non nul; l'exécution reprend ensuite à `0x18a`.
3. `TIME 0x18a–0x1ce`: si `chaleur > 0`, calcule `T=trunc(chaleur/100)+1`, puis `chaleur=max(0,chaleur−T)`. Il copie `min(chaleur,600)` dans l'état chaudière `main+0x2fc2`. Si cet état est supérieur à 100, ajoute `100×T` à la réserve motrice `main+0x2fc0`, ensuite bornée à `32000` par `0x1ed–0x20b`.
4. `TIME 0x215–0x274`: recalcule la masse de la composition, `W'=W+trunc(W/100)^2`, `H=trunc(W'/2)`, `D=trunc(32000/H)`, puis le coût `C=trunc((v + v×trunc(v/10))/D)` avec `v` la vitesse effective avant modification. `0x27a` retranche `C` de la réserve. Les formules et les tables de poids sont spécifiques au script original; un changement de composition impose le recalcul.
5. `TIME 0x280–0x2fa`: si la réserve vaut 0 ou moins, la ramène à 0 et retranche 5 à la vitesse. Sinon, si `réserve > 1500` **ou** `vitesse > 0`, rapproche la vitesse de la cible: si `abs(cible−vitesse)<5`, copie la cible; sinon ajoute `5×sign(cible−vitesse)`. Enfin, une vitesse négative ou le frein actif donne vitesse 0.

Deux vecteurs déterministes utiles avec la composition initiale, cible 0 et frein inactif: depuis l'état initial, un cycle avec taux `(1,0)` donne stocks `(1999,500)`, chaleur `9`, état chaudière `9`, réserve `0`, vitesse `0`; douze cycles identiques donnent stocks `(1988,500)`, chaleur `106`, état chaudière `106`, réserve `200`, vitesse `0`.

## Limites pour l'intégration

Le modèle ci-dessus définit **une mise à jour du script TIME**, pas une seconde réelle. `TIME 0x3a` installe une routine séquencée et `0x4f–0xe0` boucle sur un compteur; la source hôte possède sa propre cadence d'affichage. Ces éléments ne prouvent pas le nombre de mises à jour de chauffe par minute de jeu sur la machine d'origine. Une commande de pas manuel est fidèle aux calculs sans inventer cette cadence.

`TRAIN` ne stocke pas directement la vitesse effective; TIME la modifie sous la garde réserve/cible. Les commandes de taux de TRAIN ne consultent pas le stock avant de passer au taux suivant (`0x236–0x266`, `0x67a–0x6bc`); TIME peut donc émettre à nouveau l'événement de stock nul après reprise. Les événements « charbon épuisé » et « surcharge chaudière » sont observés comme script, message et suspension, et non comme une transition terminale prouvée. La réserve est un mot signé de 16 bits (`src/alis.h:296–297`, `src/mem.c:187–190`); TIME remet à `32000` toute valeur supérieure à `32000` **ou négative** après l'ajout de vapeur (`0x1ed–0x20b`), ce qui inclut un éventuel dépassement signé. La règle de navigation ou de jonction ferroviaire est distincte de la conduite de la chaudière.
