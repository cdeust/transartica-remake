## Décision : train en vue de dessus (propriétaire, 26 septembre)

Réponse « oui » du propriétaire à : vue de dessus, wagons à l'échelle, redessinés ; abandon de la 3D et de
la perspective oblique pour les véhicules. Base : prototype Codex `output/imagegen/vehicles-overhead-prototype-v2.*`,
bancs `tasks/validation/review_overhead_{prototype,convoy}.gd`.

- [x] Intégrer la planche de dessus au voyage (rotation rigide, gabarit identique dans les 8 caps). Une
  seule image par véhicule (`game/assets/travel/vehicles-overhead.{png,json}`, produite par
  `tools/build_overhead_manifest.py` depuis le prototype accepté), tournée en continu vers la direction
  projetée du trajet réellement parcouru (`game/scripts/train_renderer.gd`) : la rotation rigide d'un
  raster ne peut ni l'étirer ni le cisailler, à n'importe quel angle, pas seulement aux 8 caps. La
  projection du voyage n'est pas isotrope (~206px/case est-ouest, ~141px/case SE/NO, ~255px/case NE/SO,
  vérifié depuis WORLD_EAST/WORLD_SOUTH) : `_bisected_rear` choisit par bissection (24 pas, borne fixe,
  pas une boucle de tolérance) la distance-monde de chaque véhicule pour que sa corde PROJETÉE reste
  constante, tout en gardant ses points de contact avant/arrière comme échantillons exacts du trajet
  (`journey.sample_behind`). Testé dans `game/tests/test_travel_world.gd` (rotation rigide à angle
  arbitraire, corde constante à travers un virage réel synthétique) ; un test de mutation (retour à un
  décalage fixe non projeté) fait échouer ces deux vérifications, confirmant qu'elles ne sont pas vaines.
  Limite connue : les longueurs mesurées dans l'planche acceptée sont presque uniformes (0.95-1.0) alors
  que le prompt demandait des longueurs différenciées (460/345/354/359/405/368px) — l'image livrée ne
  respecte pas cette partie de sa propre consigne ; voir le docstring de
  `tools/build_overhead_manifest.py`. Sens physique du canon/de la verrière d'observation (les deux
  pointent vers l'avant du convoi dans ce dessin) non vérifié contre une source — inchangé depuis
  `tasks/lessons.md`. Captures natives : `tasks/validation/overhead-train-{straight,curve,after-purchase}.png`.
