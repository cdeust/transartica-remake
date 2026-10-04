# Historical user review — 27 September (see current completion run below)

## Reprise des interactions : véritables découpes, 2 octobre 2026

- [ ] Remplacer les huit masques de contours refusés par des découpes raster transparentes des sujets source.
- [ ] Examiner chaque découpe et sa registration sur le décor ; corriger les fragments de mobilier conservés.
- [ ] Brancher la surbrillance sur la transparence des découpes, puis vérifier le rendu natif et les interactions.
- [ ] Montrer les découpes et les surbrillances au propriétaire avant le commit demandé.

Les anciens essais par détection de contours sont refusés. Leur suite verte ne valide pas les découpes demandées. Aucun commit des masques n'a été effectué.

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

## Interactive wagon masks — 2 October 2026

- [x] Bind boudoir and General Quarters artwork to existing actions and masks.
- [x] Confirm hover highlight; create eight masks with the existing chaufferie shader.
- [x] Rework all source contours after renewed rejection: correct measured vertices and preserve outer clothing/object edges.
- [x] Inspect source registration, preserve metadata and prepare handoff.
- [x] Native highlight/resize/modal tests and full boudoir input regression pass.
- [x] Repeat enlarged source/shader review of all eight masks; six contour regressions fail before and pass after.
- [x] Open corrected gallery with fresh native captures for owner review before commit.
- [ ] Commit masks after this requested visual review.
- [ ] Owner's artistic acceptance in game.

## Missing trooper poses for Opus — 2 October 2026

- [x] Bind request to `handoff-trooper-poses-codex-20261002.md` and the supplied v2 soldier sheet.
- [x] Generate both color variants: five climb/mantle, three plant, five forward death and four backward death frames.
- [x] Generate the two additional passing run frames per variant.
- [x] Inspect pose completeness; measure alpha, preserve prompts/hashes in actor manifest.
- [x] Deliver generated sheets for Opus to cut and integrate, with remaining alpha/scale limits stated.
- [ ] Normalize alpha and exact source scale if user chooses local bitmap finalization; otherwise Opus owns those steps.

Contract and inventory: [wagon masks](wagon-masks-20261002.md).
Review: [eight source/overlay comparisons](../output/wagon-masks-20261002/index.html).

## Actor sprite design for Opus — 2 October 2026

- [x] Inventory live actor types, source actions, projection and current sprite limits.
- [x] Produce original design sheets for troopers, wolves, mammoths and spies.
- [x] Specify readable silhouettes, animation states, pivots and event attachments.
- [x] Inspect delivered sheets and prepare Opus handoff with unresolved production checks.

Owner request: help design sprites with Noita-inspired animation; Opus finalizes.
This pass supplies design references. Runtime animation and artistic acceptance
remain subsequent work. Existing motion design stays preserved.

Review: [Opus handoff](handoff-actor-sprites-opus-20261002.md) and
[four-sheet gallery](../output/imagegen/actors-20261002/index.html).
Generated pose concepts are inspected; exact frame geometry, clean alpha,
missing headings/actions and game-size pixel polish remain for finalization.
No runtime source change, animation acceptance, commit or publication in this pass.

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
- [x] Tactical cadence: byte8375 is pass parity, not side (0x13a1/173e); player
  infantry was frozen, mammoths half speed. Both roofs swept per pass (0x1713,
  ALIS cswitch2 index=value+base); roof steps on 8548, fuses five passes.
- [ ] Reported "commanded player mammoth did not move": not reproduced. Scene
  path (livestock deploy, Down) moved it 5→0 within10s pre-fix and in2.5s
  post-fix. Faithful silent no-ops: Up/click above at y5 (0x1f27 y>=6 bound)
  and S (split) on a mammoth. Needs the owner's exact steps.
- Note: eight suites (campaign_fauna, campaign_visuals, city_list_icons,
  game_boot, key_bindings, launcher, restore_city, startup_intro) hang under
  --headless; run them with a window.
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

## Living effects iteration, 1 October 2026

