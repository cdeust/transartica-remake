# Matrice des parcours du jeu autonome

Audit du 18 octobre 2026. Référence fonctionnelle : `game/scripts/`. Contrat propriétaire : `FIDELITE.md:17–26` et mandat autonome de `spec.md`. Aucun lancement ni benchmark effectué par l'auteur de cette matrice.

Cette photographie précède le raccordement des nouveaux lots par l'orchestrateur. Une implémentation isolée reste à intégrer et à vérifier dans la partie. Le nombre de classes ou de fichiers portés ne mesure pas la complétude.

## Composition observée

`native-game/app/session_ui.h` expose huit destinations : Reception, Cabin, World, Boudoir, Quarters, Instruments, Overview, Inventory. `SaveBook` est un dialogue modal. `session_ui.cpp` raccorde navigation, commandes moteur, aiguillages, horloge et sauvegarde `.native`. Le lance-missiles et la marche arrière renvoient encore une indisponibilité au moment de l'audit.

| Parcours source | Contrôleur et actions | Assets/données | État lors de l'audit |
|---|---|---|---|
| Introduction | `game_boot`, `startup_intro` : séquence et entrée dans l'accueil | `campaign/startup.png`, `private-data/startup.json` | À porter |
| Accueil/options | `reception_screen`, `world_encounters` : nouvelle partie, charger, niveau, combat automatique, musique | `interface/reception.png` | Start/load raccordés ; réglages à porter |
| Clavier | `keyboard_settings`, `keyboard_settings_button`, `key_bindings` : capture, contexte, conflits, persistance | `original_screen`, `brass_choice` | À porter |
| Cabine/instruments | `engine_room_art`, `engine_room_controls`, `engine_instruments`, `instrument_art` | Assets cabine/instruments | Raccordés ; fidélité complète non vérifiée ici |
| Bandeau | `original_panel`, `panel_hotspots`, `panel_composition`, `panel_clock` | Bandeau et wagons | Navigation/horloge/défilement raccordés ; reverse/missile ouverts |
| Carte détaillée | `travel_world`, `world_view`, `map_*`, `world_terrain_*` | CARTE, `travel/artwork`, manifeste monde | Voyage/aiguillages raccordés ; composition intégrale ouverte |
| Boudoir | `boudoir_session`, `boudoir_screen`, `boudoir_actions` : bénitier, Kolotov, revolver, sauvegarde | `boudoir/captain-boudoir.png` | Décor/inventaire/save raccordés ; bénitier/revolver ouverts |
| Quartiers | `general_quarters`, `campaign_crew` : espions, rapports, carte, inspection | `boudoir/general-quarters.png` | Décor/carte raccordés ; équipage ouvert |
| Inventaire | `inventory_page`, `inventory_report`, commerce/wagons | `interface/inventory-frame.png` | Rapport paginé ; modèle économique intégral à raccorder |
| Carte générale | `ecs_overview`, `overview_chart_art`, `campaign_crew` | `world-artwork.png`, cadre, landmarks, `overview-geometry.json` | Carte/position raccordées ; inspection/sélection ouvertes |
| Sauvegarde | `save_book`, `save_slots`, `session_saves`, `session_save_extensions` | Cadre et bande noire | Fichiers `.native` ; extensions de campagne ouvertes |
| Revolver/mort | `captain_event`, `boudoir_actions`, campagne | `interface/mort-earth.png` | À porter |
| Ville d'information | `main_interface.show_city`, `city_screen`, `campaign_session.show_town` : informations/rumeurs, départ | `cities/city-information.png`, textes privés | Nouveau `CityScreen` émet le message ; campagne hôte à raccorder |
| Comptoir | `city_screen`, `city_trade` : choix, quantité, achat/vente, refus | `city-trading-station.png`, `goods-icons.json` | Nouveau modèle/écran écrit ; arrivée/départ à raccorder |
| Foire mammouths | `city_trade` : achat/vente, capacité, paiement | `city-mammoth-fair.png` | Même lot économie écrit ; intégration ouverte |
| Marché esclaves | `city_trade` : achat/vente et refus | `city-slave-market.png` | Même lot économie écrit ; intégration ouverte |
| Garnison | `city_trade` : soldats, fichiers d'espions, départ automatique5..7 | `city-garrison.png` | Même lot économie écrit ; intégration ouverte |
| Achat wagons | `city_trade`, `city_screen` : catalogue10..16, tenders, quantité | `city-industrial-workshop.png`, silhouettes tactiques | Même lot économie écrit ; intégration ouverte |
| Atelier gare | `station_workshop`, `train_management`, `world_session` : déplacer, réparer, retirer, confirmer | Atelier et atlas overhead | Modèle/écran écrits ; frontière et reprise à raccorder |
| Mines | `world_session`, `world_event_screen`, `world_actions`, mines : questions, phases, résultats | `world-events`, textes privés, ambiance | À porter/raccorder |
| Travaux ferroviaires | `works_dialog`, travaux/voies : coûts, acceptation, résultats, départ | `world-events`, textes privés | À porter/raccorder |
| Nomades/chasse | `roamer_screen`, `world_roamers`, `world_session` | `nomads.png`, `mammoth-hunt.png` | À porter/raccorder |
| Dialogues narratifs | `campaign_session`, `campaign_screen` : pages, choix, conditions, effets | `private-data/campaign.json` ; Urga, Oslo, mausolée, soleil, baleine, pente | À porter/raccorder |
| Équipage/missions | `campaign_crew`, `quarters_actions`, `inspection_car`, `spies`, `spy_report`, `stoup_messages` | Quartiers/carte et textes | À porter/raccorder |
| Protection | `campaign_protection`, `manual_quiz` : avant entrée, réponse, reprise | Questionnaire et écran campagne | À porter/raccorder |
| Faune/embuscades | `campaign_fauna_session`, `campaign_ambush`, hazards/fauna | `wolf-ambush.png`, `mole-ambush.png` | À porter/raccorder |
| Finale | `campaign_session`, `finale_sequence`, `finale_art` | Soleil couvert/restauré, effets, `finale.wav` | À porter/raccorder |
| Combat automatique | `world_encounters`, ennemis, résolution, `combat_report` | Cadre inventaire, données des trains | À porter/raccorder |
| Combat manuel | `tactical_scene`, `tactical_combat`, setup/actors/weapons, restore/survivors/result/outcome | `combat/*.png`, mouvements et effets | À porter/raccorder |
| Lance-missiles | `launcher_session`, `launcher_scene`, modèle/géométrie/snapshot | `interface/launcher.png`, rocket, ignition | À porter/raccorder |
| Audio | `game_audio`, `game_audio_routes`, `scene_audio`, `engine_audio`, `sample_channels`, `audio_cue` | Manifests audio privés, musique orchestrale, WAV finale | Aucune initialisation audio dans `main.cpp` audité |
| Données privées | `public_boot`, `public_data_pack` : installation/validation avant démarrage | Paquet privé historique | Distribution autonome à définir |

