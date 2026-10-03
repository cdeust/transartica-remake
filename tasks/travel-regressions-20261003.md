# Voyage et gares : corrections du 3 octobre 2026

Les défauts signalés sont corrigés localement. L’agent a exécuté les commandes souris/clavier du jeu dans Godot natif et examiné les images produites. Les 85 sites recensés passent leurs 170 approches préparées avant/arrière. Le jeu entier n’est pas déclaré terminé ou stable sur cette seule preuve.

## Défauts corrigés

| Déclencheur | Cause | Comportement obtenu |
|---|---|---|
| Clic sur un aiguillage proche d’une ville | La zone de sélection de ville absorbait le clic | L’aiguillage répond au clic sur sa voie |
| Inversions puis modification d’aiguillage | Le rendu conservait une ancienne branche future | La géométrie affichée suit le choix TIME courant, en conservant la voie déjà occupée |
| Longue marche arrière | L’historique initial fini bloquait le curseur de rendu à zéro | L’historique s’étend sur les rails connectés ; sauvegarde et reprise conservent la position |
| Arrivée et ouverture de ville | Le dialogue suspendait l’animation avant la fin du segment | L’arrêt visible atteint le port de gare avant l’ouverture de la ville |
| Arrivée en marche arrière | Le contact arrière de la locomotive manquait dans l’historique | La case intérieure masquée déjà utilisée au départ fournit ce contact ; la locomotive reste visible |
| Départ puis retour à la carte | La carte cachée accumulait une interpolation depuis l’ancienne gare | La carte rouverte présente le train à sa position actuelle |
| Train plus grand que le cadre | La caméra vérifiait le contact avant, insuffisant pour toute la silhouette | Le cadrage utilise les limites alpha de la locomotive, sans changer le zoom |
| Commandes du panneau | Dessins statiques et absence d’état lisible | Frein ON/OFF avec levier mobile ; FWD/REV et cap sur le volant et la flèche |

Les demi-voies de gare sont relevées dans les ressources CARTE : 34 ouest, 35 est, 36 sud, 37 nord. La géométrie intérieure demeure l’adaptation décidée le 26 septembre. Les constantes TIME de progression, les embranchements et la carte restent ceux des sources ECS. Les assets et effets d’Opus sont conservés.

## Preuves

- [Régression du trajet avant correction](validation/route-history-before-20261003.log) : deux échecs sur le code du commit `3f8efc62622764856a351076c3b19a083466b220`, compilé séparément sans revenir en arrière dans le checkout partagé.
- [Même régression après correction](validation/route-history-after-20261003.log) : succès, avec continuité de sauvegarde/reprise et rejet atomique d’un snapshot incomplet.
- [Ancienne caméra](validation/camera-before-20261003.log) : échec du test de silhouette coupée avec la méthode du commit de référence. [Caméra corrigée](validation/test_camera_scale-20261003.log) : succès, zoom constant et absence de recentrage permanent.
- [Matrice géométrique](validation/test_station_matrix-20261003.log) : 75 gares sources, 150 approches avant/arrière aux ports d’arrêt.
- [Jeu natif de toutes les gares](validation/station-play-after-20261003.log) : 85 sites, 170 essais ; 45 villes fixes, terminus et événements de campagne. [Résultats par site](validation/station-play-20261003/results.json).
- [Parcours avec commandes et nomades](validation/test_travel_regressions-20261003.log) : frein, inverseur, aiguillage réellement cliqué, arrivée/départ de Bhopal et retour à la carte ; commerce des nomades dans les deux sens.
- [Seize suites finales](validation/travel-suite-final-20261003.json) : toutes réussies. Elles couvrent les règles ferroviaires, le rendu, la caméra, les villes restaurées et la campagne. La suite `test_campaign_route` couvre le parcours source complet avec son hôte de test ; elle ne constitue pas une partie native continue.
- [Galerie native inspectée](validation/station-play-20261003/index.html) : 264 images dans 27 planches d’arrivées/menus et 68 vues de terminus dans 9 planches. Les captures pleine taille des commandes restent dans `validation/travel-play-20261003/`.
- [Empreintes du code validé](validation/travel-source-final-20261003.json).

## Méthode et limites

Les scripts lancent le vrai `Main`, utilisent `Viewport.push_input` pour les événements souris/clavier, exécutent sa cadence de simulation et attendent le rendu natif. L’agent inspecte ensuite les images. Les approches sont préparées sur la carte source avec un moteur déjà roulant, comme la fixture existante `test_playable_trip`. Ce sont des essais successifs indépendants, pas un tour continu de toute la carte.

Les dix sites révélés utilisent les écritures de carte du contrôleur de campagne. Le site 39,32 devient un passage pendant la révélation Hima et doit laisser passer le train. Les deux terminus 150,41/42 sans accès extérieur sont testés localement ; aucun raccord au monde principal n’est ajouté. Les nomades sont une rencontre mobile, ville 45, et ne sont pas transformés en gare fixe.

Les dialogues Urga/Oslo et le mausolée sont actionnés avec les commandes natives. Les deux approches finales atteignent la séquence SUN puis son signal `movie_finished` et le retour aux options. Ces fixtures n’établissent pas la continuité de toutes les quêtes dans une seule partie.

Une fenêtre native concurrente peut déclencher la pause de perte de focus. Les essais sont donc exécutés successivement et comptent les cycles effectivement réalisés. La simulation conserve cette pause normale.

`game/test.sh` entier n’est pas annoncé vert : les cinq assertions strictes connues sur les six découpes acceptées par le propriétaire restent hors de cette correction. Aucune preuve Windows n’est ajoutée. Aucune publication distante n’est faite.

## Reproduire

Depuis la racine du dépôt, exécuter les commandes l’une après l’autre :

```sh
.toolchain/Godot.app/Contents/MacOS/Godot --path game --script res://tests/test_station_matrix.gd
.toolchain/Godot.app/Contents/MacOS/Godot --path game --script res://tests/test_train_route_history.gd
.toolchain/Godot.app/Contents/MacOS/Godot --path game --script res://tests/test_camera_scale.gd
.toolchain/Godot.app/Contents/MacOS/Godot --path game --script res://tests/test_travel_regressions.gd
.toolchain/Godot.app/Contents/MacOS/Godot --path game --script res://tests/test_station_play.gd
```

Les références exactes avant correction sont les deux méthodes/fichiers du commit indiqué. Les scripts optionnels `--baseline` et `--baseline-camera` attendent une copie de ce code dans `.cache/`, à recréer depuis `git show` ; ces copies temporaires sont supprimées après validation.

## Nettoyage

72 fichiers de cette tâche supprimés, soit 67.7 Mio : captures de terminus en double et copies temporaires de référence. Les planches et leurs légendes restent conservées (86.9 Mio). Aucun nouveau worktree créé ; les worktrees préexistants et les autres changements locaux sont préservés. Aucun processus de test de cette tâche ne reste actif. [Relevé exact](validation/travel-cleanup-20261003.json).
