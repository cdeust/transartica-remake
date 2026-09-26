# Transartica : remake en construction

Référence : Amiga 500 ECS anglais. Objectif : remake fidèle à la carte et à toute l'histoire, pixel art moderne, commandes clavier/souris actuelles, multiplateforme avec priorité Windows. Le code créé sera sous MIT ; les ressources historiques restent des références documentaires.

- [Décisions et critères de fidélité](FIDELITE.md)
- [Recherche générale](DOSSIER.md)
- [Inventaire mécanique](INVENTAIRE.md)
- [Villes et parcours documentaire](data/README.md)
- [Sources de campagne](CAMPAGNE-SOURCES.md)
- [Inspection des disquettes ECS](OBSERVATION-ECS.md)
- [Carte décodée : preuves et limites](FORMAT-CARTE.md)
- [Villes décodées : preuves et limites](FORMAT-VILLES.md)
- [Centrale et fin de campagne](FIN-CAMPAGNE.md)
- [Travail restant](tasks/todo.md)

## Essayer la préversion

- macOS : ouvrir `builds/macos/Transarctica — Northern Survey.app`.
- Windows : décompresser `builds/Transartica-Windows.zip`, puis lancer
  `Transartica.exe` en conservant `Transartica.pck` à côté.
- Depuis les sources sur ce Mac : `game/run_local.sh`.

Cette préversion ouvre une chaufferie illustrée et animée. Cliquer les chauffeurs
règle les deux alimentations en charbon. Cliquer les cadrans ouvre un écran
d'instruments distinct, avec mesures vivantes, régulateur et retour à la chambre.
L/A commandent les chauffeurs, B le frein, Espace la pause, F5/F6 la sauvegarde
complète de cette session, R son redémarrage. M ouvre la carte et J le journal.
La cadence est indépendante du rendu, mais la seconde réelle par cycle reste
une calibration de préversion. Les événements non portés arrêtent la simulation.

Le brouillard de découverte est une évolution autorisée par le propriétaire ;
sa portée actuelle est provisoire. Un premier parcours de conduite suit la ligne
de départ vers l'est, de (12,62) à (33,62), puis s'arrête avant le croisement non
porté. Ouvrir M, alimenter les chauffeurs, régler le régulateur et relâcher le
frein. La carte reste active pendant le trajet ; la sauvegarde inclut sa progression.
Les branches des aiguillages et la marche arrière ne sont pas encore disponibles.
Une ancienne sauvegarde de chaufferie conserve son moteur et commence son premier
trajet au départ : aucune position de voyage n'existait dans cette version.
La scène de voyage utilise maintenant une projection 2D oblique avec train,
terrain glaciaire et brouillard. Les combats, la composition modifiable du train, les
villes, le commerce et la campagne complète restent à construire. Le niveau
graphique de Noita est l'objectif, pas une qualité certifiée de cette préversion.

Le [registre de couverture](tasks/original-game-coverage.md) distingue chaque
système de l'original, les évolutions autorisées et les parties manquantes.
Les [preuves de conduite](tasks/evidence/locomotive-rules.md) et
[d'instruments](tasks/evidence/boiler-instruments.md) décrivent les règles
vérifiées et leurs limites. Validation : `game/test.sh` et
[témoin d'export](tasks/validation/engine-room-export.txt).

Le code nouveau est sous MIT. Les paquets locaux contiennent des données
historiques privées ; ils ne sont pas des releases publiques sous MIT.

## Reproduire les contrôles

```sh
TMPDIR="$PWD/.cache" python3 -m unittest discover -s tests -v
game/test.sh
python3 tools/build_preview.py all
```

Le moteur Godot 4.5 et ses modèles sont dans `.toolchain/`. Le script de build
utilise ces fichiers locaux, copie les données privées et produit les archives.
Les sorties de validation et limites sont dans `tasks/validation/`.

Le protocole prd-gen a été tenté ; son étape d'analyse du code exige un connecteur
absent. Son arrêt est consigné dans `tasks/spec-pipeline.json`. Aucun PRD généré
n'est déclaré terminé. Le contrat de fidélité et le contrat d'exécution guident
le jalon testable et la suite de la reconstruction.
