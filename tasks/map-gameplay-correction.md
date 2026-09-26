# Contrat de correction — 26 septembre

Demande brute :
> The doodad is not moving at the same time the camera is moving, the feeling is weird, the current feeling on the map aside from the train being beautiful, is really horrendous.
> The regulator to choose whether to go up or down does not work, the train is able to stop like magic as soon as you click on brake, while you had to time it on the natural version to have your train slowing down enough to be able to stop in town.
> Town are not visible on the map, the control on the side when on the map is horrible as well

| Référence | Liaison vérifiée |
|---|---|
| doodad, caméra, carte | travel_world.gd et travel_ground.gdshader; inspection native révèle texture initialement fixe puis TextureRect plus grand que son parent |
| train beautiful | assets/travel/train-east.png; conserver ce dessin |
| up/down regulator | travel_hud.gd envoyait set_regulator; train_journey.gd fixé cap6 ne gère aucun aiguillage |
| brake | engine_state.gd _drive force speed0; sources TIME/TRAIN documentées dans evidence/braking-rules.md |
| natural version | corpus Amiga ECS privé, TIME/TRAIN/CARTE/TABLE; manuel https://www.lemonamiga.com/doc/transarctica/1676 |
| towns | world_data.gd 46 villes, ancres76; travel_world.gd simples cercles, visibilité testée sur une seule ancre |
| side control | travel_controls.gd ancien panneau; désormais remplacé par travel_hud.gd mais fonctions de direction absentes |

Symptôme : scène et contrôles ne donnent pas une conduite ferroviaire cohérente.
But : caméra/décor synchrones, bifurcation choisie et approche de ville lisible.
Hors périmètre immédiat : commerce complet, combat, remplacement du train approuvé.
Stratégie : context_engineering + verified_reasoning; traces originales, tests
sur données privées et observation native, pas de nouvelle proposition de maquette.

Acceptation externe :
- Tests de projection inversée, zoom ancré, taille réelle du fond et déplacement
  commun des rails/terrain, puis observation native pendant déplacement/pan/zoom.
- Tracé original du clic aiguillage et transitions; un test fait diverger deux
  trajets avec les deux états sur la même carte, sans modifier CARTE.FIC.
- Arrêt progressif demandé explicitement ensuite : vitesse strictement décroissante,
  trajet continu pendant freinage, vitesse0 atteinte, régulateur préservé,
  résultat identique à15/60FPS et après sauvegarde partielle.
- Villes découvertes dessinées à leur empreinte originale; inconnues non dessinées
  ni sélectionnables. Une ville du trajet apparaît en partie réelle.
- Aucun panneau latéral de banc dans la vue livrée; commandes cliquées en natif.

Décision complémentaire propriétaire : « oui frein progressif pour le remake ».
Frein de service: réutiliser la baisse originale de5 par cycle du régulateur;
son application au levier est une adaptation autorisée, pas une règle ECS.
Les combats futurs auront des explosions modernes pixel art inspirées de Noita,
avec effets animés, débris, fumée et lumière; ne pas réutiliser les sprites ECS.
