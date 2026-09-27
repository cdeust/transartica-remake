# Scène de ville : glieu, ville, usine, mamesc, commerce (26 septembre 2026, Claude)

Offsets = offsets dans `reference-private/unpacked/<script>.alis`. Listings : `tools/alis_disasm.py
--all-entries --json`, lecture `tools/claude/alis_pretty.py` (travail dans `.cache/city-scripts/`).
`Lx` = variable locale du processus (octet `b`/mot `w`), `Lw[0x44][i][j]` = tableau local de mots,
`main[..]` = tableau de main, `shimb[14,12]` = écrit l'octet 0x0c du processus dont le handle est en
`L0x0e` (`storenames.c:189-197`). Types de ville = `abs(VILLE.FIC champ 2)` (FORMAT-VILLES.md).
Données dérivées complètes (privées) : `reference-private/city-scripts/` (`glieu-commerce.json`,
`texte2k-messages.txt`, `textek-messages.txt` et les scripts d'extraction, à lancer depuis `.cache/city-scripts/`).

Corrections d'outils :
- `alis_pretty.py` : avec `opile`, l'opérande gauche est la valeur dépilée (`opernames.c:280-284` opile,
  `alis.c:165-168` saveD7). L'ancien affichage inversait `-`, `/`, `%` et les comparaisons (13 instr.
  de yoda, 8 de time concernées ; aucune citée dans tasks/evidence n'en change le sens : TIME 0x223 et 0x2a5f
  sont des bornes de boucle). Les tableaux distinguent maintenant `main[..]`/`L[..]` et la largeur (`w`).
- `alis_disasm.py` : ajout de `cfopen/cfclose/cfreadv/cfwritev/cfreadb/cfwriteb/cordspr` (`opcodes.c:2501-2780`,
  `4134`) et `--all-entries` (points d'entrée d'en-tête). Tests : `tests/test_alis_disasm.py`
  (`test_header_entries_and_resource_boundary`, `test_file_opcodes_from_main`).

## 1. Pourquoi ville.alis « s'arrête » à 22 instructions

Ce n'est pas une erreur de longueur d'opérande. En-tête : `+0x06` s32 = gestionnaire post-tick
(`alis.c:1183-1188`, PC = en-tête+6+val), `+0x0a` s32 = gestionnaire d'interruption/messages
(`alis.c:1141-1146`, PC = en-tête+10+val), `+0x0e` s32 = table des ressources (`alis.c:1345-1348` adresdes).
Le code s'arrête à la table : ville 0x18–0x76 (22 instr., tout décodé), mamesc 0x18–0x64, usine 0x18–0x88
(+ gestionnaire 0x1c), glieu 0x18–0x2b66 (1514 instr., aucun octet de code non couvert hors 13 trous de 1–6 octets).
Le reste de ces fichiers = images/palettes. **ville, mamesc, usine sont des décors, pas de logique.**

- `ville 0x29` : `cswitch2 L0x0c` (= type écrit par glieu 0x9e) : 1→`cput 4`, 2→`cput 1`, 4→`cput 7`, 3→palettes seules.
- `mamesc 0x29` : type 5→`cput 1`, 6→`cput 4`.
- `usine 0x1c` (messages) : 33→`cerasen 0` ; 34→redessine le fond (`0x5e`) ; autre valeur v (type de wagon)
  → `cputnat … 29+(v−4)` (image du wagon).

## 2. glieu.co : contrôleur de ville (`L0x0c` = index de ville, écrit par yoda `shimb[66,12]`)

Entrée (`0x18–0xaf`) :
- `L0x0c == −1` → écran « gare-atelier » `0x21ea` (§2.6).
- `0x2f` bandeau : `cputnat … 19`, textek message −95 avec octet 13 = index de ville (contenu non résolu).
- `0x33` : `main[0x5fe4][ville][2] = −abs(champ2)` → **la visite rend le champ 2 négatif**.
- index 10–16 : `clive 17` (usine) puis atelier `0x1d64` ; 45 : `clive 22` (scene3) ; <5 : `clive 34` (mamesc) ;
  sinon `clive 10` (ville) + `shimb[14,12] = type`. Type 2 → `L0x16 = 1` (mode marchandises).

