# Scénarios visuels dans l'application native

Le générateur `native-game/tests/gameplay_scenarios.cpp` prépare des sauvegardes
complètes pour charger les scènes dans l'application SDL. Ces sauvegardes sont
des fixtures mises en place directement. Elles ne prouvent ni un trajet jusqu'à
ces événements ni une campagne terminée.

## Production des archives

Le parent compile et exécute ce programme avec les mêmes bibliothèques que
`game_archive_tests`. Il reçoit deux arguments : le répertoire `game` contenant
`private-data/CARTE.FIC`, puis un répertoire de travail existant. Il crée son propre
sous-répertoire `gameplay-scenarios-<horodatage>-<compteur>` sans écraser un dossier
existant. Aucune modification d'app/CMake n'est effectuée par ce lot.

```text
gameplay_scenarios <game-directory> <existing-scratch-directory>
```

Utiliser un parent ignoré dans les sorties privées du projet. Les archives
contiennent la carte décodée et des textes privés ; le manifeste inclut la réponse
du quiz sélectionné. Ces sorties doivent rester hors des paquets publics.

Chaque cas repart des graines de `game_archive_tests.cpp` : état partagé7,
rencontres19, présentation23 et audio31 au constructeur. Le périphérique audio
reste fermé. Le budget résident audio est celui imposé par le propriétaire,
1073741824octets. Le parent conserve son garde de mémoire pour le processus entier.
Les archives commencent avec la lecture audio arrêtée, comme `GameAudio::reset`.
Les interactions suivantes empruntent les routes audio de l'application.

Le programme appelle `save_game`, relit l'enveloppe puis appelle `load_game` après
réinitialisation. Il compare exactement les sections sérialisées à l'état attendu,
y compris RNG et présentation. Le suffixe `.native` apparaît seulement après cette
comparaison. Un échec conserve éventuellement un fichier `.staged`, inscrit la
raison dans `manifest.json` et fait sortir le programme avec le code1. Aucun cas
échoué ne doit servir de preuve visuelle.

La présentation conserve le fond cabine, écran1 de `SessionUI::Screen`, sur lequel
l'application compose ses modaux. `world_view` contient les valeurs par défaut de
`WorldState`, avec `ready=false` : `View::restore_world` effectue son cadrage initial
réel. Les scènes ne forcent ni zoom particulier ni coordonnées de caméra inventées.
La ville est restaurée par `CityScreen::restore_city`, sans nouveau tirage du stock.

## Chargement et interactions

Lancer l'application réelle avec son argument `--save-dir` pointant sur le
sous-répertoire annoncé. À l'accueil, utiliser F9, saisir le nom du slot et valider
avec Retour. Les noms ci-dessous respectent la normalisation du livre source :
lettres ASCII majuscules, huit caractères au maximum. Repartir de l'accueil ou
relancer l'application pour charger le cas suivant lorsqu'un modal capture F9.

| Slot | Construction et source | Interaction à observer |
| --- | --- | --- |
| CITY | `game_archive_tests.cpp::commit_boundaries` : `GameSession::open_city(24)` depuis le trajet initial canonique. C'est une fixture de commerce ; aucune arrivée ferroviaire n'est simulée. | Cliquer un commerce et inspecter un prix ou une transaction. Ce cas ne vérifie pas le départ de gare. |
| WORKS | `game_session_tests.cpp::works` : crevasse83,67, approche82,67, wagon rails17 avec20 unités et wagon esclaves5 avec15. L'archive conserve la question non payée. | Cliquer OK, vérifier le rapport et le débit unique, puis cliquer OK pour réparer. |
| MINE | `game_archive_tests.cpp::base_state` : jour3 et `WorldActions::tick_mines(3)`. Le premier gisement vivant fournit la cellule. Ses approches sont filtrées par `Journey::valid` sur le réseau réel avant `ask_mine`. | Cliquer OK pour prospecter, traverser les plaques puis fermer le résultat. Vérifier le charbon et la sortie de la mine. |
| HERD | `game_session_tests.cpp::hunt_text_cadence` : troupeau0 à la cellule du train, quantité20, timer40, direction6 ; `WorldRoamers::encounter` ouvre la question et déplace le troupeau selon son RNG. | Cliquer OK, continuer jusqu'au résultat puis fermer. Vérifier les mammouths dans l'inventaire. |
| NOMAD | Même construction de rencontre, avec `Nomad::x/y` égaux à la cellule du train et les troupeaux inactifs. `WorldRoamers::encounter/answer` puis `GameSession::answer_world` raccordent la ville45. | Cliquer OK, inspecter le marché puis partir. Le stock doit être tiré une seule fois. |
| TACTIC | `game_archive_tests.cpp::battle` : ennemi créé par `spawn(0)`, modèle `Tactical::begin`, pause manuelle conservée et vitesse joueur1. | Relâcher la pause avec P, sélectionner un acteur et donner un ordre. Observer le combat dans son écran réel. |
| LAUNCH | Wagons de `launcher_tests.cpp::continuation` : lanceur13 et porte-missiles14, marchandise2, quantité2. `Controller::open` conserve le trajet initial canonique. | Cliquer ARM, attendre, cliquer FIRE puis fermer le rapport. Le missile doit être débité à la fermeture. Ce cas ne promet pas une cible ennemie touchée. |
| QUIZ | `game_archive_tests.cpp::works_and_quiz` : `open_city(5)` ouvre la protection avant toute visite. Le train conserve son trajet initial de fixture. | Saisir `private_quiz_answer` du manifeste puis Retour. Vérifier l'ouverture unique de la ville5. |
| FINALE | `campaign_tests.cpp::finale_rules` : `Controller::station(-5)` ouvre l'introduction du Soleil. Les étapes antérieures de campagne ne sont pas simulées. | Cliquer l'introduction, observer le film et son retour aux options. |

La sélection d'une approche valide de mine construit un état local cohérent avec
les ports du rail. Elle ne prouve pas que le joueur a parcouru le réseau pour y
arriver. Le même avertissement s'applique au déplacement explicite de WORKS.
La première génération de CITY a refusé l'approche31,67 : cette cellule cachée
n'avait pas un historique initial valide. La fixture conserve désormais le trajet
initial au lieu de désactiver le validateur. Le générateur n'injecte aucun nouveau code de carte ; la création de
mine utilise exclusivement les mutations du modèle de production.

## État de validation de ce lot

Le générateur et cette procédure sont préparés par l'agent propriétaire des deux
fichiers. Aucun build, génération d'archives ou lancement n'a été exécuté par cet
agent. Le parent doit conserver le résultat de compilation et le manifeste produit,
puis noter les captures et interactions réellement observées pour chaque slot.
`archive_roundtrip_verified` prouve seulement le rechargement des modèles ; le champ
`visual_status` reste `not_observed_by_generator` jusqu'au contrôle dans l'application.
