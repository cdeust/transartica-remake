# Redesign : 19 wagons au gabarit des six véhicules initiaux

Le propriétaire a demandé de refaire les dessins après avoir constaté des largeurs de 95 à 139 texels dans l'atlas. Les 19 nouveaux fichiers ont été redessinés avec l'outil intégré image_gen, en utilisant le type 3 comme châssis fixe et chaque ancien dessin comme référence d'équipement. Aucun étirement, redimensionnement individuel ou retouche Python des PNG n'a été effectué.

## Remise à Opus

`catalogue.json` couvre les 25 identifiants. Les 19 fichiers redessinés sont dans ce dossier; les six véhicules initiaux sont référencés dans le dossier précédent, sans duplication. Les chemins `file` sont relatifs au catalogue. `prompts.json` couvre également les 25 types et conserve les prompts exacts des 19 éditions.

Pour préparer l'atlas, utiliser ce catalogue comme `SOURCE_DIR` dans `tools/build_overhead_atlas.py`. Conserver sa réduction commune 1/3 et son détourage alpha; ne pas appliquer une normalisation différente par wagon. Les noms de fichiers, identifiants et slugs restent compatibles. Recalculer les régions et ancrages depuis les nouvelles images. Le générateur et l'atlas du jeu ne sont pas modifiés dans cette livraison artistique.

`index.html` compare référence, ancien dessin et nouveau dessin à une échelle commune. Les liens ouvrent les PNG détaillés 1024 × 1536.

## Mesures vérifiées

`measurements.json` contient les SHA-256, dimensions solides avant/après, largeur médiane de la moitié centrale et alpha des coins. Reproduction : `python tools/audit_wagon_redesign.py` depuis le dépôt, avec Pillow installé. Le script lit les PNG sans les modifier.

- 19 types redessinés : largeur solide 401–407 pixels source.
- Six références conservées : largeur solide 401–417 pixels source.
- Les longueurs des 19 redraws restent dans la plage mesurée des six références.
- Largeur médiane de la partie centrale des redraws : 358–370 pixels, contre 358 pour le châssis de référence. La prison conserve ses passerelles latérales.
- Toutes les images sont lisibles en RGBA, 1024 × 1536. Les six références restent inchangées.

La convention alpha >= 128 est celle du générateur d'atlas existant. Les valeurs source divisées par trois donnent une estimation; l'échantillonnage de l'atlas peut déplacer une limite d'un texel.

## Limites conservées

Les sources gardent des pixels faiblement opaques hors silhouette. Trois images ont un coin à alpha 1 : observatoire, foreuse et serre. Le détourage déjà effectué par le générateur d'atlas doit rester actif. Les dessins ne sont pas certifiés comme détourages bruts sans halo.

Cette livraison corrige le gabarit de la famille de wagons. Elle ne constitue pas une validation du rendu en jeu. Les détails de volume hérités des références restent visibles sur certains équipements.

Pour les combats rapprochés, les sources détaillées sont conservées. Matériaux physiques, masque solide de simulation, intérieurs et pièces mobiles séparées restent à produire. Un toit redessiné ne prouve pas une destruction par pixels.