- [x] Composition dessinée dérivée de la table des wagons (`train_wagons.gd`), un dessin par type ; 6 types initiaux d'abord.
  `train_consist.gd::derive_from_wagons` + `TYPE_TO_KIND` (positionnel, choix artistique du remake, documenté
  en commentaire — l'original a un sprite par type). Appelé depuis `main.gd` à l'initialisation, après
  `wagons.reset()` et dans `_on_cargo_changed()` (achat à l'atelier via `city_screen.gd::cargo_changed`) :
  plus de liste `consist` sauvegardée indépendamment (sauvegardes v7 : clé `"consist"` acceptée et ignorée,
  la composition est toujours redérivée de `wagons` à la restauration ; voir `main.gd::_restore_view`
  et le commentaire au-dessus de l'écriture de `state` dans `save_view`).
- [ ] Dessiner les 19 autres types (achat à l'atelier). `derive_from_wagons` les laisse volontairement
  non dessinés (pas de repli générique inventé) : un achat d'un type non mappé change `wagons.wagons`
  (masse, commerce) sans ajouter de véhicule visible. Capture `overhead-train-after-purchase.png`
  montre en revanche un type mappé (TENDER) ajouté visiblement après achat simulé + avance réelle du
  trajet (le nouveau wagon n'a d'historique de trajet qu'une fois le train avancé de sa propre longueur).

Note de propriété (Codex) : `main.gd` touché a minima aux points ci-dessus, plus une correction de la
garde de restauration de sauvegarde qui vérifiait la longueur de TOUT le convoi contre l'historique de
trajet décodé (~5.0 cases derrière START_POSITION, `train_path.gd::seed`) ; les nouvelles longueurs
LENGTHS (quasi uniformes) dépassaient cette marge dès le départ d'une partie neuve alors que le
renderer tolère déjà un historique partiel (`poses()` s'arrête proprement sans extrapolation). La garde
vérifie maintenant seulement la locomotive, seuil minimal cohérent avec ce que `poses()` accepte déjà.
`travel_world.gd` touché pour passer `self` à `train_renderer.poses()`/`screen_bounds()` (nécessaire pour
la bissection projetée) et retirer `train_pose(heading)`, mort avant même ce changement (aucun appelant
dans `game/`), dont la signature aurait sinon cassé sur l'API à un seul cadre par véhicule.

## Commerce en ville (26 septembre, Claude)

- [x] Masse des wagons décodée (TIME 0x2a77/0x2b4a) ; table des wagons et masse dynamique.
- [x] Règles glieu : marchandises, mammouths, esclaves, soldats, espions ; stocks sauvegardés.
- [x] Écran de ville : menu, transaction, refus, départ ; captures natives BHOPAL et KUWAIT.
- [x] Atelier des villes 10–16 (achat de wagons) : règles, écran, tests, captures natives (IN SALAH).
- [ ] Dessin des wagons achetés : types 1–25 sans correspondance décodable avec les 6 véhicules
  illustrés (l'original a un sprite par type) — décision artistique du propriétaire.
- [ ] Textes d'histoire (TOWN), gare-atelier, effets de l'équipage et des animaux.
Preuves : tasks/evidence/city-scripts.md §5–6 et « Portage ».
Note de propriété : `main.gd` (Codex) touché pour raccorder l'écran : champs de sauvegarde v7
(`wagons`, `trade`), validation avant restauration de session, masse depuis les wagons, touches de ville.

## Correction active : wagons sur les rails (captures propriétaire, 26 septembre)

Symptôme : rotation du convoi entier, arrière hors des voies aux virages ; perspective du sprite déformée.
Références : travel_world.gd::_draw_train/train_pose/update_train ; train_journey.gd::fractional_position/advance ; rail_glyphs.gd::ports_for_code.
But : chaque véhicule suit le trajet réellement parcouru et utilise une perspective dessinée pour son cap.
Stratégie : correction des coordonnées et rendu par véhicule, tests géométriques puis captures natives sur virage.
Hors périmètre immédiat : règles de commerce/combat non décodées.

- [x] Trajet continu sur les segments des rails, historique conservé pour les wagons et la sauvegarde.
- [x] Atlas par véhicule et cap, remplacement de la rotation globale ; recalage des contacts sur les rails.
- [x] Assemblage depuis la liste des véhicules ; ancrages sur la voie et composition sauvegardée.
- [x] Vérifications droite/virage/aiguillage, pause/reprise et captures natives : 9 suites Godot PASS.

## Codex sprite handoff — 26 September 2026

Owner request: "Vérifier si Codex a produit les images W/SE/NW/NE dans output/imagegen/, puis lancer uvpy tools/sprite_pipeline.py E=game/assets/travel/train-east.png W=… SE=… NW=… NE=… --out .cache/sprites et examiner contact-sheet.png."

Symptom: four perspectives are missing; rotation cannot supply the required perspective.
Goal: generate those views and validate them through Claude's existing pipeline.
Non-goals for this handoff: redesigning the accepted east image or changing combat rules.
Strategy: context engineering plus external verification with the sprite pipeline and contact sheet.
Ownership: Codex generates images and owns travel integration; Claude owns sprite_pipeline.py and pixel_field.gd, already delivered per checkpoint eda317cd.

- [x] Read Claude checkpoint, ownership note and existing directional prompts; four images absent.
- [x] Generate W, SE, NW and NE from the accepted east reference.
- [x] Pipeline : 5 caps OK, avertissements de largeur SE/NW conservés. Images complètes devenues références après passage aux atlas par véhicule.
- [x] Passation dans tasks/handoff-codex-sprite-fixes.md.

## Reprise Claude — 26 septembre (incident de connexion Codex)

- [x] Frein de service progressif (−5/cycle, régulateur conservé) ; preuves dans evidence/braking-rules.md.
- [x] Circulation sur tout le réseau : règles TIME décodées (evidence/rail-network.md), game/scripts/rail_network.gd, train_journey.gd v2, aiguillages cliquables et sauvegardés. 8 suites PASS.
- [x] Vue oblique pixel art restaurée (référence propriétaire), caméra fixe avec recentrage en bord d'écran, rails depuis le réseau vivant, aiguillages cliquables. L'ancienne vue de dessus plate de la carte (« cheap view ») est abandonnée ; ne pas confondre avec la vue de dessus des véhicules retenue le 26 septembre (section « Décision : train en vue de dessus »).
- [ ] Sprites du train pour W, SE, NW, NE (S, N, SW par symétrie) : prompts dans output/imagegen/travel-train-headings-prompt.md. En attendant, les diagonales utilisent une rotation, rejetée par le propriétaire (« adapter la perspective »).
  - [x] Claude : `tools/sprite_pipeline.py` contrôle, met à l'échelle et ancre chaque image générée, puis écrit le manifeste des 8 caps. Mode d'emploi et constats (échelle NE/SE, ancres, intégration) : tasks/handoff-sprites.md.
  - [x] Claude : module autonome `game/scripts/pixel_field.gd` (fumée, vapeur, neige, étincelles, débris, lueur additive ; inspiré de Noita), testé, non raccordé à la scène. Même note de passation.
- [ ] Combats « respectant la carte initiale du train » : demande à préciser.

## Correction active : véritable scène de déplacement

- [ ] Remplacer la carte de banc par terrain glaciaire et train en vue oblique.
- [ ] Intégrer commandes, brouillard et déplacement existants sans changer le réseau.
- [ ] Vérifier visuellement zoom, suivi, lisibilité et exports.

## Priorité active : première boucle de déplacement testable

Les retouches de survol sont reportées par le propriétaire (25 septembre, 23h).

- [x] Relier la circulation prouvée à chaque cycle de simulation (corridor initial uniquement).
- [x] Conduire depuis la carte, suivre le train et découvrir les cases traversées.
- [x] Sauvegarder position, direction et progression sur le segment.
- [x] Vérifier déplacement, consommation et frein en fenêtre native; panne, pause et reprise dans les tests.
- [ ] Reconstruire les paquets et documenter les frontières encore non portées.

## Chaufferie interactive : intégration autorisée

- [x] Séparer le décor et les sprites des chauffeurs de la maquette.
- [x] Animer foyer, vapeur et chauffeurs selon les états réels.
- [x] Placer les commandes dans la machinerie et les compteurs dans le bandeau.
- [x] Faire tourner la simulation indépendamment du rendu, avec pause et sauvegarde.
- [x] Vérifier la boucle chauffe / accélération / freinage dans le paquet macOS.
- [x] Reconstruire les distributions et consigner les limites de fidélité.

Le propriétaire autorise l'intégration de la direction illustrée. Les calculs
prouvés sont conservés. Toute cadence non encore vérifiée sera identifiée comme
calibration de préversion, sans prétendre reproduire le temps original.

## Correction de direction artistique : référence Noita et interface Amiga

- [x] Examiner les captures originales de chaufferie et de quartier général.
- [x] Produire une maquette illustrée de la chaufferie avec composition originale.
- [x] Conserver image, prompt, référence et limites dans output/imagegen/.
- [x] Transformer la direction retenue en assets distincts et animations.
- [x] Intégrer les commandes dans la machinerie et le bandeau inférieur.
- [x] Vérifier le rendu de jeu réel ; ne pas confondre maquette et implémentation.

## Priorité corrigée par le propriétaire : jeu de gestion fidèle

- [ ] Relier les commandes de conduite aux déplacements et à la consommation prouvés dans l'original.
- [ ] Établir les états de ressources, monnaie, personnel et moral depuis leurs sources.
- [ ] Relier une première étape de campagne originale à des actions réellement jouables.
- [x] Remplacer la grille diagnostique par une carte lisible ; reprendre décor glaciaire et rails.
- [ ] Vérifier une boucle jouable avant de présenter une nouvelle version comme un jeu.

Le train dessiné est conservé. Les choix visuels ne remplacent pas la simulation.
Références : scripts originaux TIME/TRAIN/TABLE, INVENTAIRE.md, FIDELITE.md,
CAMPAGNE-SOURCES.md ; carte actuelle world_view.gd, décor/rails cab_vignette.gd.

## Amélioration visuelle demandée

- [x] Remplacer le train schématique par une locomotive détaillée et un paysage pixel art.
- [x] Agrandir la scène et harmoniser encadrement, carte et panneaux.
- [x] Inspecter le rendu réel et refaire les exports testables.

Références : `game/scripts/cab_vignette.gd` (dessin), `main.gd` (composition),
`world_view.gd` (carte). Symptôme : visuel trop sommaire. But : qualité graphique
supérieure, sans modifier les règles ou les coordonnées. Stratégie : modification
ciblée des dessins natifs puis vérification visuelle et tests exécutés.
Critères : locomotive et décor lisibles à la taille de jeu, pixels nets, interface
sans chevauchement, tests Godot verts et paquet macOS testé après export.

# Livraison autonome — 25 septembre 2026

- [x] Regrouper tout le projet dans Developments/Transartica.
- [x] Vérifier les 10 tests après déplacement.
- [x] Décoder 46 enregistrements de villes depuis les scripts ; 43 concordances indépendantes.
- [ ] Produire la spécification proportionnée via prd-gen : runner arrêté sur connecteur codebase absent, voir spec-pipeline.json.
- [x] Livrer une première préversion d’exploration avec train pixel art animé et commandes de lancement.
- [x] Vérifier lancement natif, recherche/sélection, pause, sauvegarde/reprise et horloge indépendante du rendu.
- [x] Exporter le paquet Windows ; binaire PE x86-64 vérifié, exécution sur Windows non vérifiée.
- [ ] Reconstituer navigation, commerce, combat et campagne complets selon FIDELITE.md.

Tous les nouveaux fichiers de travail restent dans ce dossier, y compris téléchargements,
caches et exports. Les travaux historiques ci-dessous décrivent leurs états successifs.

# Recherche Transarctica — 24 septembre 2026


## Suite autorisée : règles et campagne

- [ ] Tracer les consommateurs des tuiles et les règles de circulation.
- [ ] Décoder les tables de villes et de commerce avec leurs traitements originaux.
- [ ] Identifier les conditions de la centrale et les déclencheurs de fin dans les scripts.
- [ ] Rendre l’observation du jeu reproductible et conserver les résultats hors des fichiers temporaires.
- [ ] Intégrer les formats prouvés à des outils testés ; garder les inconnues explicites.

Critère : chaque règle retenue doit citer le script, son offset, le traitement ALIS et une vérification sur les données. Aucun raccord inventé pour faire correspondre le guide.

## Travail du 25 septembre : carte et fin de campagne

- [x] Retrouver le format de la grille CARTE.FIC par le moteur et le script d’origine ; VILLE/COMMERCE restent ouverts.
- [x] Construire le décodeur, exporter JSON/CSV et visionneuse ; rendu navigateur non vérifié, contrôle logique JavaScript réussi.
- [x] Comparer les codes aux 44 coordonnées indépendantes : 43 concordances, Tibesti à vérifier.
- [x] Recouper les informations documentaires sur la centrale et la fin ; observation en partie toujours requise.
- [x] Conserver commandes, extraits de bytecode, résultats et limites dans FORMAT-CARTE.md.

Autorisation : le propriétaire demande de démarrer la suite. L'analyse de carte et la recherche de fin sont indépendantes et déléguées de façon bornée lorsque cela économise du contexte.

## Travaux précédents

- [x] Consulter Cortex et rechercher les précédents pertinents (aucun résultat pertinent retenu).
- [x] Identifier le jeu et les ressources de préservation.
- [x] Relever les mécaniques du manuel transcrit et repérer les scans pour comparaison approfondie.
- [x] Examiner les remakes existants et la gestion du temps de simulation.
- [x] Livrer un dossier sourcé, distinguer faits, propositions et inconnues.
- [x] Recueillir les préférences de plateformes, fidélité et diffusion avant une spécification de développement.
- [x] Consigner les critères de fidélité et de complétude dans FIDELITE.md.
- [x] Identifier l'édition originale de référence : Amiga 500 ECS.
- [x] Préciser la langue : anglais. Le propriétaire ne dispose plus des disquettes.
- [x] Trouver une archive ECS exploitable avec menu anglais et relever sa provenance ; comportement en partie non vérifié.
- [ ] Constituer les inventaires vérifiables de la carte et de la campagne.
- [x] Trouver un parcours décrit jusqu'à la fin et consigner ses limites dans CAMPAGNE-SOURCES.md.
- [x] Récupérer et inspecter une archive présentée comme ECS : deux disquettes, listes de fichiers et empreintes conservées ; langue et comportement non vérifiés en exécution.
- [x] Relever les 44 villes du guide dans un CSV et vérifier sa structure.
- [x] Livrer le premier inventaire mécanique et le parcours documentaire de campagne.
- [ ] Décoder les fichiers candidats de carte/villes/commerce en s'appuyant sur leur traitement dans le jeu.
- [ ] Vérifier le déroulement final et l'interaction à la centrale par observation.

## Périmètre

Recherche et cadrage de la refonte. Aucun code de jeu ni choix artistique définitif à ce stade. Un sous-agent Luna effectue la recherche sur les mécaniques ; l'orchestrateur vérifie la faisabilité et synthétise. Les questions de cadrage ont été envoyées pendant la recherche.

Le propriétaire a depuis confirmé : ECS anglais, pixel art moderne, fidélité carte et histoire, clavier/souris actuels, multiplateforme avec priorité Windows, gratuit et code créé sous MIT. Le cadrage ne bloque plus sur la révision exacte.

## Revue

Dossier local livré. Sources primaires techniques vérifiées : Godot, FS-UAE, WHDLoad, ALIS et projet SourceForge. À cette première étape, aucun jeu lancé ni benchmark exécuté. Inventaires exhaustifs, formules et campagne complète restent à relever. Préférences du propriétaire consignées ; question sur l'édition de référence envoyée.

25 septembre : inventaire sélectif relu, 44 villes sans doublons de nom ou coordonnées, archive ZIP sans erreur CRC, deux systèmes de fichiers listés avec amitools 0.8.1, trois fichiers de données extraits localement. Lors de cette première inspection, aucun jeu lancé. Voir OBSERVATION-ECS.md pour les preuves et limites.

Suite du 25 septembre : ALIS compilé et démarrage observé jusqu’au menu des langues ; sélection anglaise non validée. MAIN.CO décompressé, dimension 73 déclarée identifiée ; carte de 160 × 73 cases, rangement en colonnes, 43/44 positions du guide sur codes 71–76. VILLE.FIC reste non décodé. Voir FORMAT-CARTE.md et FIN-CAMPAGNE.md.

Validation : 4 tests Python passent, dont l’oracle sur archive réelle ; roundtrip du JSON vers CARTE.FIC exact ; contrôles JavaScript sur DOM simulé réussis. Le rendu navigateur reste à contrôler.

## Dernier point de reprise

Préversion autonome exportée dans builds/ ; voir tasks/validation/release-status.json.
18 tests documentaires passent, ainsi que les tests Godot et le test de reprise
du binaire macOS exporté. Windows est exporté mais non exécuté sur Windows.
Le contrôle natif a vérifié recherche, sélection, pause, sauvegarde et reprise.

Suite fidèle : relier les deltas TIME documentés dans
tasks/evidence/navigation-next.md aux conditions de circulation, puis établir
commerce, combat et campagne. Ne pas confondre ce jalon d'exploration avec un jeu
complet. La carte est conservée octet pour octet ; sa palette reste diagnostique.


## Revue de la correction gestion / univers glaciaire

- [x] Conserver la locomotive ; remplacer ciel étoilé, conifères et sommets réguliers par reliefs glaciaires, strates, congères et neige ventée.
- [x] Rendre la grille brute optionnelle, afficher noms et coordonnées des lieux sans inventer de réseau.
- [x] Décoder stocks, commandes de chauffe, réserve, accélération, frein et masse des six wagons de départ.
- [x] Intégrer ces calculs dans un banc de conduite avec pas manuel, onglets carte et journal.
- [x] Tester les vecteurs originaux et les commandes par l'interface native.
- [ ] Établir la cadence TIME et raccorder circulation, obstacles et événements.
- [ ] Porter commerce, effectifs et progression de campagne. Le moral reste non attesté.

Le banc est un progrès de simulation, pas une boucle jouable complète. Aucune
campagne complète ni déplacement ferroviaire n'est revendiqué. Voir
`tasks/evidence/locomotive-rules.md` et `tasks/validation/engine-room.md`.

## Revue du rendu par véhicule, 26 septembre

Captures natives : tasks/validation/modular-train-{start,east,diagonal,overview}.png. Les tests géométriques couvrent 48 couples type/cap, virage analytique, interpolation par distance parcourue, composition variable et sauvegarde. Caméra fixe jusqu’à sortie du convoi du viewport, recentrage vers la marge intérieure.

Limites : atlas artistiques à calibrer visuellement entre les caps ; les miroirs changent le côté de lumière. Armement encore inclus dans le sprite du wagon blindé, séparation de la tourelle et armes interchangeables à faire. Achat de wagons et combat ne sont pas implémentés par cette correction du rendu. Anciens saves sans historique ambigu : aucun chemin arrière inventé. Les exports ne sont pas reconstruits.

## Train modulaire : échelle unique et vitesse régulière — 26 septembre 2026 (Claude)
- [x] Échelle unique sans étirement, placement par le milieu, LENGTHS recalées sur les ancres E (4,98 cases), vitesse constante sur les trois phases. 9 suites PASS. Détails : tasks/handoff-sprites.md, dernière section.
- [ ] Voitures SE (et, moins, NW) dessinées trop hautes dans l'atlas : « étirées vers le sud » (propriétaire). Correction dans les images, pas dans le rendu.
- [ ] Atlas NE ~15 % trop court : jours entre voitures en NE/SW.

## Atlas SE / NW : reprise Codex, 26 septembre

- [x] Lire le handoff Claude et conserver son rendu à échelle uniforme.
- [x] Régénérer les deux planches en raccourcissant la profondeur des toits.
- [x] Mesurer les silhouettes et vérifier les extrémités des véhicules.
- [x] Intégrer les planches retenues, vérifier les tests et le rendu natif SE.

Revue : 9 suites Godot passent. Capture native dans
`tasks/validation/modular-train-foreshortening-southeast.png` et mesures dans
`tasks/validation/foreshortening-measurements.json`. Les hauteurs SE lits/fourgon
restent à 173/172 px, contre les estimations de boîte 158/163 d'Opus. Ce modèle
est une cible artistique approximative. Le contrôle natif du trajet NW reste à faire.

## Tentative retirée : normalisation par cap, 26 septembre

- [x] Remplacer le critère de dimensions physiques par la même longueur visible à l'écran pour chaque véhicule, quel que soit son cap.
- [x] Mesurer les silhouettes PNG dans leur axe et appliquer une normalisation isotrope fixe par dessin, sans dépendance au virage.
- [x] Espacer les véhicules le long de l'arc projeté des rails ; garder les distances de simulation inchangées.
- [x] Supprimer le zoom automatique en déplacement ; choisir le zoom initial sans dépendance au cap.
- [x] Vérifier les 48 couples véhicule/cap, le virage analytique et le cas du convoi plus grand que la fenêtre.
- [x] Produire le comparatif natif `tasks/validation/sleeper-eight-headings-constant-length.png`.

Contrat et méthode : `tasks/screen-length-contract.md`.
La normalisation conserve le rapport largeur/hauteur de chaque dessin. Elle ne
rend pas identiques les détails artistiques entre atlas. La longueur est mesurée
sur l'étendue du masque alpha dans l'axe du véhicule, avec arrondi de rasterisation
au pixel lors de l'affichage. À fort zoom manuel, le train peut dépasser la fenêtre.

## Correction après rejet du grossissement vers le bas

Le propriétaire rappelle que le raccourcissement perspectif était exclu dès le
départ. La tentative précédente reste invalide malgré ses tests de longueur :
elle agrandit aussi la largeur des vues de face. Rendu et espacement de cette
tentative remis dans leur état précédent ; les atlas SE v3 / NW v2 restent en
place. Le défaut visuel n'est pas déclaré corrigé.

- [x] Retirer la normalisation par cap et fermer sa fenêtre de test.
- [x] Présenter un prototype de dessin de dessus tourné rigidement, avec le même gabarit complet dans les huit caps. Fenêtre native `review_overhead_prototype.gd`, touches 1 à 6 ; capture `overhead-prototype-eight-headings.png`.
- [ ] Faire confirmer ce changement de vue avant remplacement du dessin accepté.

Reprise après revue de session-optimizer PR44 : revue livrée dans
`/Users/cdeust/Developments/.reviews/session-optimizer-pr44-8de3910/.review/REVIEW.md`.
Fenêtre prototype de dessus ouverte, touches 1 à 6. Choix de présentation
demandé au propriétaire : vue de dessus à gabarit invariant, ou maintien de
l'aspect oblique accepté avec reprise des dessins directionnels. Ne pas
intégrer le prototype avant sa réponse.

## Reprise après PR44, 26 septembre (Codex)

- [x] PR44 corrigée et fusionnée : 52fe5935218b719a92b1f60f967b6b1300471fcf.
- [x] Context Guard 2.1.0 installé dans Codex, Stop/SubagentStop approuvés, ancienne version retirée, seuils Astra vérifiés 180000/220000.
- [x] Étendre le prototype séparé au convoi complet en mouvement, à gabarit invariant.
- [x] Examiner le rendu natif : `review_overhead_convoy.gd`, capture `overhead-convoy-loop.png`, 48 poses vérifiées. Espace met en pause ; R inverse le déplacement sans retourner les caisses.
- [ ] Choix visuel encore en attente : la vue de dessus reste une proposition séparée, non intégrée au jeu.

## Reprise Codex : gabarit oblique, 26 septembre

Reprise demandée sans choix explicite de la vue de dessus : conserver l'aspect
oblique accepté. Ne pas interpréter cette reprise comme une validation artistique.

- [x] Relire checkpoint, handoff, contrat et atlas actifs.
- [x] Mesurer les deux dimensions des silhouettes sources à échelle fixe.
- [ ] Produire une nouvelle planche SE sans raccourcissement, guidée par ces mesures.
- [ ] Comparer les deux dimensions et les contacts avant toute intégration.
- [ ] Vérifier le rendu natif et consigner les limites restantes.

Les mesures portent sur le masque alpha >=128, comme le précédent outil de
mesure, projeté dans l'axe des ancres et sa perpendiculaire. La largeur ainsi
mesurée inclut les côtés visibles et les accessoires ; elle ne représente pas
la largeur physique de la caisse. Ne pas confondre cette mesure avec une
validation artistique. Aucun facteur de normalisation n'est réintroduit.

### Résultat de la reprise : zoom de voyage

- [x] Reproduire le zoom automatique dans `_keep_train_in_view` : trois assertions échouaient avant correction.
- [x] Supprimer la réduction automatique. Si le convoi dépasse la fenêtre, conserver le zoom choisi et recentrer sur sa tête seulement lorsqu'elle sort de l'écran.
- [x] Quatre suites passent : caméra, travel_world, trajet jouable, interactions.
- [x] Lancement natif OpenGL macOS réussi ; capture `tasks/validation/camera-scale-native.png`. La petite fenêtre du banc montre volontairement un train tronqué à zoom conservé.
- [x] Mesures des 30 dessins sources archivées avec SHA256 dans `tasks/validation/vehicle-dimensions-baseline.json`; contrôles analytiques de l'outil réussis.
- [x] Deux nouvelles planches SE générées et examinées ; toutes deux écartées, aucune intégration. v1 conserve un axe diagonal ; v2 ne respecte pas le canevas demandé. Voir `tasks/validation/gabarit-generation-review.json`.
- [ ] Corriger les dimensions et les contacts des atlas obliques : toujours ouvert. Les tentatives de génération ne prouvent pas un gabarit invariant.

Les atlas et la normalisation du rendu restent inchangés. Seul le comportement
de caméra est corrigé dans le jeu source ; exports non reconstruits.
Suite : `tasks/checkpoint-codex-camera-2026-09-26.md`.

## Gares et villes jouables — 26 septembre 2026 (Claude, Codex arrêté : Claude possède tout le jeu)
Preuves : tasks/evidence/station-arrival.md.
- [x] Chaîne décodée : TIME 0x26fb (index de ville) → message 76 → yoda 0xdae (scène ville, glieu + ville/usine/mamesc) → glieu message 9 → yoda 0x18e3 (demi-tour, vitesse 0).
- [x] ALIS copié dans .toolchain/alis/ (les builds de /private/tmp ont disparu le 26 septembre, avec la trace de ville).
- [x] Porter l'arrivée : écran de ville (nom, type), départ par demi-tour prouvé. 10 suites PASS, captures natives station-*.png.
- [x] Présentation après demi-tour (propriétaire) : le convoi ressort de la gare derrière la locomotive.
- [ ] Gares sans ville (message 34) et gares de récit (messages 22–25) : non portées, arrêt nommé.
- [ ] Décoder glieu.co / ville.co : menus de la ville, commerce, recrutement.
- [ ] Observer la chaîne dans ALIS instrumenté (poke de position, dump d'écran) au lieu de piloter le bureau.

## Nettoyage de fin de session, 26 septembre

- [x] Vérifier les worktrees enregistrés, les processus et les fichiers ouverts.
- [x] Vérifier PR44 fusionnée et ses commits distants ; conserver 4 preuves utiles et supprimer son clone.
- [x] Retirer captures intermédiaires, caches de test, téléchargements déjà extraits et doubles des images rejetées.
- [x] Installer la règle de retrait après push dans les instructions persistantes Codex et Claude.
- [x] Mesurer et vérifier les suppressions : `tasks/validation/cleanup-2026-09-26.json`.

Les répertoires des sessions Claude actives restent protégés. Aucun worktree
secondaire enregistré trouvé dans les emplacements parcourus.

Contrôle final : 59 dépôts examinés ; le worktree concurrent
`/Users/cdeust/Developments/anthropic-partnership/ai-architect-mcp-codebase/.claude/worktrees/fix-366a`
est apparu pendant l’audit et contient 7 fichiers modifiés ou nouveaux non commités.
Il est préservé. Un dépôt de fixture temporaire a renvoyé une erreur Git ;
aucune suppression dans les sessions Claude actives. Aucun processus Godot restant.

## Codex native cleanup test, 2026-09-26

- [x] Create documentation-only draft test PR #2, commit ccdf0f9c7b623027d337ca6c094e785308572680.
- [x] Verify real push removes its registered worktree and local branch automatically, with no manual worktree disposal.
- [x] Observe native SessionStart, Stop and SessionEnd, each exit 0; startup 0.114 s and end 0.543 s in the recorded probe.
- [x] Confirm active writer protection, Cortex completion receipt, then automatic rollout removal.
- [x] Remove recorder, intermediate captures and empty worktree parents; verify native test processes exited.

Evidence: tasks/validation/codex-hook-native-20260926.json. PR remains draft, not for merge. Existing Claude worktree and concurrent game edits were preserved. No CI checks configured on test PR.

## Scripts de ville décodés, 26 septembre 2026 (Claude)

- [x] glieu.co contient tous les menus de ville ; ville/usine/mamesc sont des décors ; COMMERCE.FIC n'est lu par aucun script. Preuves : tasks/evidence/city-scripts.md.
- [ ] Porter achat/vente et leurs refus (place, stock, argent, stockage tender, plafond 31000).
- [ ] Porter soldats/espions, mammouths, esclaves, atelier des villes industrielles.
- [ ] Inconnus : écrivain de main+0x1c, message textek 95, déclencheur du message 65.
