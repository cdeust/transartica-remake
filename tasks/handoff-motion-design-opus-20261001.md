# Handoff motion design pour Opus, 1 octobre 2026

Le propriétaire signale des bugs dans les animations et demande l'aide d'Opus pour le motion design. L'acceptation artistique reste ouverte. Les changements de production sont figés après les vérifications en cours. Aucun push de cette itération.

## Intention du propriétaire

« Ma volonte d'avoir une DA beaucoup plus actuelle c'etait justement pour redonner un interet au jeu, d'avoir aussi des scenes de combats plus realistes, et plus nerveuses. »

La flamme de la fusée fonctionne selon le propriétaire. La fumée doit s'accumuler contre le plateau du wagon près de la fusée, puis se propager comme pendant une ignition réelle. Les effets Gatling restent jugés pauvres. Noita sert de référence pour la richesse des effets vivants. Les contraintes techniques de l'Amiga ne constituent pas une limite artistique.

## État exact du travail

- Checkout : `.worktrees/living-effects`, branche `feat/living-effects`.
- Commit local de base : `ca1ece1b896a724d6c652e21020cb300924a5418`.
- Publication précédente : `79c80b28a5a7a9bf227269dcceac4b015b11e182` sur main.
- Les modifications suivantes sont non commitées. Préserver le diff et les fichiers nouveaux.
- `world_recovery` possède les effets communs et le combat ; `ambience_validation` possède l'ignition. Ils terminent leurs preuves et arrêtent leurs processus.

La locomotive correcte a été déplacée sans modification des pixels vers `game/assets/combat/wagon-01.png`. `tactical_wagon_art.gd` charge ce chemin canonique. L'ancien fichier combat `locomotive-hero.png` est supprimé ; celui du voyage reste présent. Le fichier public sur main n'a pas encore reçu cette correction.

Root a vérifié l'égalité exacte des octets avec le hero du commit ca1ece1,
SHA256 `daddf434129246da326c6a91650d7d5e02e402acc33078e6c72722d709a07788`.
Après le déplacement, les fixtures headless `test_tactical_art_cache.gd` et
`test_rocket_ignition.gd` sortent avec PASS et code 0. Le système macOS signale
une erreur de lecture des certificats système ; aucun échec GDScript dans ces
deux exécutions. Une importation headless précédente a planté à la fermeture
avec `Pure virtual function called`; ces fixtures ne valident pas l'export.
`git diff --check` est propre sur le diff suivi.

Le worker combat confirme l'arrêt de ses processus. La vérification système
finale par root ne trouve aucun processus Godot ou ffmpeg en cours.
Le worker ignition confirme également l'arrêt de ses tests. La vidéo complète,
le coût du shader et les nouveaux contrôles de cycle save/restart du shader
restent ouverts ; les preuves de la précédente itération ne les remplacent pas.

## Modules et preuves disponibles

Combat : `living_effects.gd`, `living_particles.gd`, `blast_pixel_volume.gd`, `tactical_weapon_motion.gd`, `tactical_scene.gd`.

- Avant : `validation/blast-detail-before-20261001.gif`.
- Après : `validation/blast-detail-after-20261001.mp4` et `.gif`.
- Empreintes des fichiers et patch : `validation/blast-detail-code-manifest-20261001.json`.
- État source avant/après : `validation/blast-detail-before-model-20261001.json` et `validation/blast-detail-final-model-20261001.json`.

Les états source avant/après sont identiques, SHA256 `bae607f4fde999441336a2bdaff64e5834e4e035820e3ceb8cf8e681fb986106`. Cinq fixtures affectées passent. Les checkers source/craft du périmètre combat sont sans findings. Le modèle reçoit `state.advance(delta)` une seule fois ; les effets visuels avancent entre les ticks source. Le déplacement des acteurs et du train reste à 12,5 Hz.

