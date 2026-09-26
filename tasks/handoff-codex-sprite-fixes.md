# Reprise Codex, 26 septembre 2026

Le handoff Claude dans tasks/handoff-sprites.md est lu. Codex corrige W (canon et verrière) et NW (verrière) via imagegen, versions distinctes v2. Les quatre sources initiales et leurs prompts sont maintenant sous output/imagegen/train-*-raw.png et train-*-prompt.txt.

Le propriétaire a précisé que le train évolue avec les achats de wagons et armements. La composition de départ ne doit pas être figée dans un unique sprite. Architecture attendue : sprites par véhicule et cap, armement séparé, assemblage depuis la composition actuelle, commun au voyage et au combat. Les images actuelles restent des références de perspective.

Codex garde la propriété des images et de travel_world.gd ; Claude conserve sprite_pipeline.py et pixel_field.gd. Aucun changement de ces modules Claude dans cette reprise. La version de travail a été lancée pour le test propriétaire, avec les anciens assets intégrés.

Validation v2 : en attente des images ; réutiliser le pipeline existant et contrôler visuellement le canon W et les verrières W/NW.

## Résultat intégré

Le défaut signalé par les captures du propriétaire imposait de changer le rendu complet. train_renderer.gd dessine maintenant chaque véhicule indépendamment, depuis game/assets/travel/vehicles-*.png et vehicles.json (régions et ancrages). Les images originales du convoi restent des références. travel_world.gd choisit la perspective par véhicule et interpole la distance le long du chemin. train_journey.gd + train_path.gd conservent les segments réellement parcourus dans le snapshot v3. train_consist.gd porte la liste de véhicules et la sauvegarde principale v6 la conserve.

W complet corrigé : output/imagegen/train-west-v3.png (canon et verrière). NW complet : train-northwest-v2.png (arrière plat ajouté à la verrière, calibration artistique restante). Le pipeline Claude passe les cinq caps dans .cache/sprites-corrected ; SE et NW ont encore les avertissements d’épaisseur déjà documentés. Les cinq atlas sont créés par le tool imagegen intégré, prompts exacts dans output/imagegen/vehicles-*-prompt.txt ; la variante southeast-v2 supprime le tender parasite de la cellule locomotive.

Toutes les 9 suites game/test.sh passent sur le rendu final. Captures natives dans tasks/validation/modular-train-*.png. La voie sous les wagons est découverte sans déplacer le marqueur de locomotive. Le recentrage inclut les sprites du convoi entier et déclenche au bord du viewport ; la marge intérieure est la cible, pour éviter de suivre à chaque image après un ajustement de zoom.

À reprendre : l’arme est encore dessinée dans le wagon blindé. Produire châssis neutre et tourelles séparées avant les achats/équipements ; relier le même consist au combat lorsqu’il sera porté. Les points de contact sont des ancrages artistiques, pas des mesures physiques historiques. Ne pas présenter les tests de géométrie comme une validation de toute la perspective artistique.

## Sauvegarde ancienne à chemin ambigu

Le test natif du save propriétaire v2 (20,58), cap6, phase2, ticks7 ne pouvait pas reconstruire l’entrée de l’aiguillage. Aucun wagon ne s’affichait. La restauration refuse maintenant une composition dont la queue ne peut être située sur un chemin connu, avant de changer la session ; fichier de sauvegarde conservé. Copie supplémentaire : .cache/view-before-modular-renderer.json. La fenêtre de revue utilise donc le trajet initial en pause. Le message dans le jeu explique le refus. Ne pas affirmer que l’ancien trajet a été restauré.
