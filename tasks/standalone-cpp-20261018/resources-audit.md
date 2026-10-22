# Audit du rendu autonome et des ressources

Audit statique du 18 octobre 2026, après lecture de FIDELITE.md et tasks/todo.md.
Périmètre : native-game/platform, native-game/view et leurs propriétaires de
production dans game/scripts. Aucun gain de performance n'est déduit du langage.
Aucun build, test ou lancement effectué par l'auteur de cet audit.

## Composition à préserver

Le chemin de production sélectionne assets/travel/artwork/world-hd/manifest.json
dans main_interface.gd. map_artwork_installation.gd:_clear_legacy retire les
anciennes peintures, repères, canopées et portails puis masque le fond. Les
passes de travel_cover.gd retournent immédiatement sous artwork_scene_candidate.
Les huit variantes du manifeste actif déclarent des backgrounds et aucun
foreground. Réintroduire automatiquement les anciennes textures pour remplir
les trous modifierait la composition choisie par le propriétaire.

Le C++ conserve actuellement ces backgrounds, les vrais ports CARTE et les
sprites rigides du train. Le pied de page restauré vient de original_panel.gd,
pas de travel_hud.gd qui reste caché dans la production. Les pixels de
original-panel-v2.png, leurs trois découpes, les cases de commande et la hauteur
de carte 149/200 doivent rester identiques lors des optimisations.

## Écarts de rendu à porter

| Domaine | Sources de production | Ressources et contrat |
|---|---|---|
| Rails | map_rail_drawing.gd, rail_art.gd, rail_material.gd | rail-track-kit.png ; traverses, doubles rails, raccords, volumes, reflets, aiguillages actifs et heurtoirs. Le C++ dessine encore les seuls segments centraux. |
| Mouvement | travel_world.gd:update_train/_advance_motion/_snap_visual_position | Interpolation de l'arc affiché entre cycles ; retard partagé du convoi ; remise à zéro au retour d'un écran caché et lors des changements de trajet. |
| Carte interactive | map_entities.gd, world_view.gd:_gui_input, travel_world.gd:focus_city | Noms et sélection des villes décodées, indicateur de direction évitant le train, zoom manuel, déplacement et inspection. |
| Mobiles | map_render_objects.gd:_update_enemies, map_entities.gd:visible_enemies | Même atlas locomotives ; perception source carrée selon les wagons actifs. Dépend du modèle réel de rencontres, sans composition adverse inventée. |
| Souterrain | map_vehicle_object.gd:update_pose, underground_visual.gd | Teinte/transparence déterminée par le contact ferroviaire réel ; le C++ utilisait une teinte blanche constante au moment de l'audit. |
| Effets | travel_living_effects.gd, engine_living_effects.gd, living_effects.gd, living_particles.gd, living_effects_atlas.gd | assets/effects/living-atlas.json et living-atlas.png ; cheminées enregistrées sur le crop héro, cadence visuelle indépendante, pause respectée. |
| Catalogue | artwork_scene_manifest.gd, artwork_scene_renderer.gd, artwork_scene_layer.gd, artwork_world_pages.gd | Identité CARTE, variantes et dépendances, plans visibles, foreground par foot_y, pages/LOD, hashes PNG/RGBA, préparation puis remplacement transactionnel. |
| Survol cabine | engine_room_art.gd, engine_room_controls.gd | engineer-mask.png, interface-mask.png, sélection des acteurs et infobulles source. |

Le catalogue C++ charge seulement une variante region_bounds par scène et
authentifie son PNG. Il ne reproduit pas encore tout le contrat des variantes,
des pixels RGBA et des pages. Porter ce contrat ne signifie pas inventer de
nouvelles couches absentes du package actif.

## Coûts identifiés dans le code

Ces observations décrivent des opérations, pas des temps mesurés.

- view/world.cpp:poses effectue les 24 recherches source par wagon. Chaque
  core/journey.cpp:sample_behind construit un vector temporaire de deux ou trois
  points. Un petit tableau fixe et un index d'arcs cumulés sont des candidats ;
  les contacts numériques doivent rester couverts par les régressions.
- Chaque point rail passe par screen, world_rect, fit et les requêtes SDL de
  taille ; rail_ports retourne un vector par tuile. Préparer la projection une
  fois par frame et conserver la géométrie suit map_rail_geometry_cache.gd.
  Une mutation locale doit invalider le code concerné sans repeindre le décor.
- footer.cpp refait le placement elliptique des chiffres romains et les essais
  de tailles à chaque frame. La disposition dépend de la taille et du font ;
  seules aiguilles et valeurs nécessitent des mises à jour courantes.
- Canvas::measure appelle glyph : mesurer un caractère absent peut créer une
  texture GPU. Chaque texte ou mesure reconstruit aussi un vector UTF-8.
- Quand le wagon13 est présent, footer.cpp appelle alpha_bounds sur l'image
  entière du lanceur à chaque frame. Son rectangle peut être conservé dès le
  chargement ; il ne dépend pas du temps simulé.