- [x] Verify approved publication: origin/main79c80b28a5a7a9bf227269dcceac4b015b11e182.
- [x] Assess combat-quality travel: directional art and a compatible renderer are feasible; uniform scaling cannot supply side perspective. See combat-view-feasibility-20261001.md.
- [x] Add original-event muzzle/tracer, fracture debris, layered blasts and lingering smoke with an independent visual clock/RNG.
- [x] Integrate launcher exhaust/impact, mine/work dust and lamps, furnace steam/embers and rigidly registered locomotive smoke.
- [x] Correct renderer rounding at translated coordinates while preserving complete contacts and unchanged short-history rejection.
- [x] Verify native attachments, OPTIONS pause, save/restore and New Game transient cleanup through independent review.
- [x] Run complete Godot inventory:63 PASS records, no script/shader errors;33 Python tests pass.
- [x] Measure native CPU effects submission at128emitters/2048particles: median3.129ms, p953.900ms. Fixed updates median0.844ms, p951.432ms. GPU frame time excluded.
- [x] Independently approve integration after fixing stale transient caches and same-frame smoke registration.
- [x] Verify actual rebuilt macOS executable: desktop input/save/load and28 native effect checks; source/craft gates zero findings.
- [x] Preserve evidence; dispose registered artifact scratch and410668647bytes of redundant builds. Unpublished worktree/app and Windows archive retained.

Travel-renderer preference remains unanswered. This iteration improves effects shared by either presentation. It does not claim a new directional side-view map. New changes remain on feat/living-effects; the earlier approved push is complete.

## Motion design : handoff Opus, 1 octobre 2026

- [x] Consigner les corrections du propriétaire sur l'ignition et les effets Gatling.
- [x] Figer les modifications de production ; conserver les changements non commitées sur feat/living-effects.
- [x] Préparer [le handoff avec captures et défauts confirmés](handoff-motion-design-opus-20261001.md).
- [x] Vérifier le cache graphique natif après correction du fichier canonique wagon-01.png.
- [x] Corriger le montage Gatling et l'alignement des pieds des acteurs sur les toits (vérifié en capture native).
- [x] Examiner la séquence complète d'ignition et corriger les défauts signalés (flamme coupée, fumée sans accumulation, tuyère en escalier).
- [ ] Obtenir l'acceptation artistique sur les animations natives.

Les fixtures combat préservent les états source avant/après. Les ancrages de
présentation restent défectueux ; cette itération n'est pas déclarée terminée.
Le fichier canonique de locomotive est corrigé localement, sans nouveau push.

### Itération Opus, 1 octobre 2026 (soir) — non commitée, aucun push

Décision du propriétaire, 1 octobre 2026 : les scènes dynamiques ne gardent pas
le rythme temps réel ECS (« la pause active est déjà amplement suffisante ») ;
la carte du monde conserve une vitesse jouable. Règles et RNG par tick inchangées.

