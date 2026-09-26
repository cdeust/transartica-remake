# Passation Claude → Codex : sprites du train par direction

26 septembre 2026. Outil neuf, aucun fichier existant du jeu modifié. `train-east.png`
reste l'image acceptée par le propriétaire ; rien n'a été réécrit dans `game/assets/`.

## Outil

`tools/sprite_pipeline.py` (tests : `tests/test_sprite_pipeline.py`, 10 cas).
Environnement local au projet :

```sh
export UV_CACHE_DIR="$PWD/.cache/uv" TMPDIR="$PWD/.cache"
uvpy() { uv run -q --no-project --with pillow --with numpy python "$@"; }
uvpy -m unittest tests.test_sprite_pipeline -v
# Contrôle seul d'une image générée (code retour 1 si refus) :
uvpy tools/sprite_pipeline.py W=output/imagegen/train-west-raw.png --reference game/assets/travel/train-east.png --out .cache/sprites --check-only
# Production : échelle commune, rognage, manifeste, planche de contrôle :
uvpy tools/sprite_pipeline.py E=game/assets/travel/train-east.png W=... SE=... NW=... NE=... --out .cache/sprites
```

Sans Pillow, `python3 -m unittest discover -s tests` ignore ces tests au lieu d'échouer.

Pour chaque image : alpha binaire (seuil 128, suppression du halo), axe principal
recalé sur la ligne des roues (contour inférieur si l'axe est plutôt horizontal à
l'écran, ligne médiane si le convoi s'éloigne ou approche), ancres nez/queue sur des
texels opaques, contrôle de la direction attendue (±4°), mise à l'échelle commune,
rognage, grille de pixels et palette partagée optionnelles (`--cell`, `--colours`).
Sorties : `train-<direction>.png`, `train-manifest.json` (les 8 directions, miroirs
inclus, et la liste `missing`), `contact-sheet.png` avec axe et ancres dessinés.
Le sens locomotive/queue ne se déduit pas d'une silhouette : vérifier sur la planche
que le point vert (nez) est bien sur la locomotive.

## Ne pas écraser l'image acceptée

Le `train-east.png` écrit dans `--out` n'est **pas** l'asset accepté : alpha durci
(≈20 000 texels de bord semi-transparents deviennent nets ou disparaissent) et toile
rognée ; ses ancres du manifeste ne valent que pour ce fichier traité. Deux options :

- garder les octets actuels de `game/assets/travel/train-east.png` et utiliser pour E
  les ancres de `--check-only` : nez (1466, 969), queue (9, 156) ;
- ou faire passer les huit caps par le même traitement, pour des bords identiques sous
  filtrage au plus proche.

Recommandation : la seconde, pour la cohérence entre caps, mais seulement après que
le propriétaire a vu `contact-sheet.png`. Ce n'est pas une décision à prendre en
copiant le dossier de sortie.

Contrôle heuristique supplémentaire : une épaisseur de caisse à ±25 % de la référence
après mise à l'échelle déclenche un avertissement (non bloquant) sur la planche. Il
vise l'échec le plus probable sur SE/NW : un convoi dessiné sans raccourci, qui serait
rétréci en largeur par la mise à l'échelle.

## Constats à prendre en compte

1. **Échelle et toile.** Avec `WORLD_EAST`/`WORLD_SOUTH`, une unité de monde mesure à
   l'écran 1,24 × la longueur est pour NE/SW et 0,69 × pour SE/NW. Le train E mesure
   1728 texels sur son axe ; un train NE à la même échelle en demande ~2130, plus que
   la toile 1536 × 1024 imposée par `travel-train-headings-prompt.md`. Proposition :
   laisser l'image générée à l'échelle qui tient dans la toile (toile portrait pour
   SE/NW) ; le pipeline remet chaque direction à l'échelle de référence.
2. **Échelle de dessin.** Les sprites sortis sont rognés, donc de largeurs différentes.
   `_draw_train()` calcule aujourd'hui `TRAIN_WIDTH / texture.get_width()` : il faudra
   une échelle constante (`760 / 1536` texel → pixel au zoom 1), sinon chaque direction
   change de taille.
3. **Ancres.** Mesure automatique sur `train-east.png` : angle 0,5093 rad (constante
   `TRAIN_AXIS_ANGLE` = 0,5070), nez (1466, 969), queue (9, 156), sur le contact des
   roues côté spectateur. Les constantes actuelles (1474, 942) / (30, 140) sont ~20
   texels plus haut, probablement sur l'axe de la voie. Choisir une convention ; si le
   calage actuel est bon en jeu, ajouter un décalage de voie constant plutôt que
   reprendre les ancres à la main.
