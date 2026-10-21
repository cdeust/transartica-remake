# Rails : contrôles préparés

Root compile et exécute sous sa garde. Aucun lancement par l'agent auteur.

`rail_geometry_tests.cpp` se lie à `transartica_core` avec les includes SDL2 de
`world_visual_math.hpp`. Il confronte les16états d'aiguillage au `rail_turn` du
modèle, vérifie chaque port, le sens des normales, la gauge projetée, la continuité
des répétitions de ballast et le plancher réel d'un pixel aux zooms source.
Les codes67/69 restent des coupures ; seules les réparations63/64 ont leurs rails.

`rail_render.cpp` se lie à `transartica_view`, mêmes dépendances que
`render_resources`. Exemple opérateur, à lancer dans un dossier de sortie enregistré :

```sh
rail_render --game-dir GAME --artwork-dir WORLD_HD --font FONT --output-dir EXISTING_DIR --renderer software --zoom 0.3
```

`--zoom` est obligatoire (.001..2 selon TravelWorld), ainsi que le backend explicite,
sans fallback. Répéter avec `.1` dans un autre dossier pour voir le mode lointain.
Les caméras Serov/Amsterdam sont tirées des villes décodées ; cette préparation
ne déplace aucun convoi gagné et ne simule aucun cycle. Le probe produit deux
captures1280×800 via le vrai `View::world`, et un reçu indiquant zoom/backend,
ancrages et code actuel source25,24. Il vérifie la conservation de CARTE.

Avant ces captures, il vérifie195×200 pour la texture dérivée neutre, la réutilisation
sans nouveau décodage/upload au second accès, puis l'éviction après une frame
inutilisée. Les staging buffers CPU sont libérés. La dérivation copie exactement
`RailArt.neutral_ballast` depuis l'unique rail-track-kit existant ; aucun PNG généré
n'est stocké et aucun cache supplémentaire ne persiste hors du cache Canvas.

La géométrie conserve les chords centre/ports de CARTE, sans arrondir le chemin.
Le lit est dessiné sous les traverses, la gauge lointaine garde la compression au
sol. La branche sélectionnée garde un trait d'au moins **deux pixels écran**,
plancher déjà présent dans `MapRailDrawing::_draw_switch_state`; sa palette reste
le brassage HANDLE du mécanisme physique, sans disque UI. Le levier garde son
plancher distinct d'un pixel écran. Cette adaptation de lisibilité ne prétend pas
reproduire exactement le dernier `RailMaterial.draw_switch` aux petits zooms.
Le cache de meshes ne conserve qu'une génération de zoom. Le stipple souterrain
reste inchangé ; portails, ponts et couronnes sont traités séparément.

Ces contrôles ne certifient ni l'intégration artistique, ni un clic réel sur un
aiguillage, ni une traversée de tunnel ; root valide ces interactions dans l'app.

Les droits ordinaires détruits `-2/-3/-4/-5` remplacent maintenant le mesh intact
par la vignette cassée existante de `rail-track-kit.png`, crop `(724,774,321,218)`.
Les deux sections extérieures mesurées sont enregistrées exactement sur les
ports CARTE, avec normale au sol et calibration moyenne50.5 des deux gauges
mesurées51/50, choix auteur explicite. Les deux moignons et la cassure centrale
proviennent des pixels existants ; aucun rail/traverse intact n'est superposé,
aucun PNG/texture nouveau n'est créé. Le cache signé/zoom existant reste borné.
Voir `tasks/standalone-cpp-20261018/rail-broken-strip-measurements.md` pour les
hashes, relevés et la variation d'un pixel du dessin source.

Limite explicite : les courbes, croisements et aiguillages négatifs ainsi que les
états détruits des souterrains/bouches ne reçoivent pas cette recette droite.
Le modèle bloque/répare ces cases, mais leur état cassé n'est pas encore une
représentation graphique distincte vérifiée. Aucun trajet ni code n'est remplacé
pour les faire entrer artificiellement dans le cas droit.
Les ponts construits suivent d'autres mutations : `63→67`, `64→69`, `-117→114`
et `-121→-116` (`rail_network.gd:283–286`). Ces états d'ouvrage sont déjà pris en
charge par WorldPassages ; ils ne deviennent pas `-63/-64`.