- View::load_artwork authentifie et téléverse les huit peintures avant l'accueil.
  Un catalogue léger et une résidence visible sont à comparer après mesure.
- Canvas conserve toutes les textures, plans alpha et tailles de glyphes jusqu'à
  sa destruction. Le plafond de 64 Mio par image ne borne pas leur somme.
  Une texture RGBA représente quatre octets logiques par pixel, un plan alpha
  en représente un ; le tampon RGBA de décodage en ajoute quatre pendant le
  chargement. Ces tailles ne représentent ni RSS, ni allocation réelle du pilote.

## Instrumentation de référence, sans changement de cache

Canvas expose resource_stats(), un shared_ptr<const ResourceStats> lisible sur
le thread de rendu même après destruction de Canvas. Il distingue :

- asset_textures et glyph_textures : créations, destructions, actifs et pics,
  avec octets RGBA demandés à SDL ;
- glyph_entries : entrées du cache, y compris les espaces sans texture ; leurs
  octets sont laissés à zéro car l'empreinte de std::map n'est pas mesurée ;
- alpha_planes : plans CPU à un octet par pixel ;
- staging_buffers : charges utiles RGBA de décodage, glyphes et captures ;
- octets logiques simultanément actifs et pic global, sans addition erronée des
  pics individuels ;
- requêtes et accès cache, mesures/textes, scans alpha et requêtes de taille ;
- durées et appels PNG, rasterisation glyphes, création/upload SDL et scan alpha.

Les compteurs incluent les ressources créées puis libérées lors d'un échec.
Les temporisations utilisent steady_clock. L'upload mesure la durée CPU des
appels SDL, pas une barrière de fin d'exécution GPU. L'instrumentation conserve
le filtre, l'ordre des opérations, les crops, les caches et les pixels existants.
Les buffers internes de libpng/FreeType/SDL, la mémoire des conteneurs et les
overheads du pilote ne sont pas comptés. Une mesure RSS externe reste requise.

begin_frame()/end_frame() sont des bornes optionnelles de mesure. Elles ne
déclenchent ni admission ni éviction. Une paire produit les deltas de travail et
la durée CPU entre les deux appels ; les paires imbriquées ou incomplètes sont
des erreurs explicites. Le dessin fonctionne aussi sans ces appels.

## Banc préparé pour exécution sérialisée par root

tests/render_resources.cpp doit être relié au core, aux trois fichiers view
principaux plus footer.cpp, à Canvas/hash et aux mêmes dépendances que le jeu.
Le CMake n'a pas été modifié par l'auteur de ce fichier.

Arguments obligatoires : --game-dir, --font, --output-dir (répertoire existant
enregistré par root), --renderer software ou accelerated, --frames (au moins
deux), --label. --artwork-dir, --width et --height sont optionnels. Le défaut
1280x800 est celui de app/main.cpp. Aucun changement de backend silencieux.

Le banc instancie les vraies classes View et Canvas puis mesure accueil, cabine,
cabine chauffée, monde, pied de page, pied de page avec lanceur, et les huit
peintures. Les deux états chauffé/lanceur sont explicitement des fixtures de
rendu, pas des preuves de progression de campagne. Le temps visuel est figé.

Chaque étape enregistre les frames froides puis chaudes, une capture PNG et les
SHA-256 RGBA de la première et dernière frame. Une différence dans cette charge
fixe échoue ; aucune copie PNG identique supplémentaire n'est écrite. Le JSON
conserve les snapshots de construction, de chaque étape, avant et après
destruction, puis les hashes des inputs. Le banc exige des comptes équilibrés
et zéro ressource observée active après destruction. Il refuse d'écraser une
capture ou un rapport existant. Le hash des inputs arrive après les mesures
pour ne pas réchauffer leurs lectures de fichier avant le chargement.

La durée par frame exclut présentation, readback, captures, JSON et hashes.
Elle mesure la soumission CPU ; ce n'est pas un FPS. Les captures et hashes
doivent être comparés entre baseline et optimisation, avec même renderer,
résolution, assets, font et sources identifiés. Le cache de fichiers de l'OS
n'est pas purgé : « froid » signifie cache applicatif neuf, pas disque froid.

## Séquence de validation proposée

1. Root compile et exécute d'abord ce banc sans optimisation, garde le JSON,
   les captures et une mesure RSS sous la garde existante de 1 Gio.
2. Modifier séparément chargement/résidence, calcul des poses, cache de géométrie
   ou cache de disposition. Rejouer exactement le même banc et comparer hashes,
   compteurs et distributions des temps ; aucune amélioration annoncée à ce stade.
3. Étendre les scènes mesurées au parcours réel : droite, virage, aiguillage,
   tunnel, frontière de région, longue composition, retour cabine et sauvegarde.
4. Ajouter les couches manquantes en gardant les captures de fidélité distinctes
   des benchmarks. Les pixels supplémentaires attendus doivent être approuvés
   comme portage de sources, pas dissimulés dans une optimisation.
5. Pour toute comparaison de moteurs, produire une référence de comportement
   équivalente réellement mesurée. Les tests du C++ seul ne peuvent la remplacer.