Coût CPU mesuré par le worker pour quatre champs denses, 128 émetteurs et 2048 particules : draw médiane 4,844 ms, p95 6,955 ms, maximum 7,225 ms ; update médiane 0,704 ms, p95 1,687 ms, maximum 1,769 ms. Le temps GPU est exclu. Voir `validation/blast-detail-benchmark-20261001.json` et le journal final.

Ignition : `rocket_living_effects.gd`, `rocket_ignition.gd`, `rocket_ignition_canvas.gd`, `launcher_scene.gd`, `shaders/rocket_ignition.gdshader`.

Les captures `validation/rocket-ignition-{before,after}-step{00,03,08,15,18,23}.png` montrent plusieurs instants. Le worker rapporte 48 assertions natives, dont la pause réelle, et 35 callbacks source identiques. La vidéo complète n'a pas été produite : l'enregistrement du scratch imbriqué a échoué et l'auto-review a rejeté la tentative suivante dans le cache principal comme risque pour le workspace protégé d'une autre session. Aucun contournement. Ne pas établir l'acceptation artistique à partir de ces assertions. Voir le rapport final ignition quand disponible pour les mesures et la restauration.

## Points à examiner en animation

- La Gatling procédurale ressemble à une tige verticale exposée et apparaît seulement pendant l'activité du rig.
- Dans la capture conservée `validation/blast-detail-misalignment-0030-20261001.png`, le montage dépasse de la tourelle alors que le flash tombe sur le corps du wagon. Le worker confirme un désaccord des ancrages : base du rig à `roof - direction * recoil`, extrémité à `base + direction * 8`, flash à `roof + direction * 8` sans recul. Le flash reste également à son point monde d'émission. Les vecteurs pointent tous deux vers le bas pour side0 ; le montage visuel reste incohérent.
- Les pieds des acteurs flottent au-dessus du toit des wagons dans cette même capture, confirmé par le worker. Les acteurs utilisent `_roof_point` aux hauteurs source 38/171 ; les sprites utilisent leurs hauteurs découpées. Réconcilier les ancrages sans modifier les règles source.
- Les débris utilisent encore l'ancienne grille de position d'un pixel logique et peuvent sauter entre positions.
- Le déplacement de la tuyère suit encore les étapes BERTA. Le shader continu ne suffit pas à rendre ce mouvement continu.
- La transition vers la carte plein écran vient du comportement source. Examiner la continuité visuelle sans changer silencieusement les règles de campagne.

Le propriétaire n'a pas encore identifié les bugs par frame. Ces observations ne remplacent pas son retour sur l'animation.

## Asset Gatling candidat

`game/assets/weapons/gatling.png` est une génération originale transparente, non intégrée. Dimensions réelles : 2075 × 758. Les cellules ne sont pas quatre rectangles réguliers et les poses restent très similaires. Ce fichier ne constitue pas une animation de rotation validée. Provenance dans `output/imagegen/gatling-20261001/manifest.json`.

## Références et lancement

Contrat de travail et références : `rocket-ignition-quality-20261001.md`. Références primaires : [Noita press](https://noitagame.com/press/index.html), [NASA Artemis I high-speed ignition](https://images.nasa.gov/details/KSC-20221116-MH-GEB01-High_Speed_Film_Artemis_I_ML_Tower_WON-3327395). Les téléchargements vidéo externes incomplets ne constituent pas une inspection de ces vidéos.

Depuis ce checkout : `.toolchain/Godot.app/Contents/MacOS/Godot --path game`. Les fixtures `review_blast_detail.gd` et `review_rocket_ignition.gd` permettent les captures reproductibles ; lire leurs arguments avant exécution.

Le binaire `builds/macos/Transartica.app` correspond au commit de base ca1ece1, avant les modifications présentes. Il ne prouve pas le fonctionnement de cette nouvelle itération. L'export Windows précédent n'a pas été exécuté sur Windows.

Reprendre le motion design depuis les animations natives, corriger les ancrages et vérifier les mêmes états source après chaque modification.
