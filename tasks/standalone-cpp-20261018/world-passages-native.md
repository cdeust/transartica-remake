# Passages du monde natif

Le propriétaire demande des entrées de montagne visibles et un passage souterrain
correctement dessiné. Root a autorisé la couverture par les pixels des peintures
actuelles le19octobre2026. Cette couverture remplace la visibilité par alpha0.75
dans le dessin du monde. C'est une adaptation visuelle autorisée ;
`travel_cover.gd` ne définissait pas de masque par cellule souterraine.

## Sources conservées

`underground_visual.gd:5–16` classe les voies couvertes38..52 et55..57, en valeur
absolue, et distingue les bouches53/54/58. `travel_cover.gd:12` fixe six sites :

| Cellule CARTE | Code | Ouverture vers la surface |
| --- | --- | --- |
| (61,51) | 53 | sud |
| (30,58) | 54 | ouest |
| (51,39) | 54 | ouest |
| (12,21) | 58 | est |
| (105,23) | 58 | est |
| (113,58) | 58 | est |

`terrain_portals.gd:66–87` conserve la hauteur verticale de l'arche, son
cisaillement mesuré et la jauge projetée. La section `rail_endpoint` rejoint
exactement le port extérieur de la cellule. `travel_cover.gd:59–65` sépare
plancher et couronne à `mouth_anchor.y`.

`WorldPassages` dessine le plancher avant les véhicules, puis les pixels des
peintures dans les cellules couvertes et derrière le plan d'ouverture mesuré
de chaque bouche, puis la couronne. Il redessine
le pointillé source après la couverture pour conserver le repère de carte.
Les fragments de véhicules encore à l'extérieur restent opaques. La carte et
les contacts physiques ne changent pas ; une montagne peinte sur une cellule
ordinaire ne crée aucun tunnel ni masque supplémentaire.

Les anciens `world-objects.json` et `world-occluders.json` restent exclus. Leurs
contours authentifient des peintures et foregrounds1312×1199 antérieurs aux
huit régions actuelles. Les réutiliser ne respecterait pas leurs silhouettes.

La revue des captures préparées `passages-mouth` et `passages-inner` du19octobre
a révélé un véhicule exposé entre la frontière de cellule et l'ouverture
en12,21. Le fragment est absent de `mouth-12-21-floor.png` et apparaît après le
dessin du héros. Le masque s'arrêtait à la cellule souterraine, tandis que
`mouth_anchor` situe l'ouverture dans la cellule bouche. La couverture se
prolonge maintenant jusqu'à cet ancrage transformé avec la même registration
que l'atlas, du seul côté intérieur. Les ports et les dimensions restent fixes.
Cette extension appartient à l'adaptation de visibilité autorisée par root.

Les six captures montrent aussi une arche séparée du relief peint. En51,39,
une falaise existe derrière mais ne rejoint pas la bouche ; les autres sites
présentent surtout de la neige au contact. Cette correction demande une retouche
locale du fond. Agrandir ou déplacer l'atlas changerait le raccord mesuré aux
rails. Le code ne crée aucun relief de remplacement.

## Ouvrages et dépendances

Les états67/63,69/64,-116/-121 et114/-117 utilisent la couche isolée
`terrain_obstacles.gd::draw_rails_only`, avec les ports et jauges du descripteur.
La paire NS lac réutilise69/64 comme dans cette source. Aucun grand fond de
`obstacles-master.png` n'est ajouté aux paysages. Les rails ordinaires de ces
seules cellules sont exclus par `WorldPassages::owns_rails`, car l'asset contient
ses rails. Les autres voies gardent le moteur de rails existant.

Les codes d'ouvrages cassés servent aussi à prolonger la géologie. La couche
isolée ne se dessine que si au moins un voisin possède le port réciproque vers
l'axe de l'ouvrage, selon `rail_glyphs.gd` et `rail_network.gd`. Un seul raccord
suffit pour conserver une extrémité valide. En Amsterdam,67 en25,24 garde ses
bouts de rail ;67 en25,25 et26,26 n'en reçoit plus. CARTE reste intacte.

Le pont temporisé fermé en110,33,code-120, supprime les rails ordinaires sans
dessiner d'atlas. `game_calendar.gd:11–16` fixe sa position et ses états ;
`travel_terrain.gd:124–126` convertit-120 en ressource136. L'image136.png
inspectée montre seulement l'eau. L'état ouvert-121 conserve le pont de l'atlas.

Le paquet doit conserver ces fichiers sous `game/assets/travel/terrain/` :

- `underground-mouths.json`, empreinte du descripteur source
  `dc0782286f681f124a955e76c7facf4646dfaec8e0412264493e7ee234039e12` ;