- [x] Combat ×2 (`tactical_scene.PACE`) : un tick source toutes les40ms au lieu de80. Glissement des trains entre ticks (vitesse courante, bornes source).
- [x] Lanceur : lancement/montée ×1,5, vol/impact ×2 (`launcher_session.PACE`). Armement et carte du monde inchangés.
- [x] Fusée : courbe présentée à vitesse non décroissante (PAV + moyenne5), écart max1,4px aux poses BERTA ; Hermite cubique à la cadence d'affichage.
- [x] Jet : cœur dense, traînée qui s'estompe sans coupure, écrasement/évasement sur le plateau. Nuage au sol alimenté à la base, front qui roule, levée après décollage ; tramage Bayer.
- [x] Vol sur carte : défilement continu des cellules CARTE, missile interpolé, traînée continue.
- [x] Gatling : asset original `gatling.png` (cellules mesurées) ; vue de dos complète, vue de face = socle + coiffe six bouches. Rotation, échauffement, recul, flash, traceurs, ricochets.
- [x] Douilles laiton dessinées, éjectées depuis la culasse, rebond et repos sur le toit.
- [x] Canon : bouclier, frein de bouche, culasse ; flash, onde, fumée latérale.
- [x] Ancrage unique arme/flash/traceur ; pieds des acteurs sur la surface réelle du sprite (affichage et clic).
- [x] Explosions : flash blanc, halo additif, onde au sol, braises à traînée de suie, fumée tramée qui s'érode ; secousse limitée à l'affichage.
- [x] Parité : combat à ×1 même hash `bae607f4…` ; fusée35/35 états BERTA identiques (fixtures épinglées à ×1).
- [x] Tests : test_blast_detail, test_rocket_ignition, test_tactical_art_cache, test_living_effects, test_tactical_combat (headless), test_launcher (natif) : PASS.
- [x] Dégâts des wagons : cratères ouverts depuis le toit (bord déchiqueté), intérieur éventré, roussi ; les parties détachées du châssis tombent. Calcul à la résolution affichée (22–124ms par stade, contre178–285ms auparavant pour la locomotive).
- [x] Gravité des armes : sur un wagon touché, l'arme tombe dans la brèche, inclinée, masquée par la paroi avant restante ; à la destruction elle est soulevée, tournoie et retombe couchée dans l'épave (`validation/opus-gun-fall-20261001.mp4`, dégâts forcés pour la revue).
- [ ] Animaux, fantassins, espions : animation et lecture du combat à reprendre (demande du propriétaire, 1er octobre).
- [ ] Canon vu de dos encore trop trapu : asset dédié souhaitable (comme gatling.png).
- [ ] Coût CPU au pic de charge : médiane3,7ms, mais p9510,1–10,5ms et max ~16ms (référence précédente7,0/7,2ms). À optimiser.
- [ ] Soldats : déplacement encore case par case ; interpolation de présentation à faire.
- [ ] Facteurs de cadence (×2, ×1,5) à valider par le propriétaire en jeu.
- [ ] Export, lancement Windows, acceptation artistique : non faits.

Preuves : `validation/opus-combat-motion-20261001.mp4` (×2), `validation/opus-rocket-motion-20261001.mp4` (cadencé, jusqu'à l'impact), `validation/opus-combat-model-20261001.json` (état source à ×1).

### Release intermédiaire privée, 1 octobre 2026

- [x] Suite complète `game/test.sh` : 65 suites PASS, sortie 0.
- [x] `tools/build_preview.py all` : `builds/Transartica-macOS.zip` (187011767 octets, sha256 b8082bea…) et `builds/Transartica-Windows.zip` (157834697 octets, sha256 c5f993ad…), voir `builds/manifest.json`.
- [x] App macOS exportée lancée nativement : fenêtre titre affichée, aucune erreur de script après6s.
- [ ] Windows : exporté sur macOS, exécution sur Windows non vérifiée.
- Builds privés (données historiques) : non publiés sur GitHub. Code poussé sur `feat/living-effects` avec PR vers main.

## Corrections après merge, 2 octobre 2026

- [x] Corriger la sélection des wagons mobiles et pendant les secousses.
- [x] Corriger le cache de matière/paroi/profil lorsqu'une épave remplace le sprite original.
- [x] Garder le même transform pour corps, labels et lumières pendant les secousses.
- [x] Rendre le test chaudière déterministe face à la pause de perte de focus, sans changer la pause de production.
- [x] Vérifier les64 suites Godot et33 tests Python, campagne complète et sauvegarde/reprise incluses.
- [x] Vérifier que les assets, shaders, animations et rythmes d'Opus sont conservés.

Reproductions natives rouges avant et vertes après. [Rapport des corrections](combat-regression-fixes-20261001.md).
Corrections publiées sur main le 2 octobre au commit `3f8efc62622764856a351076c3b19a083466b220`, SHA distant vérifié.
Nettoyage protégé : liens privés non suivis et aucune PR liée au worktree de corrections.
[Preuve de publication et nettoyage](validation/combat-fixes-push-20261002.md).

## Mammoth howdah fall sheets for Opus — 2 October 2026

- [x] Read fall handoff and inspect all six mammoth references and trooper direction.
- [x] Inspect mounted howdahs: visible colored forms are seat backs/cushions; no human head or limbs identified.
- [x] Generate separate howdah/debris and rider-fall sheets in blue and olive.
- [x] Measure PNG alpha and SHA256; append exact prompts and update gallery/handoff.
- [x] Verify deliverable files and document production limitations.