## Lots indépendants et interfaces

| Propriétaire de lot | Responsabilité | Dépendances partagées |
|---|---|---|
| Composition | Entrée/sortie des scènes, frontières, pause, transactions de sauvegarde | État unique du train, horloge, réseau |
| Économie | Commerce, recrutement, atelier, inventaire | EngineState, vector<Wagon>, flux Random du commerce |
| Monde | Mines, travaux, nomades/chasse, départ/reverse | Réseau et voyage, ressources, événements hôte |
| Campagne | Dialogue, équipage, questionnaires, faune, fin de partie | Conditions, effets uniques, états persistants |
| Combat | Ennemis, tactique, automatique, missile | Composition et cargaison du train, RNG, résultats |
| Présentation | Terrain, entités, occultation, caméra | Données CARTE et état de simulation |
| Accueil/services | Introduction, options, clavier, audio | Événements de transition et préférences persistantes |

`session_save_extensions.gd:18–35` impose de conserver campagne, monde, travaux, interface mondiale, audio, RNG commercial, roamers et lance-missiles. La validation des extensions précède tout engagement. Sauvegarder pendant une interaction puis reprendre doit conserver sa phase et empêcher une seconde application des coûts/effets.

## Contrat du lot économie écrit

Fichiers : `native-game/economy/{trade,management,world_data}.{hpp,cpp}`, `native-game/screens/city_screen.{h,cpp}`, `native-game/tests/economy_tests.cpp`.

