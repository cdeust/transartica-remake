# Composition hors ligne des raccords

`world_join_compose.cpp` utilise seulement libpng, json-c et OpenSSL Crypto.
Root possède CMake, compilation et exécution. Aucun ajout au rendu par frame,
aucune écriture dans les peintures sources, aucun téléchargement.

```sh
world_join_compose --artwork-dir ORIGINAL_WORLD_HD --patch-manifest PATCHES_JSON --output-dir DOSSIER_EXISTANT_VIDE
```

Le dossier candidat contient les mêmes PNG, aux mêmes dimensions, le manifeste
original avec seulement ses hashes PNG/RGBA réécrits, et `composition-receipt.json`.
Une région sans changement est copiée octet pour octet. Une région modifiée est
encodée en RGBA8 ; ses métadonnées PNG ne sont pas promises identiques. Tous ses
texels hors empreinte restent identiques après décodage. Un échec laisse un candidat
incomplet à examiner ; ne pas l'activer, utiliser ensuite un autre dossier vide.

Exemple de structure **à compléter avec les hashes et paramètres auteur** :

```json
{
  "schema": 1,
  "source_manifest_sha256": "SHA256_DU_MANIFESTE_ORIGINAL",
  "city_inventory": {
    "file": "world-inventory.json",
    "sha256": "SHA256_DE_L_INVENTAIRE"
  },
  "protected_world": [
    {"id": "silhouette-auteur", "world": [34, 48, 1, 1]}
  ],
  "patches": [
    {
      "id": "V4-2",
      "image": "V4-2-edited.png",
      "png_sha256": "SHA256_DU_PATCH",
      "size": [264, 462],
      "source_crop": [0, 0, 264, 462],
      "world": [36, 48, 8, 14],
      "edit_world": [36, 48, 8, 14],
      "feather": {
        "width": 16,
        "unit": "source_pixels",
        "edges": ["left", "right", "top", "bottom"],
        "exterior_world": "opaque"
      }
    }
  ]
}
```

Les nombres de cet exemple décrivent la capture V4-2 à33px/cell, **pas un masque
approuvé**. Root fournit `edit_world`, les bords et la largeur pour chaque retouche.
`world` enregistre le rectangle complet représenté par le crop ; `edit_world`,
contenu dans ce rectangle, limite les changements autorisés. Le contexte modifié
par imagegen en dehors de cette empreinte est ignoré. L'alpha du patch peut porter
un masque auteur plus précis ; un PNG opaque active toute l'empreinte rectangulaire.
Les ressources sont relatives au dossier du manifeste de patches ; aucun chemin
absolu ni `..` n'est accepté. L'inventaire peut être un lien lecture seule vers
`reference-private/artwork-world-20261011/world-inventory.json`.

`unit` vaut `source_pixels` (pixels du crop du patch, indépendants du PNG de
destination) ou `world` (cellules monde). Une largeur nulle désactive le feather.
`edges` choisit explicitement les bords de **edit_world** à traiter. Chaque bord
coïncidant avec une limite extérieure du monde est opaque même s'il est énuméré.
La distance minimale aux bords sélectionnés donne `t=clamp(distance/width,0,1)`,
puis l'alpha est multiplié par `t*t*(3-2*t)`. Source :
`game/scripts/world_artwork.gd::EDGE_SHADER`, ancien `FEATHER_PIXELS=16` ; la valeur
16 est ici un choix explicite du manifeste, aucun défaut n'est imposé. Les RGB
ne sont pas floutés. Ce masque raccorde le périmètre à son contexte intact ; il
ne répare aucune falaise ou géographie au centre du patch.

La projection inverse reprend le crop affine de `View::world` et des références
`world_join_render` : les coordonnées monde au centre de chaque texel de destination
déterminent les coordonnées du patch. Le filtre bilinéaire utilise les centres des
texels et limite ses quatre taps au crop sélectionné. La composition applique les
équations source-over de `SDL_BLENDMODE_BLEND`, avec arrondi au RGBA8 le plus proche
(voir `SDL_blendmode.h` installé). Il n'y a aucune promesse d'identité bit à bit
avec tous les backends SDL. Les patches sont composés dans l'ordre du tableau ;
les chevauchements sont donc un choix auteur visible, sans égalisation automatique.

Un patch peut ajouter `"sampling": "area-v1"` pour la réduction. Si au moins un
axe du texel destination couvre plus d'un texel source, le compositeur projette
le rectangle complet du texel dans le crop et intègre chaque pixel source selon
sa surface d'intersection. Le poids est cette intersection divisée par la surface
totale couverte. Les limites fractionnaires sont conservées ; aucun rayon ni
seuil visuel n'est choisi. Sans réduction, `area-v1` reprend le bilinéaire.
L'absence de `sampling`, ou `"sampling": "bilinear"`, garde le comportement
antérieur. Les valeurs inconnues sont refusées avant toute écriture.

