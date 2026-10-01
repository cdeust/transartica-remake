# Historical user review — 27 September (see current completion run below)

- [ ] Refaire le bandeau avec les mêmes informations, dans la qualité des scènes de wagons. Le grossissement des pixels originaux est rejeté.
- [x] Ajouter un indicateur du sens de marche sur la carte détaillée.
- [ ] Refaire le terrain cartographique et les éléments de décor : rendu courant rejeté.
- [ ] Clarifier puis vérifier l’accès à la carte globale et ce qui doit être visible au départ.

# Correction des villes et ennemis visibles

Bandeau ECS privé et reprise : [validation](validation/map-places-20260927.md).
- [x] Dessiner le bandeau depuis YODA, avec composition réelle et défilement.

- [x] Retirer le filtrage de découverte non original des lieux fixes.
- [x] Afficher les villes par type et les ennemis selon les règles de perception originales.
- [x] Intégrer les décors de villes et vérifier entrée, transaction et départ.
- [ ] Vérifier les captures natives, relire, pousser et nettoyer.

# État du projet et travail restant

## Completion run — 1 October 2026

Base verified remotely: merged PR7 `bf9f9501711a05a6d4a1b1eca318ac4d0263dcf6`.
New changes remain local; no publication or merge is authorized.

- [x] Recover prior work and preserve other sessions’ worktrees.
- [x] Integrate source campaign, original quizzes, deaths and Sun ending.
- [x] Integrate manual/automatic combat, weapons, effects and resumable battles.
- [x] Complete mines, works, drill, commerce, crew and train-management actions.
- [x] Integrate source fauna, nomads, launcher, startup and private source audio.
- [x] Validate atomic full saves, legacy migration and configurable keyboard input.
- [x] Prove original-start earned-cargo campaign with default enemies and actual UI.
- [x] Prove Mausoleum disk resume yields the same ending and full state.
- [x] Validate actual simulation at30/60/144Hz.
- [x] Replace ordinary player engines in actual master sheet, illustrations, HUD, travel and combat with shared massive futuristic locomotive.
- [x] Add authored16goods and25wagon icons; verify native selection and transactions.
- [x] Complete final exact-tree test inventory, independent review and code gates.
- [x] Execute rebuilt macOS application and retain evidence.
- [ ] Execute Windows package on Windows; export alone is insufficient.
- [x] Finish owner-scoped cleanup, preserving unpublished/concurrent work.

Current proof: campaign-route-cleanup-native-after-20261001.log, source route
10 657callbacks,1 713cells,day23,lignite1 067. Native input/save review and
launcher65assertions pass. Source signed audio and nine scores are packaged;
four recurring scores preserve the first attack and original subsequent cycles.
Native goods/wagon icon review passes. Full integration rerun and artifact
acceptance follow the final fixture/art changes. PhysicalAmiga audio timing and
exhaustive historical visual variants are not certified.

[Current coverage and evidence](validation/completion-matrix-20261001.md).

## Historical checkpoints — superseded by current completion review

The sections below retain earlier evidence and rejected presentations. Their
unchecked publication tasks do not authorize publication of the current work.

## Priorité quota : boucle ennemis et combat automatique

- [x] Raccorder apparition, déplacements et rencontres au voyage.
- [x] Raccorder l’option originale de résolution automatique et ses conséquences.
- [x] Sauvegarder ennemis, réglages, hasard et rencontre en attente.
- [x] Vérifier les reprises, pertes, butin et absence de double résolution.
- [ ] Publier le lot et retirer le worktree enregistré.

Validation du lot : [rencontres et combat](validation/world-loop-20260927.md).
Le combat tactique manuel reste un chantier distinct. Aucun objectif de 80 %
n’est annoncé sans inventaire et preuve de campagne.


## Boudoir et bandeau ECS — correction visuelle requise