`Trade::load(private_data,error)` charge les tables privées avec json-c ; `reset(Random&)` initialise le stock. `TradeState` conserve22×16 stocks signés et20 fichiers d'espions. Le contrôleur de campagne utilise `set_spy_slot` sur le même objet. `WorldData::load` charge les46 villes et les octets CARTE. Son `city_at` cherche uniquement un ancrage exact ; la recherche d'une gare utilise l'algorithme source `rail_network.gd:station_lookup`, avec offsets mutés et stations spéciales.

`CityScreen` reçoit Canvas, assets, Trade, WorldData, EngineState et vector<Wagon> par référence. `open(city,Random&)` doit être appelé une seule fois après le contrôle de campagne ; il effectue la visite des nomades. `open_workshop(Cell)` ouvre l'atelier. `handle(SDL_Event)` retourne `CityEvent{depart,cargo_changed,town_message,consumed}`. Le propriétaire hôte applique les deux drapeaux si une transaction provoque aussi un départ. Il recalcule la masse et la géométrie de composition après `cargo_changed`, puis dessine le bandeau après `draw()`.

`restore_city(index)` rouvre la présentation sans visite ni tirage aléatoire. La source `session_saves.gd:134–144` rouvre le menu initial : elle ne persiste pas la quantité, la sélection de marchandises ou son défilement. L'atelier de gare possède un contrat distinct dans `world_ui_save.gd:8–20,51–79`. `workshop_snapshot()` et `restore_workshop(WorkshopState)` conservent visibilité, titre, sélection, action, défilement, déplacement en cours, confirmation et message. `Management::valid_workshop` vérifie les indices et refus sur les wagons/ressources restaurés avant engagement.

Le modèle revalide la quantité finale avant engagement pour refuser un choix modal périmé. La primitive GDScript ne le faisait pas ; son écran contrôlait chaque incrément. Les transactions acceptées conservent prix, ordre des wagons, wrap de stock signé et fichiers d'espions. Les appels directs volontairement impossibles dans les anciennes fixtures doivent fournir une capacité réelle avant de tester le plafond de crédit.

La fixture économie couvre les tables réelles, les refus, les transactions, les fichiers d'espions, l'ordre de chargement, les seuils atelier et les restaurations invalides. Elle attend `game/private-data` comme argument. Elle n'a pas été exécutée par ce propriétaire.

## Preuves restant à obtenir

- Vérifier une arrivée réelle pour chaque type de ville et le passage du contrôle de campagne.
- Exercer les achats/ventes avec les refus affichés, puis contrôler la masse et les ressources après départ.
- Vérifier l'atelier par clic, notamment insertion, confirmation et protection des tenders.
- Sauvegarder/reprendre une transaction en cours et une action de campagne suspendue.
- Terminer le parcours de campagne avec combat et finale dans l'exécutable autonome.
- Mesurer allocations, chargements et temps d'image sur ces parcours, puis vérifier le paquet Windows sur Windows.

`engine_panel`, `travel_controls`, `cab_vignette` n'ont pas de constructeur retrouvé dans la composition inspectée. `pixelworld_view` et ses couches sont des variantes expérimentales. Les bases `original_screen` et `world_view` ne sont pas des destinations supplémentaires.