Menu (`0xc7–0x1ef`) : sprites de menu 24 (type 1), 25 (type 4 si espion possible), 22 (autres), puis 21.
Attente `main+0x1c ∈ {50,51,52}` ; 52 → départ (`0x1d0` → `0x2b50` : `csend 9`, cf. station-arrival.md).
`L0x12 = main+0x1c` puis `cswitch2 type` (`0x1ef`) :

| type | 50 | 51 | préparation |
|---|---|---|---|
| 1 TOWN | msg texte2k `(v−17)·2+1` | `(v−17)·2+2` | textes d'histoire 1–14 (`0x20e`), retour menu |
| 2 COMMERCIAL | msg 26 achat marchandises | 27 vente | `0x157c` table, boucle `0x310` |
| 4 GARRISON | msg 24 enrôlement soldats | 25 espion | `0xd5f` |
| 5 MAMMOTH FAIR | msg 20 achat mammouths | 21 vente | `0xcd1` |
| 6 SLAVE MARKET | msg 22 achat esclaves | 23 vente | `0xd23` |

Garnison (`0x100–0x189`) : espion proposé seulement si une fiche libre existe dans `main[0x5d84][k][0]`
(k 0–19) **et** ville 8 ou 9 ; sinon enrôlement direct (msg 24). Villes 5–7 : départ automatique après
validation ou sortie (`0x790`).

### 2.1 Paramètres de transaction (`L0x36` = prix d'achat, `L0x38` = prix de vente)
Preuve du sens : `0x555` `main+0x2fb6 −= L0x28` si `L0x12 == 50`, sinon `+=` (`0x55f`), avec
`L0x28 = qté × L0x36` (achat) ou `× L0x38` (vente) (`0x7a9`). `L0x14/L0x3a`, `L0x15/L0x3c` = type de
wagon/capacité par wagon acceptés.

| sous-prog. | wagons (type:capacité) | prix par ville (achat/vente) |
|---|---|---|
| mammouths `0xcd1` | 7:3, 7:3 | 0 CASABLANCA 350/150 ; 1 BHOPAL 250/200 ; 2 TEMIR TAU 300/250 |
| esclaves `0xd23` | 5:60, 6:100 | 3 SEROV 14/12 ; 4 LOUXOR 12/10 |
| soldats `0xd5f` (L0x12=50) | 23:50, 24:80 | 5 ABU DHABI 6 ; 6 TASKENT 7 ; 7 MOSCOW 10 ; 8 BERLIN 12 ; 9 SPARTA 12 |
| espions `0xd5f` (L0x12=51) | 22:5, 22:5 | 0 |

Marchandises : `0xdd2` remet `L0x36 = L0x38 = 0`, puis `cswitch2` sur le type de marchandise 1–16
(`0xddc`) : wagons 17:20/18:40 (rails, bois, antiquités, fourrure…), 17:5/18:10 (missiles, draisines),
19:20/19:40 (plantes), 14:20 (alcool, pétrole), 15:20 (essence) ; les prix sont des `cswitch1/2` sur
l'index de ville 24–45 (`0xfcb–0x157b`). Ex. rails `0xfcb` : vente 2 par défaut, KUWAIT (24) achat 4 ;
missiles `0x102d` : vente 30, achat 43 (24), 41 (29)… Table complète 22×16 : `glieu-commerce.json`.
Aucune valeur n'est lue dans un fichier : **les prix sont codés en dur dans glieu**.

### 2.2 Liste de la ville (`0x157c`)
Vente/achat marchandises : `Lw[0x44][k] = (type, quantité)`, 16 cases (grille 5×4, sélection
souris `main+0x18/0x1a`, `0x409`). Achat : une marchandise g apparaît si `main[0x6160][ville−24][g−1] > −1`
(`0x1607`). Vente : somme des cargaisons `[2]/[3]` des wagons de type 14, 15, 17, 18, 19 (`0x1661`).
Ville 45 : `main[0x6160][21][3] = 5 + rnd(40)` à chaque visite (`0x1588`).

### 2.3 Boucle de transaction (`0x310–0x790`)
- Capacité `0x90a` : pour chaque wagon de type `L0x14`/`L0x15` compatible (hors marchandises, ou cargaison
  vide, ou même marchandise), `L0x2a += capacité − [3]`, `L0x2c += [3]`.