- `underground-mouths.png`, atlas2014×781, empreinte
  `3257c10443d3c9dc1832c29d1e373808a00d0079b4202b009aa7d65cebab3427` ;
- `obstacles.json`, empreinte source
  `703ddd339ea3735809bee7672b78cd846cdbc662d76f129c95256ee673ea35e7` ;
- `scenes/bridges-only-v1.png`, empreinte inspectée
  `19fc7e79c5da692cca2813fdcd1480051f7f059bf4d26545e08bc047e1c3c4a5`.

Le Canvas existant possède les textures et leur éviction. Le module conserve
seulement les petits descripteurs. Les cellules examinées par image sont bornées
au viewport, avec la marge d'une cellule de `travel_world.gd`.

## Probe à exécuter par root

Nouveau fichier `native-game/tests/world_passages_probe.cpp`, à raccorder à une
cible équivalente à `rail_render`. Le probe exige un répertoire de sortie
existant et refuse d'écraser ses captures. Paramètres obligatoires :

```text
world_passages_probe --game-dir GAME --artwork-dir WORLD_HD --font FONT
  --output-dir EXISTING_DIR --renderer accelerated --density PIXELS_PER_CELL
  --placement mouth
```

Répéter avec `--placement inner` dans un autre répertoire. `mouth` place le héros
au milieu de la bouche ; `inner` le place à la frontière avec son voisin couvert.
La densité reste un paramètre explicite dans la limite de zoom source2.

Chaque exécution produit24 captures cumulatives, dans l'ordre
`floor`, `train`, `cover`, `crown`, et `world-passages.json`. Le probe compare
indépendamment les sections du descripteur aux ports CARTE et vérifie que la
coupure plancher/couronne garde ses points communs. Il refuse un héros sans pixels
visibles ; en placement `inner`, il exige un changement sous ses bounds après
couverture. Ces compteurs concernent la boîte du véhicule, pas son masque alpha.
Un second dessin du couvert sans héros fournit une référence de rasterisation.
Le compteur `hero_changed_pixels_unrestored_after_cover` examine seulement les
pixels modifiés par le héros et exige zéro en placement `inner`. Ce contrôle
détecte le fragment exposé entre frontière et arche. Le probe vérifie aussi les
trois cellules Amsterdam et les états fermé/ouvert du pont temporisé sur une
copie du réseau. La comparaison visuelle reste nécessaire. Il vérifie aussi
CARTE inchangée.

## Fonds pour retouches locales

Ajouter `--background-context 8` à la commande précédente, avec `--density 96`.
Chaque site produit alors `mouth-X-Y-background.png`, carré768×768 sans voie,
héros ni arche. Il provient du rectangle pixels256,16,768,768 du même viewport
1280×800 ; le centre et la densité ne changent pas. Toute taille demandée doit
tenir dans le viewport. L'option est facultative et n'autorise aucun écrasement.

| Bouche | Rectangle monde du fond à densité96 et contexte8 |
| --- | --- |
| 61,51 | 57.5,47.5,8,8 |
| 30,58 | 26.5,54.5,8,8 |
| 51,39 | 47.5,35.5,8,8 |
| 12,21 | 8.5,17.5,8,8 |
| 105,23 | 101.5,19.5,8,8 |
| 113,58 | 109.5,54.5,8,8 |

`world-passages.json` version2 conserve `captures[].background`. Chaque entrée
contient `world`, `pixels`, `source_crop`, `capture` et `capture_sha256`.
`inputs` reprend les champs des captures world-joins : scène et empreinte du
PNG, rectangle monde, crop source, intersection visible et destination soumise.
Le reçu authentifie aussi le manifeste sélectionné et CARTE par SHA256.

`portal_quads_world` donne les contours enregistrés des deux couches de l'arche.
`surface_port_world` et `opening_direction` verrouillent le raccord extérieur.
`underground_neighbor_world` désigne la cellule derrière l'entrée.
`edit_envelope_world` est l'union des bounds de l'arche et de cette cellule,
proposée comme étendue locale ; aucun masque n'est appliqué par le probe.

Pour le compositeur `world_join_compose`, la retouche approuvée fournit `image`
et son nouvel `png_sha256`. Reprendre `world`, `source_crop` et `pixels` comme
`size` depuis le fond. Le propriétaire choisit `edit_world` et le feather après
revue artistique. Le plan d'ouverture et les ports doivent garder leurs
coordonnées du reçu. Les pixels extérieurs au masque approuvé restent ceux
des huit peintures sélectionnées.

Aucune compilation ni exécution de ce probe par cet agent. Les captures préparées
ne prouvent pas un trajet joueur dans les six passages ni leur acceptation
artistique. Root doit examiner les raccords de neige et le masquage aux bouches
avant de reconstruire le paquet final.