Scope: generated source sheets and documentation only; no runtime changes or Git mutations.

Review: [fall delivery](handoff-mammoth-howdah-fall-codex-20261002.md), four generated source sheets. Solid alpha, exact grids, source scale and pivots are not normalized; no integration or artistic acceptance claimed.

## Réparation des hooks Codex — 2 octobre 2026

- [x] Vérifier l’inventaire natif et reproduire les échecs de dépendances.
- [x] Corriger le démarrage Hypermnesia et sa reprise SessionEnd ;134 tests ciblés passent.
- [x] Aligner la configuration installée ; inventorier les28 hooks dans les quatre dépôts.
- [x] Approuver globalement les11hooks Hypermnesia après autorisation du propriétaire et capturer leurs événements natifs.
- [ ] Atteindre zéroHookfailed : disk-hygiene et statusline corrigés ; approbation native du nouveau hook statusline en attente.
- [x] Commiter et partager les corrections : Cortex PR658, Session Optimizer PR56, SHA distants vérifiés.
- [x] Conserver les résultats et nettoyer les captures et tests temporaires.

Revue : [réparation Codex](codex-hooks-repair-20261002.md). Deux démarrages directs réussis en7,302s puis1,057s ; livraison native encore non prouvée.

- [x] Autorisation statusline globale reçue et appliquée via /hooks ; nouvelle session native : 20 hooks réussis, zéro failed observé. PreCompact et sous-agents restent non vérifiés. Les deux PR ont leurs checks verts.

## Reprise masques et jeu, 3 octobre 2026

- [x] Retrouver les huit SVG refusés et les découpes non intégrées.
- [ ] Nettoyer les franges colorées et le décor résiduel des découpes transparentes ; examiner la registration.
- [ ] Brancher les découpes raster et leur alpha sur la surbrillance des deux intérieurs.
- [ ] Vérifier captures natives, clics et navigation ; laisser l’acceptation artistique ouverte.
- [ ] Reproduire puis corriger les dysfonctionnements indiqués par le propriétaire, sans remplacer les effets d’Opus.

Reprise du 3 octobre : huit PNG candidats générés, cinq défauts natifs reproduits. Référence native des surbrillances et parcours boudoir passent ; les SVG refusés restent actifs jusqu’à correction des PNG. Finition raster locale et reproduction des dysfonctionnements attendent les réponses du propriétaire. Voir wagon-cutouts-resume-20261003.md.

Revue des découpes du 3 octobre : propriétaire valide six couches ; table/carte du quartier général et revolver refusés. Ne retoucher que ces deux éléments. Activation et contrôle natif des couches acceptées restent à faire.

- [x] Corriger localement table/revolver après autorisation ; RGB source et alpha binaire vérifiés indépendamment.
- [x] Brancher les huit PNG et vérifier le parcours boudoir natif.
- [ ] Revue artistique finale table/revolver ; cinq assertions strictes des autres couches inchangées restent rouges.

- [x] Acceptation artistique des huit découpes reçue : « bon comme ca », 3 octobre. Version conservée.
- [x] Recevoir les dysfonctionnements précis du voyage et les reproduire par les entrées du jeu.

## Boucle de voyage signalée par le propriétaire, 3 octobre 2026

- [x] Reproduire par les entrées du jeu : aiguillages ignorés, invitation de ville avant la gare et train hors champ.
- [x] Corriger les causes dans le trajet, l'arrivée et la caméra en conservant les règles ECS et les effets d'Opus.
- [x] Afficher l'état effectif du frein et le sens de marche dans les commandes du bas.
- [x] Vérifier un trajet natif avec aiguillage, arrivée, départ et événement de campagne ; enregistrer les résultats et limites.

Revue : [voyage, gares et commandes](travel-regressions-20261003.md).85 sites/170 approches natives avant/arrière réussissent ; les45 villes fixes et les nomades sont couverts. Seize suites ciblées passent. Les planches des arrivées et terminus ont été inspectées. Les essais utilisent des approches préparées sur la carte source ; une partie native continue de toute la campagne et une release Windows stable ne sont pas établies.

## Partie continue et acceptation du jeu, correction du 3 octobre