Cette intégration suit la relation de surfaces de
[OpenCV INTER_AREA](https://docs.opencv.org/4.x/da/d54/group__imgproc__transform.html)
et les poids fractionnaires de `computeResizeAreaTab` dans
[sa source](https://github.com/opencv/opencv/blob/4.x/modules/imgproc/src/resize.cpp).
L'implémentation locale utilise directement les intersections rectangulaires ;
elle ne reprend pas les seuils d'optimisation du code OpenCV. Les couleurs sont
prémultipliées par l'alpha avant sommation et déprémultipliées ensuite selon
[W3C Compositing1, §5.1](https://www.w3.org/TR/compositing-1/#simplealphacompositing),
pour qu'un pixel transparent ne contribue pas de couleur. Les RGB restent dans
l'espace encodé des PNG, comme dans la composition existante. Le crop, les
coordonnées monde et les masques de protection ne changent pas.

Le cas observé `V6-2` réduit948×1659pixels sur8×14cellules vers environ33pixels
par cellule. Le patch contient déjà une matière neigeuse ponctuée ; la réduction
bilinéaire ne consulte que quatre pixels autour du centre et ne représente pas
l'ensemble du texel destination. Le mode par surface traite cet échantillonnage,
sans promettre de corriger les détails déjà peints. Recomposer depuis les
peintures originales avec les mêmes patches et comparer V6 au même zoom ; ne pas
filtrer une seconde fois les peintures déjà composées.

`world_join_compose_validation.py` contrôle les moyennes exactes d'un damier
réduit3×, un champ constant et l'identité. Il vérifie également une réduction
fractionnaire2,5×, les limites du crop et l'exclusion des RGB transparents.

Le manifeste source authentifie les peintures PNG, leurs dimensions/crops et leur
RGBA décodé lorsque ce hash existe. L'inventaire est authentifié et doit déclarer
le même `source_map_sha256`. Ses `features` comportant des `city_records` définissent
les footprints de villes protégés. Par défaut, tous les texels dont la surface
intersecte ces bounds sont conservés, même dans un patch. `protected_world` ajoute
des silhouettes protégées plus larges et reste prioritaire sur toute réparation
de ville. Le programme ne devine pas ces silhouettes.
Les éventuels `city_records_without_town_footprint` sont repris dans le reçu sous
`city_records_without_source_bounds` : leurs ancrages ne donnent pas une silhouette
certifiée. Fournir des bounds auteur dans `protected_world` si un patch les approche.

Une réparation de ville autorisée par le propriétaire se déclare dans le patch
concerné, avec une identité vérifiée contre l'inventaire authentifié :

```json
"city_repairs": [
  {
    "feature_index": 23,
    "city_source_index": 35,
    "city_name": "TURIN",
    "anchor": [30, 37],
    "reason": "Repair the painted city discontinuity across H1 at y37."
  }
]
```

Ces valeurs désignent Turin dans `join-city-inventory.json`, footprint
`[28,36,3,2]`. Le mandat du21octobre2026 autorise sa correction graphique.
L'index de feature, l'index source, le nom et l'ancrage doivent tous correspondre ;
la feature doit intersecter `edit_world`. Les identités absentes, incohérentes ou
dupliquées font échouer la composition avant toute écriture. Le motif doit être
non vide. L'exception est locale au patch : un patch ultérieur sans cette entrée
conserve les pixels de la ville tels qu'il les reçoit. Une protection explicite
dans `protected_world`, ou une autre ville au même emplacement, reste bloquante.
Ni l'inventaire ni les coordonnées du manifeste monde ne sont modifiés.

Le patch existant `art-generated-horizontal/H1-3.png` fournit une ville continue
dans son rectangle monde `[24,33,16,8]`. Les deux peintures sélectionnées à
l'origine coupent la ville aux limites de leurs canevas. Il s'agit donc d'une
réparation graphique issue de ce patch auteur, pas de pixels originaux retrouvés.
Le manifeste candidat conserve le footprint et l'ancrage ; sa marge de fondu
reprend les16/33cellules du patch H1 existant, à l'extérieur du footprint.

Le reçu conserve la spécification auteur complète, les hashes des entrées et
sorties, les features de villes utilisées et les comptes de texels changés,
inchangés hors empreinte et inchangés dans les protections. Chaque PNG écrit est
redécodé et comparé au RGBA validé avant émission du reçu final. Les drapeaux
`artistic_validation` et `native_render_validation` restent faux : ce contrôle
prouve la conservation des pixels, pas la qualité artistique du raccord.

`authorized_city_repairs` expose les identités résolues et le patch qui les
autorise. `repair_eligible_texels` compte les texels protégés dont une réparation
autorisée peut changer la valeur ; `repaired_city_texels` compte ceux dont la
valeur finale diffère de la source. `unchanged_protected_texels` ne compte que
les protections restées obligatoires. `protected_bounds_exact` reste vrai
uniquement si aucun texel de ville réparé n'a changé ;
`unapproved_protected_bounds_exact` garantit la conservation des autres protections.
Un manifeste sans `city_repairs` conserve le comportement précédent.

Contrôles ciblés avant activation : vérifier que Turin change dans les deux
régions00/04, que tous les texels hors masque et toutes les autres villes restent
exacts, puis comparer le raccord y37 au zoom du jeu. Vérifier aussi le refus des
identités incorrectes et doublons, la priorité de `protected_world` et l'absence
d'autorisation héritée par un second patch. Les contrôles de pixels ne valident
pas l'apparence du bâtiment.

Pour revoir avant/après, utiliser `world_join_render --artwork-dir ORIGINAL_WORLD_HD`
puis `--artwork-dir DOSSIER_CANDIDAT`, avec deux dossiers de sortie distincts et
les mêmes densité/backend/`--segments`. Le manifeste et les images proviennent
du même dossier sélectionné dans View, `world_join_render` et `render_resources`.