- Hors marchandises : achat impossible si `L0x2a == 0` (msg 51), vente si `L0x2c == 0` (msg 18).
- `main+0x1c == 52` (+1), achat : refus si `L0x2a < qté+1` (msg 51), si marchandise et `qté+1 > stock ville`
  (rien), si `main+0x2fb6 < total+prix` (msg 50). Vente : refus si `qté+1 > L0x2c` (msg 52) ou si
  `(qté+1)·prix > 5000 × (tenders type 21 d'état ≠ 3) − (main+0x2fb6 + main+0x2fc8)` (msg 54).
- `51` : qté −1 (si >0). `53` : sortie. `50` : validation `0x549` : argent débité/crédité ; après
  crédit, si `main+0x2fb6 < 0` ou `> 31000` → 31000 (`0x565`) ; puis `0x9ec`.
- `0x9ec` achat : espions → marque `qté` fiches libres `main[0x5d84][k][0] = 1` ; puis remplit les wagons
  un par un (`[3] += 1`), marchandises : `stock ville −= 1`, `[2] = marchandise`. Vente `0xbd0` : `[3] −= 1`,
  marchandises : `stock ville += 1` seulement si ce stock > −1 ; wagon vidé → `[2] = 0`.

### 2.4 Atelier des villes industrielles 10–16 (`0x1d64–0x21e7`)
Menu sprite 47 ; 52 = départ, 50 = achat de wagons. `0x1905` : liste (type, prix) par ville, ex.
IN SALAH : (21,100) (19,450) (17,250) (12,500) (14,400) (5,150) (23,300) (7,300) ; RUM : (8,800).
Sélection : `csend usine type`, texte2k msg `type+56` (`0x2046`, fiche du wagon), prix en mot 0.
+1 refusé si `qté + main+0x2fac > 99` (msg 17), si tender et `tenders intacts + qté ≥ 6`, si argent
insuffisant (msg 50). Validation : `main+0x2fb6 −= total`, ajout de `qté` wagons `main[0x2e1a][n][0] = type`,
`main+0x2fac += 1`, puis `0x27c3` (drapeaux : type 4 → `main+0x307b = 2`, type 10 → ≥ 1, type 13 → `main+0x62c1 = 1`).

### 2.5 Tableaux de textes
- texte2k (message = `abs(octet 0x0c)`, `0xb8`) : 16 achat de wagons, 17 plus de wagons, 18 rien à vendre,
  20–27 titres commerce, 30–45 unités des 16 marchandises (`29 + type`), 50–54 refus, 60–81 fiches
  des wagons (`type + 56`), 85–93 gare-atelier ; 110–118 = pages suivantes de 1,2,3,6,8,9,10,12,14 (`0x25f0`).
- textek `0x3172` (switch sur `L0xb8 = main[0x2e1a][i][0]`, `0x15f`) : 25 noms de types de wagons (1 LOCOMOTIVE … 21 TENDER, 22 SPY, 25 BOILER),
  ordre cohérent avec les fiches texte2k `type+56` ;
  `0x3648` : état `[1]` 0 PERFECT, 1 BRUISED, 2 OLD, 3 SCRAP IRON.

### 2.6 Gare-atelier (`L0x0c = −1`, `0x21ea`)
Lancée par yoda message 65 (`cswitch1 0x20` → `0x1e2`, scène −4 → `0x11cc` → `clive 15`, `shimb[66,12] = −1` à `0x1277`) ;
charge aussi `mine.AO` (`clive 18`). Nom affiché selon `main+0x2fbe` (<30 LEEDS, <70 AOUDJILA, <100
NOVOMOSKOVSK) puis `main+0x2fb1` (<50 BALKHACH, sinon OMAN). Choix `main+0x1c` : 50 déplacer (msg 90),
51 départ, 52 réparer (msg 92), 53 détruire (msg 93).
- Réparer `0x2523` : état 3 → msg 87 ; état 0 → textek 35 ; sinon coût = `unité(type) × état`
  (`0x2a48`), confirmation textek −2, refus si argent < coût (msg 50), sinon état = 0 et argent −= coût.
  Unités : 1:100 2:80 3:50 4:80 5:10 6:15 7:20 8:60 9:30 10:50 11:50 12:40 13:80 14:30 15:30
  16:60 17:10 18:15 19:40 20:30 21:10 22:60 23:15 24:20 25:80.
- Sans outil (`L0x12 = 0`, remis à 0 en `0x236a` et `0x26be`) : clic sur un wagon → textek −1 (fiche
  WAGON / TARE WEIGHT / STATE / TRANSPORT, `0x2679`) avec octet 13 = index du wagon.