- [x] Lancer la scène normale et démarrer une nouvelle partie par son interface.
- [x] Conduire depuis le départ réel : chauffe, régulateur, frein, sens et aiguillages, avec captures.
- [x] Entrer à In Salah, repartir jusqu'à Taoudeni et acheter une unité de sel dans cette même partie.
- [ ] Parcourir les événements et objectifs de campagne sans injection de position, ressources ou progression.
- [ ] Vérifier sauvegarde et reprise de cette partie, puis la fin et les fonctionnalités restantes.
- [ ] Documenter chaque étape observée, les défauts, le temps réel et le temps du jeu. La validation exhaustive reste ouverte.

- [x] Corriger la disparition réelle en marche arrière ; enregistrer le test échouant avant et réussissant après.
- [x] Rejouer un parcours depuis START jusqu'à In Salah en avant puis en arrière, par les seules commandes du joueur.
- [x] Fournir le scénario rejouable avec synchronisation d'écran, timings et reprise de sauvegarde.
- [x] Corriger la réduction des dessins modernes du commerce ; vérifier16 marchandises et25 wagons, puis inspecter Taoudeni en jeu.
- [ ] Expliquer le clic d'aiguillage perdu dans la répétition : tuile18 inchangée, attente expirée. Le pilote vérifie maintenant la sélection avant de démarrer ; deux parcours suivants passent, sans preuve de la cause du clic perdu.

Revue : [parties natives et procédure de reprise](validation/continuous-play-20261003/README.md). Le scénario START prend192,43 secondes réelles. La reprise de la partie à Taoudeni prend11,83 secondes. Ces mesures concernent ces parcours ; la durée de contenu et la campagne complète restent non validées.
## Contrat de playthrough complet et releases par acte, 3 octobre 2026

Le propriétaire rappelle que la campagne doit être entièrement jouée par l'agent.
Un parcours ciblé n'autorise pas l'arrêt du travail. Chaque bug rencontré est
corrigé, puis le parcours reprend depuis la sauvegarde gagnée. Les tests du modèle
et la vérification visuelle sont exigés ensemble. Les actes ci-dessous sont des
jalons de livraison tirés des gates ECS, pas de nouveaux chapitres de l'histoire.

- [x] Acte1 : économie et équipement gagnés, travaux, foreuse de Rum, rencontre d'Urga par le trajet réel. Sauvegarde/reprise et release macOS locale testée (8504,8517,8671 ; lot442da70).
- [ ] Acte2 : recrutement et envoi de l'espion, voyage au Mausolée et lecture du document. Sauvegarde/reprise et release locale testée.
- [ ] Acte3 : harpon, baleine, Oslo et code, sabotage confirmé de la centrale. Sauvegarde/reprise et release locale testée.
- [ ] Acte4 : préparation du convoi, accès secret, Himalaya, Minotaure et finale jusqu'à OPTIONS. Sauvegarde/reprise et release locale testée.
- [ ] Couverture restante : chaque gare/ville en avant et en arrière par les commandes, commerce et événements rencontrés ; aucun bug ouvert avant clôture.
- [ ] Pour chaque release : tests applicables verts, captures inspectées, manifeste des changements et preuve du lancement du paquet sur la plateforme annoncée.

Reprise : sauvegarde native CONTINUE obtenue après l'achat de sel à Taoudeni.
Le journal du voyage depuis START et les sauvegardes privées restent conservés.

Branche locale fix/combat-regressions basée sur main6dca252 ; aucun push dans cette tâche.

### Mouvement de présentation des acteurs, 2 octobre 2026 — non accepté artistiquement

