# Reprise Codex : Transartica, 26 septembre 2026

## Demande active

Continuer le remake dans `/Users/cdeust/Developments/Transartica`.
Priorité : corriger les changements de taille du train selon sa direction et
l'alignement des wagons sur les rails. Le travail annexe session-optimizer
PR44 est terminé. Le propriétaire demande une nouvelle session avec ce checkpoint.

## Exigences du propriétaire

- Même longueur ET même largeur visibles pour un véhicule dans toutes les directions, à zoom fixe. Aucun raccourcissement perspectif : cette exclusion date du départ.
- Garder la caméra fixe et le déplacement sur le réseau ferroviaire. Freinage progressif avec maintien du régulateur.
- Le train accepté représente sa composition initiale. Achats de wagons et d'armement doivent modifier la composition visible en voyage et en combat. Chaque wagon est modulaire ; un bitmap du convoi entier ne convient pas.
- Le combat doit respecter la composition et l'orientation du train sur la carte.
- Ne pas remplacer silencieusement l'aspect accepté par une autre vue.

## État du rendu du jeu

Le défaut visuel n'est PAS corrigé dans le jeu.

Opus/Claude a travaillé sur l'échelle uniforme et le placement des voitures.
Son passage de relais est dans `tasks/handoff-sprites.md`. Lire aussi
`tasks/lessons.md` et la fin de `tasks/todo.md`. Ce dossier de projet n'était
pas un dépôt Git lors de cette session. Préserver les travaux concurrents.

Fichiers concernés :

- `game/scripts/train_renderer.gd` : atlas directionnels, poses, placement rigide.
- `game/scripts/train_journey.gd` : historique et échantillonnage du trajet.
- `game/scripts/travel_world.gd` : projection, caméra et dessin du train.
- `game/scripts/train_consist.gd` : composition et longueurs des véhicules.
- `game/assets/travel/vehicles.json` et atlas PNG : dessins directionnels.
- `tools/sprite_pipeline.py` : pipeline des images ; lire son contrat avant emploi.

Les atlas SE v3 / NW v2 générés dans la session restent en place. Ils ne
satisfont pas encore la demande. Ne pas qualifier leur validation de réussite.

## Essais rejetés : ne pas les répéter

1. Régénérer avec un raccourcissement perspectif : contraire à la demande.
2. Normaliser chaque dessin oblique par sa seule longueur avec un facteur
   isotrope : agrandit la largeur des vues de face, train massif vers le bas.
   Cette tentative et son espacement par arc projeté ont été retirés du jeu.
3. Étirement, écrasement ou cisaillement des sprites dans les virages : refusés.

`tasks/screen-length-contract.md` décrit une tentative retirée, pas une méthode
à réappliquer. `tools/calibrate_vehicle_lengths.py` reste un outil de mesure ;
ne pas lancer son écriture de données pour réintroduire la normalisation.
Les anciennes captures portant « foreshortening » ou « constant-length » ne
prouvent pas une correction acceptée.

## Prototypes séparés, choix visuel encore en attente

Une vue de dessus a été proposée pour utiliser le même dessin tourné rigidement,
ce qui conserve le gabarit complet. Le propriétaire n'a pas encore accepté
ce changement de vue. Les prototypes ne sont PAS intégrés au jeu.

Images et métadonnées :

- `output/imagegen/vehicles-overhead-prototype-v2.png`
- `output/imagegen/vehicles-overhead-prototype-v2.json`
- `output/imagegen/vehicles-overhead-prototype-v2-prompt.txt`

Deux bancs natifs :

- `tasks/validation/review_overhead_prototype.gd` : un véhicule dans huit caps,
  touches 1 à 6. Capture `tasks/validation/overhead-prototype-eight-headings.png`.
- `tasks/validation/review_overhead_convoy.gd` : six véhicules sur une boucle
  circulaire de diagnostic. Espace : pause ; R : marche arrière sans retourner
  les caisses. Capture `tasks/validation/overhead-convoy-loop.png`.
  Le journal `tasks/validation/overhead-convoy-loop.log` indique 48 poses
  rigides vérifiées, avec échelle identique sur les deux axes. Ce contrôle
  géométrique n'est ni une validation artistique ni une validation du jeu.

