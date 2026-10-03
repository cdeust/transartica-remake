# Horloge moderne et compteur de cycles

Le propriétaire demande une horloge moderne aussi lisible que celle des travaux,
avec les cycles au centre. La capture native7190 montre le cadran romain ECS et
le chronomètre316:06. La texture moderne est conservée sans régénération.

## Registration et dessin

Sur `game/assets/interface/original-panel-v2.png` (1983×793), le centre relevé
sur les plots cardinaux est `(160,410)`. La zone intérieure retenue après examen
de l'image est `(60,320,200,180)`, à l'intérieur des plots et de la bordure.
`original_panel.gd` transforme ces coordonnées par sa première tranche existante
`(0,184,992,402)` vers `(0,149,160,51)`, puis par le cadre d'écran. Le pivot ne
reprend plus le centre de la zone cliquable ECS `(24,180)`.

Les douze chiffres romains reprennent les positions horaires visibles sur7190.
Leur taille est ajustée aux métriques réelles de la police : aucun rectangle ne
chevauche un autre, ni ne sort de l'ellipse intérieure. Leur position radiale
résout l'équation géométrique `|direction*t+corner|²≤1` pour les quatre coins du
rectangle normalisés par les rayons du cadran. Il n'y a pas de seuil empirique
ou de boucle de recherche de position. L'inset d'un pixel d'écran reprend celui
des autres fenêtres du panneau.

Les aiguilles utilisent les heures/minutes de `GameCalendar`, sans modifier la
simulation. Leurs rayons suivent la zone intérieure restante sous les chiffres ;
le rapport6/9 entre aiguille des heures et des minutes reprend le dessin
précédent. L'encre sombre, le reflet clair et le moyeu utilisent la palette déjà
présente sur le panneau.

## Valeur centrale

Le nombre affiché est directement `app.engine.cycles`. Ce compteur est déjà
nommé CYCLE dans `engine_panel.gd:209`. `engine_room_controls.gd:110` le multiplie
par trois minutes pour afficher l'ancien chronomètre HH:MM :6322 cycles donnent
316:06. La nouvelle valeur entière est donc un compteur de simulation, pas un
temps mural ou une progression inventée. Le rafraîchissement surveille aussi ce
champ pendant les arrêts.

La plaque centrale est inscrite dans l'ellipse de la petite aiguille : son coin
normalisé vaut `(1/√2,1/√2)`. Elle laisse l'extrémité de chaque aiguille visible,
reste à l'intérieur du cadran et ne couvre pas les chiffres. À taille moderne,
elle porte CYCLES et le nombre entier. Au cadre minimal320×200, la légende est
omise lorsque ses métriques ne tiennent pas ; la valeur demeure affichée.

## Preuve et réception

`game/tests/test_clock_quality.gd` reproduit le décalage historique avec
`--legacy-layout` : résultat rouge. Le dessin corrigé est vert. Les tests
contrôlent le pivot, les douze chiffres, leur non-chevauchement, leurs bornes,
les angles du calendrier, les compteurs0/6322/2147483647, ainsi que les aiguilles
visibles au-delà de la plaque dans48 directions par cadre moderne.
Cadres contrôlés :320×200,600×1000,1280×800,1440×900.
À1440×900, les chiffres romains utilisent une police13px.

Les tests existants du panneau, du défilement, du modal travaux et de l'art ECS
sont relancés. Les journaux restent dans `reference-private/validation/`.
La branche `reference_pixels` affiche toujours les ressources ECS privées pour
le diagnostic ; ce travail ne la substitue pas au panneau moderne.

La réception artistique exige encore la capture native par le pilote principal :
chiffres, aiguilles, valeur exacte des cycles et lisibilité pendant les travaux.
Les calculs de bornes ne constituent pas une acceptation visuelle.