- Confirmation `0x2748` : clic x 170–201, y 6–18 → `L0x1d = 0` (exécuter) ; x 120–151, même y → `L0x1d = 1` (annuler).
- Détruire `0x25f8` : refus (msg 88) si type < 4 ou (type 21 et `[3] ≠ 3`) ; sinon textek −3, suppression.

## 3. COMMERCE.FIC

Aucun script ne le nomme : les seuls `cfopen` littéraux sont dans main (`0x78d–0x7e5`) : ville.fic →
`main+0x5fe4` (138), carte.fic → `+0x76` (11680), hima.fic → `+0x62c6` (240), trans.fic → `+0x63ba` (276),
oasis.fic → `+0x64d2` (27). Les seuls `cfopen` dynamiques ouvrent le nom `main+0x6528` construit avec
`.SAV` (room `0x726–0x787` écriture, option `0x6c3` lecture). Contenu : 32 × `0x01` puis 1440 × `0x00`.
46 × 32 n'est qu'une factorisation. Les données commerciales réelles sont les prix en dur de glieu et les
stocks `main+0x6160` (22 × 16 octets, `cdim` de main `0x61`) initialisés par TABLE `0x75d–0xf0a`
(−1 = non vendu, sinon 20+rnd(20), 60+rnd(40), 5+rnd(5)…), sauvegardés (room `0x8cb`, 352 octets).
Recoupement : 94 cases de stock ≥ 0 ; toutes ont un prix d'achat > 0. Six prix d'achat > 0 ont un stock −1
(poisson 28/32/33, draisines et essence 42, antiquités 45 — cette dernière remplie à la visite, `0x1588`).
TABLE `0xe22` écrit dans la ligne 0 (KUWAIT) au lieu de la 18 (TAOUDENI) pour les draisines : défaut d'origine
conservé tel quel.

## 4. Variables de main

- `0x2fb6` lignite = argent, `0x2fc8` anthracite (locomotive-rules.md) ; plafond 31000 à la vente.
- `0x2e1a` wagons : 100 × 4 octets (`[0]` type 1–25, `[1]` état 0–3, `[2]` marchandise 1–16, `[3]` quantité) ;
  `0x2fac` = nombre de wagons. Mammouths, esclaves, soldats et espions sont des quantités `[3]` dans leurs wagons.
- `0x6160` stocks des villes 24–45 ; `0x5d84` 20 fiches d'espion de 15 octets (`[0]` = occupé).
- `0x18/0x1a` souris x/y, `0x1f` bouton, `0x1c` code de sélection (lu, jamais écrit par un script décodé).

## Limites

- L'écrivain de `main+0x1c` n'est pas trouvé (aucun store dans les scripts) : les libellés OK/−/+/sortie
  pour 50–53 sont déduits des effets, pas des images des boutons.
- Contenu du message textek 95 (bandeau de ville) : chaînes vides dans le switch, composition non lue.
- Émetteur du message 65 : TIME envoie le code de tuile (`0x24da`, `0x256f`) et 5 cases de CARTE.FIC valent
  65, mais les conditions de ces branches ne sont pas lues.
- Sens de `main+0x307b`, `main+0x62c1`, du test `[3] ≠ 3` des tenders, des sprites de menu 21–25 : inconnus.
- `rnd(n)` suit `opernames.c:433-437` ; les stocks initiaux exacts dépendent de la graine.
- texte2k : un index négatif remet `main+0x62c0` à 0 (`0x250c–0x2518`), un positif le met à 1 (`0x7d`) ;
  glieu utilise −50/−52/−54 pour les refus : sens exact de cette différence non prouvé.
- Rien de cette chaîne n'est observé en exécution (la trace ne contient pas glieu).

## 5. Masse des wagons (TIME `0x2a77`/`0x2b4a`, lu le 26 septembre)

`0x2a77` : `cswitch2 type−1` → poids de base des types 1–25 :
1:1000 2:50 3:40 4:110 5:65 6:85 7:60 8:105 9:20 10:100 11:100 12:40 13:120 14:40 15:45 16:55 17:45
18:55 19:40 20:90 21:50 22:50 23:80 24:100 25:200.
`0x2b4a` : `cswitch2 type−5` → charge `[3]` : types 5, 6, 23, 24 `+[3]/10` (`0x2b84`) ; 7 `+[3]×10`
(`0x2b98`) ; 14, 15, 17, 18, 19 `+[3]` (`0x2bac`) ; 21 `+[3]×10` (`0x2bbd`) ; autres `+0`.
Train TABLE : 1266 (inchangé). Le commerce modifie donc la masse et la consommation.