4. **Intégration de `train_pose()`.** Lire le manifeste par cap ; `mirrored` → échelle
   x = −1 avec `source_nose` / `source_tail` ; supprimer le repli par rotation.
5. **Éclairage.** S, N et SW sont des miroirs horizontaux : la lumière « en haut à
   gauche » passe en haut à droite sur ces trois caps. Compromis connu, à signaler au
   propriétaire s'il est visible.
6. **Grille de pixels.** `--cell 3 --colours 48` sur `train-east.png` appauvrit
   nettement la locomotive (comparaison : `tasks/validation/sprite-cell3-compare.png`). Au zoom 1, un pixel
   écran vaut ~2 texels. Observation hors de mon périmètre : les rails sont tracés par
   `draw_line` antialiasé en pleine résolution ; une scène rendue en résolution native
   (SubViewport) puis agrandie par facteur entier unifierait train, sol et rails.

## Module de pixels autonome : `game/scripts/pixel_field.gd`

`PixelField` (RefCounted, test `game/tests/test_pixel_field.gd`, ajouté à `game/test.sh`) :
grille native (192 × 108 par défaut) de fumée, vapeur, neige, étincelles et débris.
Règles *inspirées* de la description publiée de Noita (Petri Purho, GDC 2019,
https://www.youtube.com/watch?v=prXuyMCgbTc ; résumés 80.lv et braindump cités dans
l'en-tête) : chute puis glissement latéral, mise à jour de bas en haut, gaz inversés,
particules libres qui quittent la grille et y reviennent à l'atterrissage. Les blocs
64 × 64, rectangles sales et passes en damier de Noita ne sont pas repris : ils servent
un monde entier, pas un émetteur local.

- `step()` est appelé par l'horloge de simulation, jamais par `_process` : même graine
  et mêmes entrées donnent le même champ quelle que soit la cadence (testé).
- `burst(cell, force)` : recette d'explosion (débris incandescents, étincelles, fumée),
  conforme à la décision FIDELITE du 26 septembre. `emit()`/`launch()` pour la vapeur
  de cheminée, la neige soulevée, etc. `wind` ∈ {−1, 0, 1}.
- `render()` et `render_glow()` : textures en résolution native, à dessiner agrandies
  par facteur entier avec `TEXTURE_FILTER_NEAREST` ; la lueur avec
  `CanvasItemMaterial.BLEND_MODE_ADD`.
- Non raccordé à `travel_world.gd` ni `main.gd` (fichiers de Codex). Points d'accroche
  suggérés : panache au-dessus de la cheminée (les prompts de train excluent la fumée,
  « animée séparément ») et futures explosions de combat.
- Limite : boucles GDScript par cellule, adaptées à ~20 000 cellules par cycle. Un
  champ couvrant toute la scène demanderait un shader de calcul ou une GDExtension.
- Aperçu (rendu headless, pas une capture en jeu) : `tasks/validation/pixel-field-preview.png`, 3 instants d'une explosion.

## Validation des quatre orientations générées par Codex (26 septembre 2026, Claude)

Sources trouvées hors projet dans `~/.codex/generated_images/01a0dad9-…/` (rien dans
`output/imagegen/`). Correspondance établie à l'œil, copies de travail dans `.cache/sprites/src/` :

| Cap | Fichier Codex | Copie |
|---|---|---|
| W | `exec-da32c9df-….png` (1536 × 1024) | `train-west.png` |
| SE | `exec-bb7d60c9-….png` (1024 × 1536) | `train-southeast.png` |
| NW | `exec-27978755-….png` (1024 × 1536) | `train-northwest.png` |
| NE | `exec-5a4a6aac-….png` (1983 × 793, hors format 1536 × 1024 demandé) | `train-northeast.png` |

Commande : `sprite_pipeline.py E=game/assets/travel/train-east.png W=… SE=… NW=… NE=… --out .cache/sprites`
→ 5/5 OK, manifeste complet (8 caps, `missing: []`), planche `.cache/sprites/contact-sheet.png`.

- Transparence réelle sur les quatre (alpha 0–254/255).
- Longueurs cohérentes avec la projection de `travel_world.gd` : SE 1186 et NW 1187 texels
  = 0,686 × E (attendu 141/206) ; NE 2135,5 = 1,236 × E (attendu 254,6/206).
- Sens de marche correct partout (locomotive en tête selon la table du prompt).
- Ordre des wagons correct sur les quatre (tender, voiture-lits, fourgon, observation, wagon blindé).
- Avertissements d'épaisseur SE 186 px et NW 204 px contre 275 px pour E : attendus pour une
  vue dans l'axe (on ne voit que la largeur), mais SE et NW diffèrent entre eux d'environ 10 %.
- **Défaut à corriger (régénération ou retouche)** : dans E, SE et NE, la verrière de la voiture
  d'observation et le canon du wagon blindé pointent vers l'avant (côté locomotive). Dans **W**,
  la verrière et le canon pointent vers l'arrière ; dans **NW**, la verrière pointe vers
  l'arrière. En jeu, ces voitures sembleraient pivoter de 180° au changement de cap
  (et N, miroir de W, hérite du défaut).
- NE est une vue latérale presque plate (toits peu visibles) ; acceptable, mais moins plongeante
  que les 35° demandés.

Aucun fichier copié dans `game/assets/` : le choix des images retenues et l'intégration
restent à Codex. Décisions propriétaire toujours ouvertes : voir plus haut (convention
d'ancres, traitement de `train-east.png`, éclairage des miroirs).

## Train qui se « casse » dans les virages : constats pour Codex (26 septembre 2026, 02:45, Claude)

Signalé par le propriétaire : pendant un changement de cap, une moitié du train est dessinée
ailleurs au lieu de suivre les rails. Codex traite déjà le défaut (`train_path.gd`,
`TrainJourney.sample_behind()`, `_test_visual_curve`, 02:42). Claude n'a modifié **aucun**
script de jeu. Ce qui suit sert à l'étape de rendu.

Causes relevées dans `travel_world.gd` (état de 01:49) :
1. `_draw_train()` dessine le convoi en **un seul sprite rigide** ancré au nez et orienté
   selon le cap de la tête : à chaque changement de cap, les ~4 cases de wagons pivotent
   d'un bloc autour de la locomotive.
2. `_process()` interpole `_visual_from.lerp(_visual_to)` en coordonnées monde : même avec
   deux extrémités sur les rails, un cycle qui franchit le centre d'une courbe coupe le coin.
   Interpoler plutôt `distance_travelled()` (abscisse curviligne), puis échantillonner.
3. (corrigé par Codex dans `fractional_position()`) la tête dépassait le centre de la case
   courbe dans l'ancien cap entre les phases 0 et 1, puis sautait.

Attelages mesurés à l'œil sur `train-east.png` (graduations tracées sur l'axe des roues
`TRAIN_NOSE_TEXEL` (1474, 942) → `TRAIN_TAIL_TEXEL` (30, 140), longueur 1651,8 texels ;
imprécision ± 20 texels, soit ± 10 px à l'écran) :

| Voiture | du texel | au texel |
|---|---|---|
| locomotive (chasse-neige inclus) | −80 | 490 |
| tender | 490 | 675 |
| voiture-lits | 675 | 910 |
| fourgon | 910 | 1120 |
| voiture d'observation | 1120 | 1410 |
| wagon blindé | 1410 | 1651,8 (+110 de marge pour l'arrière) |

- Coupe entre voitures : une droite passant par le point d'attelage sur l'axe, inclinée
  d'environ 25° à droite de la verticale, prolongée d'environ 90 texels sous l'axe et de
  460 au-dessus. En ligne droite, les bandes adjacentes recomposent exactement le sprite,
  quelle que soit la précision de la coupe ; les petits défauts n'apparaissent qu'en virage.
- Mesure de longueur : 760/1536 px à l'écran par texel au zoom 1. Le sprite E pivoté garde
  sa taille à l'écran quel que soit le cap : placer les voitures en distance **écran** le
  long de la voie évite trous et chevauchements tant que seule l'image E existe. Avec les
  sprites directionnels, les longueurs du pipeline sont déjà cohérentes en distance monde
  (SE/NW 0,686 × E, NE 1,236 × E).
- Limite du repli actuel : `train_pose()` choisit `reversed` (wagon blindé en tête) pour
  W, NW et N. Voiture par voiture, un virage SW→W ou NE→N inverse alors l'ordre du convoi :
  seuls les sprites W/NW (à corriger, voir plus haut) lèvent ce défaut.

## Déformation et échelle du train modulaire (26 septembre 2026, Claude, diagnostic sans modification)

Signalé par le propriétaire : « déformation et problème d'échelle ». Causes mesurées dans
`train_renderer.gd:84-100` (`registration`) et `vehicles.json` :

1. **L'échelle dépend de la corde de voie.** `scale = |front−rear| écran / |front−rear| atlas`
   est aussi appliquée à la verticale (`basis_y = (0, scale)`). Dans un virage, la corde entre
   l'avant et l'arrière raccourcit, donc la voiture s'écrase verticalement pendant le virage.
2. **Cisaillement dans les virages.** `basis_x` force l'axe du sprite (une des 8 directions) sur une
   corde d'angle intermédiaire tout en gardant la verticale : la voiture est cisaillée.
3. **Longueurs de `TrainConsist.LENGTHS` incohérentes avec les dessins.** Texels d'atlas par
   pixel écran (distance des ancres ÷ longueur monde × projection), ×100 :

| cap | loco | tender | lits | fourgon | observ. | blindé |
|---|---|---|---|---|---|---|
| 6 E | 236 | 354 | 303 | 307 | 296 | 314 |
| 4 W | 210 | 334 | 329 | 305 | 284 | 346 |
| 3 SE | 216 | 362 | 302 | 312 | 271 | 316 |
| 7 NW | 226 | 359 | 311 | 322 | 261 | 293 |
| 9 NE | 200 | 291 | 297 | 263 | 281 | 287 |

   Le tender est ainsi dessiné à environ 67 % de l'échelle de la locomotive, et une même voiture
   change de taille de ±10 à 15 % en changeant de direction.

Correction proposée : une échelle unique et constante (texels → pixels écran) pour tous les
véhicules et toutes les directions, sans ajustement à la corde. Placer chaque sprite par le
milieu de ses ancres sur le point milieu de la voie, et choisir la direction selon la corde.
Dériver `LENGTHS` des ancres E à cette échelle : avec la locomotive gardée à 1,0, cela donne
tender 0,75, lits 0,77, fourgon 0,78, observation 0,88, blindé 0,80 (total 4,98 cases). Les
écarts entre directions viennent des images générées elles-mêmes : les corriger demande de
retoucher les ancres ou les atlas.

## Correction appliquée par Claude (26 septembre 2026, ~11:30, décision du propriétaire)

- `train_renderer.gd` : une seule échelle texel → pixel (`texels_per_cell` = portée des ancres de la loco E, 486,2 texels = 1 case), sans cisaillement ni ajustement à la corde ; le milieu des ancres se place au milieu de la corde écran ; le cap reste choisi selon la corde.
- `train_consist.gd` : LENGTHS loco 1,0, tender 0,75, lits 0,77, fourgon 0,78, observation 0,88, blindé 0,80 (4,98 cases).
- `train_journey.gd` : la tête traverse chaque case à vitesse constante sur les trois phases (le centre est franchi pendant la phase 1) ; `sample_behind`/`distance_travelled` testent « tête après le centre » au lieu de `phase > 0`.
- Tests adaptés (valeurs indépendantes recalculées), 9/9 suites PASS hors bac à sable.
- Captures en fenêtre macOS : `tasks/validation/modular-train-uniform-{start,turn,southeast}.png`.

Reste ouvert (images, périmètre Codex) : l'étirement vers le sud. Le rendu n'étire plus rien, mais les
voitures SE de `vehicles-southeast-v2.png` sont dessinées plus hautes qu'un modèle de boîte ajusté sur E
(hauteur écran au zoom 1 : tender 202 px contre 142 prévus, lits 202/158, fourgon 195/163 ; NW plus proche,
166-196). Les jours NE/SW (atlas NE ~15 % trop court pour la projection) restent aussi à corriger dans l'atlas.

## Régénération Codex SE / NW, 26 septembre 2026

Atlas actifs : `vehicles-southeast-v3.png` et `vehicles-northwest-v2.png`.
Originaux conservés. Prompts et copies sources dans `output/imagegen/`.
Seuls les deux atlas et leurs entrées dans `vehicles.json` changent le jeu ;
le rendu uniforme et les longueurs de Claude sont conservés.

Les nouvelles silhouettes SE ont pour hauteurs écran à zoom 1 : locomotive
196,5 ; tender 133,4 ; lits 172,8 ; fourgon 171,9 ; observation 178,3 ; blindé
178,7 px. Mesure du rectangle alpha >=128, sans redimensionnement du PNG.
Rapport avant/après : `tasks/validation/foreshortening-measurements.json`.
Les cibles de boîte 142/158/163 restent approximatives ; lits et fourgon sont
encore légèrement plus hauts. NW : verrière d'observation déplacée à l'avant
lointain, face arrière plate ; canon toujours orienté vers l'avant lointain.
La silhouette d'observation NW devient légèrement plus haute avec cette verrière.

Ancres : abscisses relevées au centre des attelages visibles, ordonnées proches
sur leur contact au sol ; extrémités cachées déduites des longueurs de Claude
et de la projection existante (portée E × sqrt(2) ×100/hypot(180,100)).
Ce sont des ancres graphiques estimées, pas une mesure des règles originales.

Validation : import Godot réussi, 9 suites PASS. Captures natives
`modular-train-foreshortening-{turn,southeast}.png`. Trajet NW non capturé.
`review_foreshortening.gd` ouvre le trajet SE en pause avec sauvegarde de test
isolée. L'atlas NE/SW reste à corriger séparément.
