# Rails cassés existants : relevé pixels, 19 octobre 2026

Lecture et mesure seulement ; aucune modification de code de production, aucun
PNG écrit, aucun moteur/build/test/benchmark lancé. Les mesures proviennent d'un
décodage RGBA8 sans conversion de couleur du PNG avec Python standard (`zlib`,
filtres PNG Sub/Up/Average/Paeth). Pillow n'était pas installé ; aucune installation
n'a été faite. Les processus de mesure sont terminés.

## Identité et intention de l'asset

`game/assets/travel/rail-track-kit.png`, 1447×1087, PNG8 RGBA non entrelacé.

- PNG SHA256 : `6905fe2c3a7c6a4788958bf47e85b6d9f43c8352b3c8edbc5c6d1ad3d660ae26`.
- RGBA brut SHA256 : `3443f46e66c618099defee7d3f5095c650df9ac72b0e75205318ee257a2b7db2`.

L'identité PNG concorde au manifeste d'origine
`output/imagegen/visuals-20260927/manifest.json`. Le prompt conservé
`prompts/rail-track-kit.txt` décrit explicitement rangée3/colonne3 : voie E-W
avec rails centraux manquants et traverses éparses ; colonne4 : voie réparée.
L'inspection de l'image confirme ces deux dessins. Le prompt n'est pas une
registration numérique : ses demandes de cellules égales ne remplacent pas la
mesure des pixels effectivement produits.

## Emprise et sections observées

Les bornes ci-dessous sont inclusives à gauche/haut, exclusives à droite/bas.
Composantes connexes à quatre voisins, aucun seuillage RGB :

| Support | Nombre de pixels connexes | Rectangle |
| --- | ---: | --- |
| Composante principale, alpha>0 |58539| `(724,774,321,218)` |
| Cœur alpha≥128 |51031| `(736,782,305,203)` |
| Variante réparée principale alpha>0 |60319| `(1088,772,318,224)` |

Le seuil128 est le critère alpha déjà employé par `Canvas::alpha_bounds` ; le
support alpha>0 est fourni séparément pour ne pas effacer les bords de l'auteur.
Les alphas du corps cassé sont surtout252/253. Chercher seulement alpha255 manque
donc l'essentiel de la vignette. Les petits fragments détachés ne permettent pas
de déduire seuls une cellule de gameplay ; le rectangle principal est un crop
candidat, pas une validation artistique de tout pixel détaché au-delà.

Sections verticales sur les glints supérieurs/inférieurs inspectés. Le maximum
de `(R+G+B)*alpha` est relevé dans les fenêtres y847..860 et y898..911 : c'est un
relevé d'intensité prémultipliée, sans seuil de couleur ni classement automatique
de la neige comme acier.

| x | Glint haut y / RGBA | Glint bas y / RGBA | Séparation |
| ---: | --- | --- | ---: |
|736|853 / `(227,226,233,254)`|904 / `(212,216,231,254)`|51|
|750|853 / `(255,251,216,251)`|904 / `(236,237,243,250)`|51|
|960|853 / `(255,255,230,253)`|904 / `(220,216,215,252)`|51|
|1035|853 / `(249,252,255,250)`|903 / `(206,216,234,251)`|50|
|1040|853 / `(171,174,187,175)`|903 / `(157,161,176,183)`|50|

Les colonnes consécutives où ces deux pics sont présents avec alpha≥128 sont
`736..843` et `933..1040` (intervalles inclusifs). L'intervalle intermédiaire
contient la cassure et les traverses éparses du dessin ; ce relevé n'autorise pas
à les remplacer par une simple ligne coupée. La gauge60 du strip droit en haut
à gauche n'est pas une calibration de cette vignette. Le décalage d'un pixel du
glint inférieur à droite doit rester déclaré : un pic lumineux n'est pas une
preuve d'un rail géométriquement parfait sur toute sa longueur.

## Proposition minimale, avant code

Limiter d'abord l'usage aux seuls droits ordinaires signés `-2,-3,-4,-5` : deux
ports opposés, avec les chords CARTE existants. Les positifs, courbes, croisements,
aiguillages, souterrains, bouches et codes spéciaux restent dans leurs chemins
actuels. Les cas complexes non traités seront nommés, pas annoncés comme terminés.

Le crop principal entier conserve les deux moignons complets et la cassure
centrale physique. Les centres de sections extérieures mesurées sont
`P0=(736,878.5)` et `P1=(1040,878)` ; dans ce crop : `(12,104.5)` et `(316,104)`.
Ils peuvent être enregistrés exactement sur les deux ports autoritaires par la
même transformation affine de type `TerrainObstacles.registration`. La direction
transversale doit reprendre `RailArt.transverse`, pour garder la projection au
sol des rails ordinaires, pas une rotation de tuile carrée sans compression.

Une seule gauge de calibration ne peut pas rendre simultanément les deux
séparations lumineuses51 et50 exactement égales. Choisir explicitement une
section de référence51, ou une calibration symétrique50.5 (moyenne des deux
sections extérieures), est une décision de registration à déclarer et vérifier
sur le rendu. Ne pas cacher cette irrégularité sous une affirmation de gauge
pixel parfaite. Les ports et le gabarit logique restent ceux du modèle ; cette
limite concerne le dessin source, pas une modification de CARTE.

Réutiliser directement le même PNG et son cache Canvas actuel avec un crop UV :
zéro nouvelle image, zéro téléchargement, zéro texture dérivée nécessaire. Les
meshes restent bornés par code signé et génération de zoom. Remplacer le dessin
intact de ces seuls codes plutôt que le superposer ; aucune traverse intacte
ne doit réapparaître sous le centre cassé. Vérifier les sections de raccord
voisines, le sens inversé et les quatre orientations dans un probe préparé avant
activation artistique. Aucun de ces rendus n'est encore exécuté pour ce relevé.

## Portée des destructions

Implémentation source autorisée ensuite par root : calibration symétrique50.5,
uniquement droits `-2/-3/-4/-5`, sans asset nouveau. Le PNG du kit est authentifié
une fois au premier usage avant de construire les crops mesurés. Les tests de
géométrie ajoutés ne sont pas exécutés par cet agent ; compilation, probe rendu
et acceptation artistique restent à root. Le présent relevé ne rapporte pas
une validation native des dessins cassés.

Source exacte : `rail_network.gd:283–286` et `core/rail_network.cpp:167–169`.
Les rails1..58, sauf34..37, peuvent prendre leur négatif. Les ponts construits
passent en revanche `63→67`, `64→69`, `-117→114`, `-121→-116` : ces variantes
existent déjà dans WorldPassages. Il serait faux de créer ou traiter `-63/-64`
comme résultat de dynamite de ces ponts.
