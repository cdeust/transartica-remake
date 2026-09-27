# Nettoyage des visuels du 27 septembre 2026

15 fichiers supprimés : 12 PNG et trois fichiers d'import Godot, pour
20 613 348 octets (19,66 Mio). Liste, tailles et SHA-256 :
[relevé](validation/visual-asset-cleanup-20260927.json).

## Suppressions

- Sept anciens dessins du convoi entier `output/imagegen/train-*.png`, remplacés
  par les véhicules indépendants puis l'atlas de dessus.
- Deux copies strictement identiques des atlas `vehicles-southeast-v3.png` et
  `vehicles-northwest-v2.png` dans `output/imagegen/`. Les exemplaires utilisés
  par les outils de mesure restent dans `game/assets/travel/`.
- Trois variantes remplacées dans `game/assets/travel/` :
  `vehicles-southeast.png`, `vehicles-southeast-v2.png`, `vehicles-northwest.png`,
  avec leurs fichiers `.import`. Le manifeste oblique conservé désigne les
  versions SE v3 et NW v2.

Chaque fichier supprimé correspondait exactement à sa version commitée.
Récupération historique, depuis la racine du dépôt :

```sh
git restore --source=7034997cfd50387615a729f06c3c875214347fa3 -- chemin/du/fichier
```

Les anciens comptes rendus restent historiques ; leurs exemples de commandes
peuvent nécessiter cette récupération. Aucun historique Git n'a été réécrit.
Le gain concerne l'arbre de travail, pas les anciens objets du dépôt.

## Conservés pour un usage identifié

- Les 32 nouveaux visuels et le commandement initial : remise à Opus, prompts
  et références de génération encore utilisés.
- `wagon-redesign-20260926/` et six PNG du premier catalogue : sources des
  25 types consommées par `tools/build_overhead_atlas.py`.
- Les 19 autres PNG du premier catalogue : comparatifs avant/après et entrées
  de `tools/audit_wagon_redesign.py`. Les supprimer casserait cet audit.
- `vehicles.json` et les cinq planches qu'il désigne : entrées des outils
  `audit_vehicle_dimensions.py` et `calibrate_vehicle_lengths.py`.
- `train-east.png` : référence réelle des tests de `sprite_pipeline.py`.
- Prototype de dessus, maquette de chaufferie, prompts et captures de validation :
  références documentées de conception ou preuves. Les textures de chaufferie,
  y compris les masques de survol, sont chargées par le jeu.

## Vérification

Les chemins de textures statiques du moteur, les deux manifestes d'atlas,
les empreintes des 25 sources actuelles et les liens de toutes les galeries ont
été contrôlés après suppression. L'audit des wagons redessinés s'exécute encore.
Les 10 tests de `sprite_pipeline.py` passent sans test ignoré ; journal dans
`validation/asset-cleanup-sprite-tests.log`.
Les worktrees et les fichiers des autres sessions sont préservés.

La suppression a révélé un défaut du hook Zetetic : lecture UTF-8 des PNG avant
sélection du langage. La correction locale autorisée applique la sélection
avant lecture, séparément pour l'ancien et le nouveau chemin. Les 141 tests
ciblés passent ; les suppressions réelles passent ensuite le hook installé.
Le correctif du plugin et ses tests sont dans la [PR #151](https://github.com/cdeust/zetetic-team-subagents/pull/151),
commit `48ec4b8`. 41 suites complètes passent ; le contrôle fail-before valide
les 18 nouvelles régressions. Les versions proposées sont 2.42.1 (plugin complet)
et 1.1.1 (paquet autonome). Les 15 contrôles CI passent sur cette tête, et la PR est fusionnable.
La diffusion publique dépend de la fusion de cette PR.

## Fichiers de test protégés

Le worktree de la PR et sa branche locale sont retirés après chaque push.
Le répertoire `.cache/disk-hygiene-hycqs6uv` est conservé par la procédure de
nettoyage : il contient les dépôts Git factices créés par les tests. Le contrôle
retourne `temporary directory contains a Git checkout`. Aucune protection n'a
été contournée pour le supprimer. Les processus de test ont terminé.