- [x] Glissement continu entre cases à la période source mesurée (passe = 7×colonnes / max(colonnes/4,40) ticks ; 1, 2 ou 4 passes par case selon camp et type). Avant : saut de 16 px toutes les 1,1–4,5 s.
- [x] Foulée (rebond), arrêt sur appui, orientation selon le déplacement (miroir), accroupissement à la pose de dynamite (poses 2/6 mesurées), fente et éclair en mêlée, fondu de disparition sans retarder la perte d'effectif ; saut sans glissade aux discontinuités (embarquement, restauration, fusion).
- [x] Miroir : un rectangle à largeur négative ne déplace pas sa position ; corrigé et vérifié par capture native (`test_tactical_actor_mirror`), clic et sélection sur le corps affiché.
- [x] Modèle intact : modèle piloté par la scène identique au modèle nu (`test_tactical_actor_motion`). Suite complète 68 PASS.
- [ ] Orientation : l'original dessine les acteurs au sol en tuiles (cputmap98) et ceux des toits en sprites 10+case ; son orientation n'est pas décodée. Le miroir est une présentation provisoire, pas une preuve des huit caps.
- [x] Retour du propriétaire (2 octobre) : « pas un sprite qui glisse avec 4 images ». Remplacé par un rig procédural découpé dans le soldat debout de Codex (`assets/combat/trooper-rig.png`, outil `game/tools/build_trooper_rig.gd`) : buste avec bras et fusil, deux pans de manteau, bottes ; jambes en cinématique inverse vers des pieds plantés (glissement mesuré < 0,05 px pendant l'appui).
- [x] Choix du propriétaire : sprint puis attente (case franchie en ~0,8 s, freinage sur la case, attente du pas source), plusieurs soldats visibles par groupe (jusqu'à 4).
- [x] Mêlée : coups et reculs ; chaque perte fait tomber un soldat, un par un (0,3 s d'écart), selon trois chutes (à la renverse, effondrement en avant, titubement puis chute) ; un camarade vient combler le rang ; les corps restent 3 s.
- [x] Dynamite : le meneur court à la case, caisse en main, s'agenouille, pose, allume (mèche qui crépite), se relève et revient.
- [x] Embarquement : course jusqu'à l'échelle en bout de wagon, escalade, rétablissement, course sur le toit ; les hommes transférés au toit ennemi partent de leur groupe d'origine.
- [ ] Revue du propriétaire en lecture native : cadence, taille, chutes, dynamite, montée. Vues avant/arrière absentes (miroir provisoire). Mammouths sans rig.
- [ ] Mammouths, loups, espions : hors de cette étape (planche mammouth à simplifier ; loups et espions hors effectif tactique).

Preuves : `validation/actor-motion-glide-20261002.mp4` (avant correction du miroir), `validation/actor-motion-troopers-20261002.mp4` (atlas à 4 images, rejeté), `validation/trooper-rig-20261002.mp4` (rig en combat, 8 s), `validation/trooper-actions-20261002.mp4` (morts, dynamite, montée mises en scène, modèle figé).

## Sprite-animated mammoths — 2 October 2026 (branch feat/mammoth-motion)

First integration of Codex's mammoth sheets; not owner-accepted. Builder
`game/tools/build_mammoth_poses.gd` (helpers `mammoth_sheets.gd`) writes
`game/assets/combat/mammoth-poses.png` and the generated table
`game/scripts/tactical_mammoth_frames.gd`; hashes, scales and measurements in
`output/imagegen/actors-20261002/mammoth-poses-runtime.json`; recording and close-ups in
`tasks/validation/mammoth-actions-20261002.mp4`, `mammoth-actions-contact-20261002.png`,
`mammoth-closeups-20261002.png`.

- [x] Walk 8 frames driven by distance (stepped, hooves still while a frame shows), stop, melee, hit, death (8 bare / 5 howdah), rider layer min(count-1, 2), blue and olive.
- [x] Dismount of riders stepping off a howdah (stand, leg over, hang, drop, land) before the run to the wagon; review fixture lands them on a wagon, not the locomotive.
- [ ] Owner acceptance of the mammoth sprites (scale, gait speed, rider size).
- [x] No `-v2` sheets: Codex confirms the howdah sheets hold no rider silhouettes (seat backs only).
- [ ] Howdah and rider fall physics (the rider death frames are authored arcs of the merged pairs).
- [ ] `tactical_actor_motion.gd` is 830 lines (740 before this work): split boarding, dynamite and drawing out of it; `tactical_actor_art.gd` now has no runtime caller (mirror test and review script only).

### Continuation native, 4 octobre 2026

- [x] Urga atteinte par le trajet réel, clé obtenue8504, sauvegarde8506/reprise8507.
- [x] Chargement de cette sauvegarde dans le package macOS corrigé8517 ; audio importé restauré.
- [x] Comparaison native de neige depuis sauvegarde acquise8655 ; compteur7812 visible au centre.
- [x] Mine19,47 par route alternative réelle via Tunis : ressources,165 anthracite crédités, reprise du résultat sans doublon et fermeture9003. Mine40,38 interrompue par combat perdu, conservé au journal.
- [x] Release macOS locale regroupant audio, berges, neige et extraction, SHA0989213d095d03d998a397b7f301c112e419df4272ca103cdfaa9df4cba4492b ; code publié442da70.

Lot précédent poussé sur main fc4e91d. La campagne complète et la couverture avant/arrière restent ouvertes. La défaite8662 après chauffe sans surveillance est conservée ; reprise prévue depuis NOMADS8655.

## Native continuation, 4 October 2026

- [x] Reach Berlin through real Bayreuth arrival, dialogues and departure.
- [x] Recruit a spy into the earned Gdansk spy wagon.
- [x] Send the spy, wait at a stopped train, and sabotage the central post.
- [x] Repair blank sabotage confirmation; rebuild macOS and visually check NO/OK.
- [x] Correct reversal phase in the read-only itinerary aid and prepare switches before resume.
- [x] Repair the modeled campaign save fixture and rerun both full routes.
- [ ] Reach Mausoleum for its clue and continue Oslo/whale/finale natively.
- [ ] Complete alternate campaign paths and all station forward/reverse coverage.

The current native run has not reached the ending. The modeled complete routes
do not replace this outstanding requirement. Native evidence10019..10137 and
`evidence/sabotage-confirmation.md`; itinerary proof in
`planner-reversal-phase-fix-20261004.md`.

## Underground passages reported missing, 4 October 2026

- [x] Trace source entrance/exit glyphs, shortcuts and underground risk rules.
- [x] Integrate six mouths and per-wagon underground tint; alpha0.75 chosen from valid prepared native comparisons. Player traversal acceptance remains below.
- [ ] Play real entry/traversal/exit forward and reverse; preserve replay timings.
- [ ] Check risk behavior with reproducible source comparisons and earned saves.

Owner observed no modeled underground passages. This is an open campaign and
visual acceptance requirement, not satisfied by ordinary connected rail tiles.

## Shared control corrections, 4 October 2026

Owner music direction: retain current original score during gameplay repairs;
an orchestral remake is deferred until later. Current score is not the accepted
final musical direction. Do not spend this validation phase replacing music.

- [x] Frame spy choices, sabotage NO/OK, OPTIONS labels and KEYS.
- [x] Expose overall map in engine, quarters and boudoir; return to actual caller.
- [x] Tests, source/craft gates and actual macOS viewport clicks inspected10468..10498.
- [x] Publish isolated verified lot2d0a92c9c90968cd9c31589bd256ca2b2eb2346d; remote SHA confirmed.

Native reverse raw10361 restores, but its attempted alternative route stops
at the actual terminus51,23 (10462..10464), not the Mausoleum53,32. No success
claim for this route. Draw diagnostics isolated heading-arrow and caption occlusion of the locomotive.
The correction is published as356bd49; native10582 shows the visible locomotive
and separated direction cue. Underground reverse traversal and the campaign
ending remain required. Native10904..11194 proves forward passage51,39 to113,58
and full emergence of all21vehicles at132,63 (cycles9233..9518).


Native underground pair51,39↔113,58 passed forward10904..11194 and
reverse11195..11447 with21rendered vehicles and preserved reversal contacts.
Root inspected full emergence captures11194/11447. Other two passage pairs,
Mole Men encounters and occupied-switch changes remain open.


- [x] Reproduce and correct late occupied switch49,39; original prepared contact
  divergence26.900955→0.0, source-compatible regressions and review pass.
- [x] Verify rebuilt macOS actual toggle11454, movement11455..11470 and normal
  named-book reload11473 with21contacts preserved.
- [x] Stop completed waypoint transit automation without restarting its leg;
  six detached Python protocol tests pass.