Le second banc a été ouvert et inspecté. Il peut encore être lancé.
Pour le rouvrir depuis le dossier du projet :

```sh
.toolchain/Godot.app/Contents/MacOS/Godot --path game --script ../tasks/validation/review_overhead_convoy.gd --log-file /Users/cdeust/Developments/Transartica/tasks/validation/overhead-convoy-loop.log
```

Utiliser le lancement natif autorisé hors sandbox si nécessaire : un précédent
lancement Godot sandboxé a planté dans RotatedFileLogger. Ne pas fermer les
fenêtres ou processus d'autres sessions sans identifier leur propriétaire.

## Prochaine action

Lire ce checkpoint et les leçons, puis examiner les deux captures de prototype.
Reprendre au choix de présentation encore ouvert : conserver l'aspect oblique
accepté et reprendre les dessins directionnels, ou adopter la vue de dessus
proposée. La question a déjà été posée ; ne pas considérer l'absence de réponse
comme une acceptation de la vue de dessus. Intégrer ensuite la solution retenue
avec composition modulaire, et vérifier visuellement le convoi entier dans les
huit caps et les virages à zoom fixe. Reprendre les tests de trajet et de rendu
après les modifications. Ne pas annoncer le défaut corrigé sur la seule foi
d'une égalité de longueurs.

## Travail annexe terminé : context-guard

PR https://github.com/cdeust/session-optimizer/pull/44 fusionnée.
Commit de fusion : `52fe5935218b719a92b1f60f967b6b1300471fcf`.
Correctifs : `c2b59dcd6eaa0339f631636bfe472047eaa249b8`.

- Suivi des sous-agents Codex via `agent_transcript_path`, compteurs cumulés
  du thread enfant, cache compté une seule fois, coût inconnu affiché indisponible.
- Migration des anciens seuils livrés, avec conservation des réglages personnalisés.
- 125 tests Python, couverture 95 %, 75 tests shell, Ruff et ShellCheck passent.
  CI et CodeQL verts sur le commit corrigé ; revue indépendante approuvée.
- Validation native Codex 0.157.1 app-server : Stop bloqué, consigne transmise,
  checkpoint écrit par le modèle, arrêt suivant propre. SubagentStop observé,
  bilan enfant présent dans le message de checkpoint du parent.

Installation réelle :
`context-guard@session-optimizer-codex` 2.1.0, hooks Stop/SubagentStop approuvés,
seuils Astra vérifiés 180000/220000. Les nouvelles sessions chargent cette version.

Incident de migration corrigé : la suppression de l'ancien plugin a supprimé
le fichier encore référencé par cette session. La copie exacte 2.0.0 a été
restaurée dans
`/Users/cdeust/.codex/plugins/cache/session-optimizer-marketplace/context-guard/2.0.0`.
L'ancienne entrée est explicitement `enabled = false` pour les nouvelles sessions.
Conserver ces fichiers tant que des sessions anciennes peuvent encore les invoquer.
Après restauration : ancien hook exécutable sans erreur ; inventaire d'une nouvelle
session montrant seulement les deux hooks 2.1.0 actifs et approuvés.

Clone de revue isolé :
`/Users/cdeust/Developments/.reviews/session-optimizer-pr44-8de3910`.
Les preuves locales sont dans `.review/VALIDATION.md` et les fichiers JSONL natifs.
Ne pas publier `.review/` : il contient une sauvegarde privée de configuration.
La copie temporaire d'authentification utilisée pour les essais a été supprimée.
Ne pas refaire la PR ni désinstaller de nouveau le cache encore chargé.

## Nettoyage demandé par le propriétaire, 26 septembre

Le clone `.reviews/session-optimizer-pr44-8de3910` a été supprimé après
vérification de PR44 fusionnée et du HEAD distant. Les deux rapports et les
preuves natives utiles sont conservés dans `tasks/validation/pr44/`.
Les copies temporaires de configuration et le profil natif de test ont été supprimés.
La suite actuelle est `tasks/checkpoint-codex-camera-2026-09-26.md`.