## 6. Ordre de chargement (`0x9ec`/`0xbd0`)

Achat : wagons parcourus dans l'ordre ; un wagon compatible est rempli jusqu'à sa capacité avant de
passer au suivant (`0xa91` boucle tant que `[3] < capacité`) ; type a testé avant type b. Vente : même
parcours, chaque wagon vidé avant le suivant. Stocks `main+0x6160` : octets signés (lecture `> −1`).
`rnd(n)` = mot haut de `n × graine` (`opernames.c` `ornd`), donc 0…n−1 (hypothèse : `varD7` lu sur 16 bits).
Formules de stock exportées : `reference-private/city-scripts/stock-init.json` (base, n).

## Portage (26 septembre 2026, Claude)

- `game/scripts/train_wagons.gd` : table `main[0x2e1a]` (TABLE), masse §5 ; `engine.train_mass` en dérive.
- `game/scripts/city_trade.gd` : offres §2.1, liste §2.2, capacité/refus/validation §2.3, ordre §6,
  plafond 31000, fiches d'espion, stock des nomades à chaque visite. Données privées chargées à
  l'exécution : `reference-private/commerce.json` (produit par `tools/build_commerce_data.py`,
  copié par `build_preview.py`).
- `game/scripts/city_screen.gd` : menu par type de ville, transaction (−, +, valider, sortir), départ
  automatique des villes 5–7, départ forcé si enrôlement direct sans place.
- Adaptations : libellés et refus rédigés par le remake (pas les textes texte2k) ; en ville 8–9 sans
  fiche d'espion libre, l'enrôlement direct n'est lancé qu'à l'arrivée (l'original y revient après
  chaque transaction) ; une marchandise doit être choisie avant « + ».
- Atelier des villes 10–16 (§2.4, relu le 26 septembre sur `0x1905–0x21e7`) : `city_trade.gd`
  (`workshop_list`, `workshop_refusal`, `buy_wagons`) et `city_screen.gd` (menu « achat de wagons » /
  départ ; liste ; sélection → quantité 0 ; + / − sans effet sans sélection ; validation : débit sans
  plafond, ajout de `qté` wagons `[type,0,0,0]`, désélection, on reste dans la liste ; sortie → menu de
  l'atelier, pas départ). Refus de +1 dans l'ordre : `nb + qté > 99` (msg 17), tender si `tenders
  intacts + qté ≥ 6` (**silencieux**, `0x2174`), argent `< total + prix` (msg 50). Listes (7 villes :
  8/8/5/7/6/1/8 entrées) et 25 noms textek extraits par `reference-private/city-scripts/workshop.py`
  vers `commerce.json` (clés `workshop`, `wagon_names`).
  Hypothèses : les emplacements de `Lw[0x44]` au-delà de la liste valent 0 (variables locales à
  l'entrée du script, non prouvé) ; l'original n'écrit que `[0]` du nouveau wagon, les autres octets
  gardent l'ancien contenu de l'emplacement — nuls tant que la destruction (gare-atelier) n'existe pas.
- Correspondance type → véhicule dessiné : **non décodable**. L'original dessine chaque type avec son
  propre sprite (glieu `cputnat … 48+(type−4)`, usine `29+(v−4)`) ; les six véhicules de
  `train_consist.gd` sont des illustrations du remake. Les wagons achetés comptent pour la masse et les
  capacités mais ne sont pas dessinés : choix artistique laissé au propriétaire.
- Non portés : drapeaux `0x27c3` (`main+0x307b`, `main+0x62c1` : lecteurs inconnus) et `csend LOC-40 99`
  après achat ; textes d'histoire des villes TOWN, gare-atelier, marque de visite (champ 2 négatif),
  effets des mammouths/esclaves/soldats au-delà de leur masse.
- Captures natives de l'atelier (clic et touches réels) : `tasks/validation/city-workshop-in-salah.png`,
  `city-workshop-in-salah-bought.png`.
- Tests : `game/tests/test_city_trade.gd`, `test_playable_trip.gd::_test_city_trade_screen` ;
  captures natives `tasks/validation/station-arrival-bhopal.png`, `city-trade-kuwait.png`.
