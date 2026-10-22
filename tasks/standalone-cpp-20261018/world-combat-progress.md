# Domaine monde et combat autonome — point du 18 octobre

Propriétaire : agent world_combat, sous orchestration root. Aucun build ni
lancement du jeu créé par cet agent ; root sérialise les preuves sous le plafond
de 1 Gio. Exception signalée : huit tests Python purs du packager ont été lancés
hors garde ; ils demandent une relance root et ne constituent pas sa preuve
validée. La correction de procédure est inscrite dans tasks/lessons.md.
Aucun commit/push.

## Livrables

- `native-game/world/` : EnemyTrains (30 slots, présence indépendante,
  historique aiguillages), motion commune, Mines/extraction, WorldActions,
  WorldRoamers et archive typée bornée/atomique.
- `native-game/combat/` : résolution automatique, conséquences, combat tactique,
  acteurs/ordres, armes/IA/dynamite, résultat exactement une fois et archive
  tactique comprenant le PCG indépendant.
- `native-game/screens/tactical*` et `combat_report.*` : assets existants,
  atlas/crops source, entrées P/F5/F6/split/dynamite, matériaux/occupation,
  armes rotatives/canons/recul/chute, acteurs/formations/accélération,
  escalade/mantle/dismount, poses de plantation/chutes, cavalerie et cavaliers,
  labels évitant acteurs/coques/autres labels, effets vivants sparse50Hz et
  quatre petits volumes de gaz au maximum.
- LivingEffects partagé : `draw_world(Canvas&, screen_origin, zoom)` conserve
  les émissions dans leur repère monde ; draw/draw_light/draw_atlas restaurent
  le mode de mélange SDL précédent. Atlas requis ; aucune image de substitution.
- `tests/world_tests.cpp`, `combat_tests.cpp`, `tactical_render.cpp` : fixtures
  de modèle puis sonde SDL bornée distincte de toute preuve de campagne.

## Couplages source conservés

`main.gd` partage `_trade_rng` entre commerce, mines, faune et rôdeurs.
`world_encounters.gd` possède un autre RNG pour trains ennemis et combats.
Les modèles prennent les états de Session et les RNG par référence. Le snapshot
Tactical contient son RNG ; le contrôleur restitue ce flux à WorldEncounters.
`TacticalScreen::advance_visual` n'avance jamais le modèle. Le contrôleur
appelle Tactical::advance(seconds*2), conformément au PACE2 source, puis fournit
les événements au rendu et à l'audio. Le contrôleur doit respecter paused().

## État de vérification

Root a communiqué PASS pour native_world et native_combat (0,26s / 0,24s) avant
les derniers ajouts de présentation. Ces derniers demandent encore compilation,
sonde SDL, captures, revue et vérification des entrées dans l'application réelle.
Les compteurs de suites ne constituent pas une validation de campagne ni une
réception artistique. Aucun gain de ressources chiffré n'est établi ici.

Sources de règles : scripts GDScript et modules game/native déjà présents,
ainsi que les listings et reçus `tasks/evidence/{enemy-trains,mines,world-roamers,
combat,automatic-combat-integration}.md`. Les constantes artistiques viennent
des modules Opus existants. Pour les seules fonctions mathématiques indépendantes
(hash des identités visuelles, float PCG, BCS), les sources officielles 4.5 ont
été consultées ; attribution dans `native-game/third_party/godot-math-LICENSE.txt`.
Il n'existe aucune dépendance sur des headers, types ou un runtime Godot.

Cortex query a renvoyé aucun profil et recall a échoué après attente ; aucune
boucle de relance ni redémarrage de service. Les sources locales restent la preuve.

## Revue intégration et régressions

- Revue en lecture seule de GameSession/game_events/game_archive : ordre source
  des callbacks conservé ; parsing/validation de chaque composant avant audio et
  commit du modèle vivant.
- Pont fermé : la branche utilisait la commande utilisateur Session::reverse,
  qui relâchait le frein et produisait un chemin de marche arrière. Source
  main.gd::_reverse_at_event exige TEXTEK52, frein, vitesse0 et émergence cachée
  depart_from_station. Root a posé le correctif ; six assertions ajoutées dans
  tests/game_session_tests.cpp, en attente d'exécution.
- Root a communiqué PASS pour launcher/game_archive/network/audio. La suite
  GameSession précédente échouait1/61 sur comparaison interfréquences ; diagnostic
  par composant et première ligne différente de snapshot ajoutés, sans changer
  l'exigence ni présumer la cause.
- Entrée audio tactique stop_effects puis wdecor0x6121 raccordée par root.
- Routage physique : l'adaptateur identifiait les commandes tactiques par scancode
  sans convertir keysym.sym attendu par les écrans. Écart AZERTY signalé à root ;
  correction de l'adaptateur sous son ownership.
- Sonde tactical_render : sélection au bord de la bande wagon doit choisir le
  wagon réel le plus proche, sans mutation modèle/RNG. Un guard défensif protège
  le résultat -1, mais ce résultat n'est pas atteignable avec une roster valide ;
  aucune reproduction de crash joueur n'est revendiquée.

Tous les fichiers de ce domaine sont gelés pour la prochaine compilation
sérialisée root. Aucune validation graphique ou entrée utilisateur réelle
supplémentaire n'a encore été exécutée par cet agent.

## Empaquetage macOS

Nouveaux fichiers sous native-game/packaging : allowlist runtime, collecteur des
ressources/manifests et dépendances Mach-O, mutation des copies seulement,
licences, signature ad-hoc, reçu SHA externe post-signature et vérificateur sans
accès aux chemins du checkout/Homebrew. README donne les sources plateforme et
les commandes root. Les sorties dans le scratch du projet principal sont
acceptées depuis un worktree enregistré.

L'inventaire contient aussi les deux masks de cabine et huit cutouts de
RoomHover ajoutés par l'autre propriétaire. Le nouvel oracle de couverture lit
les chemins littéraux actuels dans screens/view ; la suite compte désormais dix
tests, non relancés après les derniers ajouts. Root possède toutes les prochaines
exécutions, y compris --plan. Aucun paquet n'a été construit par cet agent.

FreeType installé2.14.1_1 : texte FTL officiel VER-2-14-1 identifié, téléchargé
par root dans son scratch enregistré. SHA communiqué par root :
5a5ee54c5001bbad1cdc1a57cc3dd4c42199b2da09d39c7ee41fab002d02967f.
Main SDL_GetBasePath/PrefPath et lien headerpad sont sous ownership root.
