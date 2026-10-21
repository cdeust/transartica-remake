# Achèvement du jeu natif et optimisation des ressources

> Je compte sur toi pour finir le jeu en C++, avec tout le portage manquant et l'optimisation des ressourcez

## Références du mandat

| Référence | Artefacts concernés | Preuve |
|---|---|---|
| jeu en C++ | native-game/app/main.cpp, app/session_ui.cpp, core, screens, view | Application SDL exécutée ; validation.md et artefact SHA256 |
| portage manquant | game/scripts/main.gd, main_interface.gd, journey_session.gd, campaign_session.gd, world_session.gd, world_encounters.gd ; game/native comme référence | Racine de composition et dispatch source ; historique 2ea408a, 8e2e725, ac1c1be |
| interface existante | original_panel.gd, city_screen.gd, boudoir_session.gd, campaign_screen.gd, tactical_scene.gd | Propriétaires instanciés par Main ; correction utilisateur conservée dans lessons.md |
| optimisation des ressources | native-game/platform/canvas.cpp, view/view.cpp, view/world.cpp, view/footer.cpp, core/journey.cpp | Cache textures/glyphes, chargement anticipé des peintures et calcul des contacts |
| fidélité | FIDELITE.md, FORMAT-CARTE.md, sources décodées sous tasks/evidence | Carte/histoire ECS, caméra et gabarit inchangés ; règles inconnues non inventées |

Symptôme : le runtime autonome couvre un trajet avant et quelques écrans ; les
contrôleurs restants et leurs ressources ne sont pas raccordés.

But : porter toute la composition du jeu et valider un parcours complet en C++
autonome, puis mesurer et réduire les coûts de ressources sans dégrader les images.

Hors demande : changement d'histoire ou de règles, nouvelle direction artistique,
publication distante et suppression de travaux appartenant à d'autres sessions.

## Exécution

Stratégies refine §5 : plan_and_solve pour les dépendances entre lots et
verified_reasoning pour les règles, la fidélité et les mesures. Le plan existant
N1–N6 reste le suivi du mandat ; aucune réduction de portée aux seuls nouveaux
écrans. Les spécialistes ont des propriétaires distincts ; root compose et
sérialise les builds et lancements sous le plafond de 1 Gio.

Les rappels Cortex sont appelés avant investigation. Les décisions antérieures
imposent une vraie preuve de jeu, le bandeau illustré et les pixels existants.
Les observations de performance Godot ne constituent pas une mesure du runtime
SDL ; refaire une référence avant chaque optimisation. Ne pas rajouter des
couches historiques que map_artwork_installation.gd désactive dans world-hd.

## Ordre de raccordement et preuves externes

- [ ] Graphe de tous les écrans/actions/modèles, suivi par propriétaires source.
- [ ] Marche arrière, contacts occupés et sauvegarde : porter les cas de
  test_reverser, test_reverse_continuity et test_reverse_physical_stop ; commandes
  dans la fenêtre native, capture du train et reprise de sauvegarde.
- [ ] Villes et économie : 46 ancres réelles, arrivée, transaction, masse,
  départ masqué ; tests station_matrix, city_trade et terminus_departure portés.
- [ ] Monde, travaux et campagne : dispatch d'entrée dans l'ordre source,
  événements et conséquences sauvegardés ; route campagne jusqu'à la finale.
- [ ] Combat et audio : parcours manuel/automatique, résultats et hasard
  persistés ; entrées et sortie audio réelles, pas seulement modèles isolés.
- [ ] Interface : chaque action source a un chemin natif raccordé et testé ;
  inspection de captures, mêmes assets et mêmes zones d'interaction.
- [ ] Ressources : banc reproductible avant/après, images identiques pour les
  optimisations de cache, mémoire et temps mesurés ; aucun seuil inventé.
- [ ] Distribution : application indépendante du checkout, dépendances et
  contenus privés correctement séparés, lancement sur chaque OS annoncé.

Critère global : une partie native du démarrage à la finale, avec sauvegardes
intermédiaires et reprise, aucune action requise laissée indisponible. La matrice,
les logs, les captures et les mesures servent de preuve ; un nombre de classes
ou de tests ne suffit pas à clôturer le jeu.
