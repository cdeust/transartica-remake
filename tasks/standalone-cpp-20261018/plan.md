# Plan d'exécution C++ sans Godot

> Exécution : superpowers:executing-plans ; tâches et preuves conservées ici.

**But :** livrer le jeu dans un exécutable autonome dont le parcours est visible.
**Architecture :** domaine C++ standard, plateforme SDL2, composition native unique.
**Stack :** C++20/CMake/SDL2/libpng ; dépendances supplémentaires justifiées par leur usage.
**Spec :** spec.md, qui remplace la cible Godot de cpp-port-20261013/spec.md.

## Jalons et critères de sortie

- [x] N1 — Application autonome : build sans Godot, fenêtre et assets réels,
  accueil et navigation cabine/carte par entrées natives. Erreurs d'assets visibles.
- [x] N2 — Noyau extrait : carte et rails authentifiés, chauffe/pression/frein,
  phases de voyage et géométrie sur voies. Tests source-grounded en C++ seul.
- [x] N3 — Première intégration jouable : état unique, contrôles, déplacement
  visible, caméra conforme, sauvegarde atomique et reprise native vérifiée.
- [ ] N4 — Monde et scènes complets : package artistique de production, villes,
  terrain/occlusion/installation, entités, transitions et interactions.
- [ ] N5 — Campagne entière : économie, équipage, événements, IA, combats,
  audio et finale ; reprise des sauvegardes antérieures ou migration explicite.
- [ ] N6 — Distribution et mesures : paquet natif Windows/macOS/Linux,
  lancement/entrées/sauvegardes sur chaque système annoncé ; benchmarks appariés
  et mémoire mesurée, sans supposer un gain du seul choix du langage.

## Ordre et responsabilités

Avant N1–N3, publier les interfaces du noyau et du rendu. Une personne par module.
Root possède CMake, plateforme, application, intégration et toutes les exécutions.
Un spécialiste extrait le noyau ; un autre raccorde les visuels existants.
Revue indépendante des règles et de la chaîne d'entrée avant validation.
Les modèles encore dépendants de Godot ne comptent pas comme modèles autonomes.

## Correction graphique propriétaire

Le premier affichage C++ utilisait des barres de texte et omettait le bandeau
de production. Le propriétaire le rejette le18octobre. N1/N3 exigent désormais
le original_panel illustré, ses commandes, les quartiers, le boudoir, les
instruments, les deux cartes et le dialogue de sauvegarde. Aucune parité
graphique ne sera déduite du premier déplacement visible.

## Points de revue

- Entrée de ville/événement : jamais contourner un contrôleur non porté.
- Sauvegarde invalide/tronquée : valider avant mutation, préserver la partie.
- Perte de focus/pause et cadence : aucune simulation liée au nombre de frames.
- Chemin d'assets manquant : erreur explicite, pas une fenêtre noire silencieuse.
- Projection/train : garder la carte et la taille des wagons ; aucun zoom de virage.

## Suivi

- [x] Mandat sans Godot enregistré, ancien lot conservé sans clôture trompeuse.
- [x] Dépendances SDL2/libpng présentes ; architecture et données inspectées.
- [x] Interfaces, 93 contrôles du noyau et premier exécutable visibles.
- [x] Revue indépendante et validation native : voir validation.md.
- [x] Nettoyage des temporaires propres, reçu cleanup.json.

N1–N3 désignent le parcours avant borné décrit dans spec.md, exécuté sur ce
Mac. Ils ne valident ni la marche arrière, ni le jeu entier, ni une parité
graphique complète. Les actions de campagne encore absentes restent visibles
comme indisponibles. N4–N6 restent ouverts ; aucune clôture du mandat global.
