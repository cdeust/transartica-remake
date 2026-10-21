# Référence C++ des raccords

`world_join_render.cpp` se lie aux mêmes dépendances que `render_resources`
(`transartica_view`, SDL2, json-c et OpenSSL transitifs). Root ajoute la cible et
possède compilation/exécution ; aucun programme n'a été lancé pour cette remise.

```sh
world_join_render --game-dir CHEMIN_GAME --font CHEMIN_NOTO --output-dir DOSSIER_EXISTANT --density 33 --renderer software
```

`--artwork-dir DOSSIER_CANDIDAT` sélectionne **son** `manifest.json` et ses PNG.
Sans cet argument, le dossier reste `GAME/assets/travel/artwork/world-hd`.
Comparer originaux/candidats dans deux dossiers de captures distincts, avec les
mêmes arguments de densité, backend et segmentation. Les rectangles de capture
restent dérivés du manifeste sélectionné ; son hash et son dossier sont consignés.
Voir `world_join_compose.md` pour produire ces huit PNG hors ligne sans ajouter
de surimpression au runtime.

La densité est obligatoirement choisie par l'opérateur. `33` dans cet exemple
est l'arrondi supérieur du minimum actuel des densités source (32,5945946px/cell),
pas une constante du programme. Le reçu indique aussi le maximum source
(33,0555556px/cell). Choisir une densité donnant des dimensions entières pour
toutes les fenêtres ; le programme refuse tout arrondi ou étirement implicite.
`--renderer accelerated` permet le backend natif ; aucun fallback silencieux.

Les adjacences et coins sont calculés depuis les rectangles du manifeste. Sur
le manifeste actif, cela produit V1..V6, H1..H4 et corner-1..3 : treize PNG,
dont **V4.png (04/05) en premier**. Les segments gardent leur longueur exacte,
avec quatre cellules de part et d'autre ; les intersections couvrent8×8 cellules.

Ajouter `--segments` produit des fenêtres dont le grand côté ne dépasse pas
seize cellules, avec un chevauchement déclaré de trois cellules, choix auteur
pour préparer les entrées imagegen. La largeur reste8 cellules et les coins
restent8×8. La couverture conserve exactement les extrémités des segments source.
Le nombre minimal de fenêtres est `max(1,ceil((L-3)/(16-3)))` ; leur longueur
totale vaut `L+3*(n-1)`. Les cellules supplémentaires sont réparties sur les
dernières fenêtres pour conserver des rectangles monde et pixels entiers.

Pour le manifeste actuel, ce mode produit trente fenêtres de segment et trois
coins. **V4-1.png, V4-2.png et V4-3.png** arrivent en premier et couvrent
respectivement `(36,37,8,14)`, `(36,48,8,14)` et `(36,59,8,14)` : à33px/cell,
264×462 pixels chacune. Les segments verticaux supérieurs ont les longueurs
14/14/15 et les horizontaux15/15/16. Les treize captures longues restent le mode
par défaut. Utiliser un autre dossier existant pour conserver les deux modes.

Le dessin reprend l'arithmétique de `View::screen` puis les mêmes `SDL_FRect`,
crops entiers, `SDL_RenderCopyF`, filtrage linéaire Canvas et clipping. Il soumet
chaque peinture entière, au lieu de prérecadrer/rééchantillonner sa bordure.
Les captures ne contiennent ni rails vivants, labels, bandeau ni retouche ; les
couloirs déjà peints dans les PNG restent visibles. PNG sources et CARTE sont
authentifiés avant capture. Les destinations déjà existantes sont refusées.

`world-joins.json` conserve le hash du manifeste/CARTE, les rectangles monde,
densités, dimensions, backend effectif et hashes des captures. Pour chaque portion
visible, il donne le hash du PNG source, son crop entier, le sous-rectangle source
fractionnaire exact et la destination flottante réellement soumise à SDL.
Ces données permettent de réimporter une retouche dans son repère original.
En mode segments, le reçu ajoute la frontière parente complète, l'indice et le
nombre de fenêtres, ainsi que le chevauchement et sa provenance auteur. Ce
chevauchement fournit du contexte commun ; il ne prétend pas qu'un recouvrement
existe dans les PNG sources et n'ajoute aucun pixel à leur géographie.
Une capture terminée n'est ni une réparation du raccord ni une validation artistique.