- [x] Relever les écrans ECS et les commandes décodées : [boudoir](evidence/boudoir-layout.md), [bandeau](evidence/panel-layout.md).
- [x] Raccorder Kolotov, livre, bénitier et revolver ; confirmation, épitaphe, Terre et retour aux options.
- [x] Restituer les accès locomotive, boudoir, quartier général et cartes dans le bandeau original.
- [x] Remplacer les panneaux génériques par l’inventaire encadré et la ligne de sauvegarde de l’original.
- [x] Reprendre les miniatures, les matières des charbons et les chiffres du bandeau après correction visuelle du propriétaire.
- [x] Vérifier les entrées natives, le redimensionnement, les sauvegardes et les événements interrompant le voyage.
- [x] Contenir les chiffres dans les cadres, avec vérification des glyphes à plusieurs tailles.
- [ ] Refaire le bandeau au niveau de pixel art demandé ; le dernier rendu est rejeté.
- [x] Rétablir les axes ECS et le plan général exact, chargé depuis les seules données privées.
- [x] Calibrer le rapport wagon/case et le cadrage initial pour six véhicules complets, sans modifier le réseau.
- [ ] Redessiner le plan général en conservant sa géographie avant une distribution publique.
- [ ] Publier la PR après corrections et revue indépendante, puis retirer le worktree enregistré.

Revue et limites : [validation du lot](validation/boudoir-integration-20260927.md).
La barre de composition, les espions, la préparation complète des wagons, le
lance-missiles et les effets de récit restent à intégrer. Le bénitier conserve
les messages mais leurs effets ne sont pas portés. La musique reste indisponible. La difficulté et le combat automatique sont
raccordés dans le lot suivant. L’acceptation esthétique appartient au
propriétaire ; les tests fonctionnels ne la remplacent pas.

## Reprise de l’implémentation et fusion de la PR #3

- [x] Confirmer que Codex reprend aussi le moteur et l’intégration.
- [x] Vérifier le SHA distant, la base de la PR et les fichiers des autres sessions.
- [x] Corriger le défaut signalé par la revue : rejet des poses de wagons sur historique incomplet, régression native échouant avant et réussissant après. [Preuve](validation/pr3-review-20260927.md).

La fusion de la PR #3 vers `main` est autorisée, avec approbation indépendante
du SHA final avant exécution. Après fusion, synchroniser le
checkout principal et supprimer la branche publiée et le worktree de revue
enregistré ; préserver les fichiers et worktrees des autres sessions.

Point visuel vérifié : au départ, le sixième wagon reste dans la composition
mais est masqué tant que le trajet connu ne permet pas de le placer entièrement.

Prochain lot : raccorder le boudoir illustré, l’inventaire et la sauvegarde aux
règles déjà portées, avec accès depuis le jeu et vérification des entrées natives.
Les effets de récit encore indécodés restent explicitement hors de ce lot.

## Publication et branches distantes (27 septembre)

- [x] Identifier les commits locaux et les deux branches d'essai des PR fermées #1 et #2.
- [x] Vérifier les tests avant le push de `feat/station-arrival` : 30 tests Python sans omission et 15 suites Godot.
- [x] Pousser les commits et ouvrir la [PR Transartica #3](https://github.com/cdeust/transartica-remake/pull/3) vers `main`.
- [x] Préserver les commits d'essai, supprimer leurs branches distantes et relire les références GitHub : seules `main` et `feat/station-arrival` restent.

Revue : suivi dans `tasks/validation/remote-cleanup-20260927.md`.

Mis à jour le 27 septembre 2026. État du moteur testé : PR #3, code de `5b5e61a`.
Cette liste remplace l'empilement des comptes rendus du 24 au 27 septembre ;
l'historique reste dans Git et dans les documents de preuve liés ci-dessous.
Une case cochée valide uniquement l'action nommée. Une logique portée n'est
pas nécessairement raccordée à une scène ; un PNG n'est pas une scène jouable.

Répartition du 27 septembre : Codex reprend le design, l'intégration et les règles.
Opus est indisponible pour cause de quota ; les futurs correctifs du propriétaire
seront examinés avant intégration, sans écraser le travail en cours.
Les travaux présents uniquement dans des worktrees ne sont pas comptés comme
intégrés à cette branche. Aucun pourcentage de campagne complète n'est établi.

## Priorité design : couverture de tous les visuels (27 septembre)

Instruction actuelle : Codex produit les visuels et les intègre. La remise
initialement destinée à Opus reste la référence des dessins livrés.
[Galerie des 32 PNG](../output/imagegen/visuals-20260927/index.html) ·
[Remise à Opus](handoff-visuals-20260927.md) · [Couverture](visual-coverage.md).

- [x] Confronter les manques aux références locales et aux galeries web ECS/AGA/DOS.
- [x] Inscrire l'exhaustivité dans FIDELITE.md et la correction dans lessons.md.
- [x] Dessiner le boudoir, le commandement sans personnages et sept scènes de villes/services.
- [x] Dessiner le décor de combat, une composition de référence et les 25 types de wagons latéraux.
- [x] Produire adversaires, acteurs, équipements et poses clés d'effets.
- [x] Produire cadre cartographique, lieux, rails/aiguillages et états de travaux.
- [x] Produire personnages, trois rencontres, trois propositions de récit et les deux états du Projet Soleil.
- [x] Livrer prompts, galerie, manifeste, sources et indications de montage ; vérifier 32 PNG, alpha, empreintes et identifiants 1–25.
- [ ] Fermer l'inventaire original scène par scène, y compris variantes, menus et transitions.
- [ ] Compléter les animations et couches matérielles après calibration de la scène de combat.
- [ ] Codex : découper, calibrer et intégrer les dessins aux états réels du jeu.
- [ ] Vérifier à taille de jeu et parcourir la campagne pour contrôler les omissions.

Revue : 32 PNG livrés (76 874 777 octets), dont 14 avec transparence. Deux
brouillons remplacés retirés. L'intégration, les interactions et la couverture
exhaustive de l'original restent à vérifier ; aucune campagne complète annoncée.

## Voyage, conduite et commerce

- [x] Chaufferie illustrée interactive : commandes, animation liée aux états, pause et sauvegarde. Preuve : [intégration](evidence/engine-room-integration.md).
- [x] Conduite, consommation et frein progressif raccordés au déplacement sur le réseau décodé. Preuves : [navigation](evidence/navigation-playable.md), [frein](evidence/braking-rules.md), [réseau](evidence/rail-network.md).
- [x] Terrain glaciaire, caméra fixe avec recentrage en bord, découverte, aiguillages et sauvegarde raccordés au voyage. L'ancienne tâche « première boucle sur corridor » est dépassée.
- [x] Choix de la vue de dessus des véhicules accepté et intégré ; rotation rigide selon le trajet. Les demandes antérieures de nouvelles perspectives SE/NW et d'approbation du prototype sont closes par ce choix.
- [x] Les 25 types achetés ont leur dessin dans l'atlas ; composition dérivée des wagons et largeurs redessinées. Intégration `8242d1c`, [revue](wagon-redesign.md), preuves `validation/overhead-atlas-redesign-tests.log` et captures associées.
- [x] Arrivée en ville, départ et présentation du convoi au retour. Preuve : [gares](evidence/station-arrival.md).
- [x] Achat/vente, refus, stocks, recrutement et atelier des villes 10–16 raccordés à l'écran de ville. Preuve : [commerce](evidence/city-scripts.md), tests `test_city_trade.gd`, captures KUWAIT et IN SALAH.
- [x] Calendrier jour/heure sauvegardé et pont temporisé (110,33) raccordés (`2a4e72e`, `game_calendar.gd`, `main.gd`).
- [ ] Corriger les limites graphiques restantes : longueurs XL peu différenciées, extrémités et attelages à vérifier ; voir [revue du catalogue](wagon-redesign.md).
- [ ] Porter textes TOWN, gare-atelier, effets de personnel/animaux et drapeaux de commerce restants. La note de commerce disant que les wagons achetés ne sont pas dessinés décrit l'état antérieur à `8242d1c`.
- [ ] Vérifier les effets journaliers et horaires encore non raccordés (mines, apparition ennemie, autres événements).
- [x] Mines portées en règles pures (création tous les 3 jours, épuisement, prospection) : `mines.gd`, `test_mines.gd`, [preuve](evidence/mines.md). Non raccordées : écritures de carte à accepter par `rail_network.gd` (aiguillages 18–33, cases 78/79), dialogue de prospection. `mine.alis` n'est qu'une scène de palette : aucune règle d'exploitation trouvée.

## Obstacles et travaux

Preuves : [obstacles](evidence/obstacles.md), [inconnues et décodage complémentaire](evidence/obstacles-unknowns.md).

- [x] Rails 38–58 et croisements 15/16 corrigés (`6b113e0`).
- [x] Conditions de travaux, consommation des rails, réparation des cases et dialogue raccordés (`705a559`). Captures natives `validation/works-*.png`.
- [x] Ponts issus de CARTE.FIC au démarrage, refus avec frein conservé et reprise explicite (`7609ca1`). L'effet principal d'un refus n'est plus une inconnue.
- [ ] Reproduire l'écran et le déroulement des travaux : le code répare actuellement la case dès l'acceptation ; le décodage place l'écriture après fermeture du texte. Le compte à rebours TEXTEK et sa cadence restent à traiter.
- [ ] Porter les scènes spécifiques des cases 65/−120/78/79, les gares sans ville et les rencontres de récit 22–25.
- [ ] Porter la foreuse à (32,67), selon TIME 0x1c31.
- [ ] Vérifier le demi-tour sur sa propre trace pour chaque événement concerné, avec locomotive en tête côté retour selon l'adaptation demandée.

## Combat

Preuve : [décodage et portage](evidence/combat.md).

- [x] Déclenchement, composition, classes de combat, fin, butin et résolution automatique étudiés dans les scripts.
- [x] Composition initiale portée dans `combat_setup.gd` ; fin/butin/résolution automatique dans `combat_outcome.gd` (`584767f`, intégré par `05e0722`).
- [x] Tests dédiés écrits dans `game/tests/test_combat.gd` ; 13 contrôles annoncés par le commit de portage. Suite réexécutée avec succès avant publication : `validation/pre-push-godot-extra-20260927.log`.
- [ ] Porter la simulation par pas : déplacements, armes, dynamite, IA et géométrie des emplacements. `combat_state.gd` n'est pas fourni par le portage actuel.
- [x] Trains ennemis portés en règles pures (apparition, déplacement, aiguillages, obstacles, rencontre, retrait) : `enemy_trains.gd`, `test_enemy_trains.gd`, [preuve](evidence/enemy-trains.md). Hors périmètre : rectangle mine TIME 0x2221, bits 64 et 1.
- [ ] Raccorder le déclenchement, les trains ennemis et le résultat à la session jouable. Instructions d'intégration : [enemy-trains.md §6](evidence/enemy-trains.md), [mines.md §8](evidence/mines.md).
- [ ] Résoudre la position relative du train joueur, l'option de combat désactivé et la cadence réelle.
- [ ] Intégrer les nouveaux dessins à une scène de combat, calibrer son échelle et vérifier les actions dans le jeu.

## Boudoir, quartier général et panneau

Preuve : [capitaine et équipage](evidence/captain-crew.md).

- [x] Logique du bénitier, inventaire, actions du boudoir, espions/draisines et zones du panneau portée dans cinq modules (`8e67eb0`, intégré par `05e0722`).
- [x] Tests dédiés écrits dans `game/tests/test_quarters.gd` : pile de messages, inventaire, conditions d'actions et panneau. Leur présence ne prouve pas l'intégration UI.
- [ ] Raccorder ces modules aux scènes, entrées utilisateur et sauvegarde. Les nouveaux modules ne sont pas appelés par `main.gd` dans l'état examiné.
- [ ] Porter les effets des messages YODA et scènes déléguées, le corps de l'inverseur et la correspondance des icônes A/B/C.
- [ ] Clarifier les cas limites signalés dans la preuve : BOILER dans l'inventaire, calcul du chargement du tender, ordre des lignes et champs inconnus.

Le décodage n'atteste pas de journal ni d'écran autonome d'équipage original.
Les anciennes tâches qui les présentaient comme des écrans obligatoires doivent
être interprétées comme des pistes d'inventaire, pas comme des fonctionnalités attestées.

## Campagne, références et distributions

- [x] Carte décodée et coordonnées recoupées : [format](../FORMAT-CARTE.md). Réseau et commerce ont dépassé les anciennes tâches « à décoder ».
- [x] Recherche des scènes et de la fin documentée : [sources de campagne](../CAMPAGNE-SOURCES.md), [visuels originaux](evidence/original-visuals.md).
- [ ] Porter la chaîne complète de récit, les conditions de la centrale et les fins ; vérifier une partie complète.
- [ ] Résoudre les inconnues documentaires encore ouvertes, dont Tibesti et les traitements non décodés ; aucune règle de moral ne doit être ajoutée sans preuve.
- [ ] Reprendre le pipeline de spécification arrêté sur le connecteur absent : `spec-pipeline.json` décrit l'arrêt historique.
- [ ] Reconstruire les distributions après intégration des changements actuels. Les exports du 25 septembre ne valident pas le moteur du 27.
- [ ] Exécuter le binaire Windows sur Windows ; le contrôle PE x86-64 historique ne suffit pas.
- [x] Refaire les contrôles de régression caméra/voyage : suites réussies sur le code de la PR #3 ; voir `validation/pre-push-godot-20260927.log`.

## Commit des visuels et vérification documentaire

- [x] Produire une galerie locale et vérifier PNG, transparence, empreintes, liens et les 25 identifiants.
- [x] Retirer les chemins personnels des références de génération ; garder les captures originales dans le répertoire privé ignoré.
- [x] Réconcilier cette liste avec les commits et les preuves courantes, en séparant logique portée et intégration.
- [x] Préparer le commit demandé des dessins et de la documentation ; worktrees et validations des autres travaux exclus.

Les changements de cette livraison ne touchent pas le moteur. Les contrôles
applicables portent sur les assets, la galerie, les données de remise et le diff.
Les journaux `validation/pre-push-*-20260927.log` établissent les résultats
locaux de la PR #3 : 30 tests Python et 15 suites Godot. Ils ne prouvent pas
une campagne complète ni le fonctionnement du binaire Windows.

## Nettoyage des visuels (27 septembre)

- [x] Examiner références moteur, manifestes, outils, tests et comparatifs avant suppression.
- [x] Retirer 12 PNG remplacés ou dupliqués et les trois fichiers d'import associés ; conserver leurs empreintes et le commit de récupération.
- [x] Vérifier les références restantes, les galeries et les tests des outils graphiques.
- [x] Mesurer le gain : 20 613 348 octets. Nettoyage commité, travaux concurrents préservés. [Rapport](asset-cleanup-20260927.md).

## Locomotive consistency — owner direction, 1 October 2026

- [ ] Inspect the original box art and define one massive futuristic locomotive design sheet.
- [ ] Apply its silhouette and identifying details to the travel vehicle, tactical locomotive, startup and every illustrated scene showing our train.
- [ ] Compare all depictions together and verify the integrated travel/combat sprites at game size, keeping the accepted invariant vehicle dimensions.

This is a shared artistic pass after the remaining gameplay integration. Existing
wolf/mole drafts are provisional until their locomotive foreground matches it.

## Final review — 1 October

All56test scripts plus core runner pass;33Python tests plus the independent
static-plan pixel/vector roundtrip pass. Source/craft staged gates0errors/0warnings.
One intermittent capture-fixture WAV teardown leak was diagnosed; actual
resource release is awaited and three sequential native runs are clean. Runtime
and exported PCK were unchanged. Independent integration review found no critical
defect in inspected model/UI/save/art/export connections.

Actual exported macOS application passes startup, viewport controls, map/HUD
scroll, F5 and named LOAD with exact state restoration. Windows EXE/PCK exported;
Windows execution remains unverified because no Windows host was available.
Cleanup removed453 822 049bytes of obsolete app/import caches and disposed the
registered artifact-test temp after preserving evidence. Unpublished commits
and other sessions’ work remain protected. No remote publication performed.
