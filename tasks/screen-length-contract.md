# Longueur écran constante

STATUT : tentative de normalisation isotrope par cap rejetée par le propriétaire.
Le grossissement des vues de face demeure. Les modifications de rendu et
d'espacement de cette tentative ont été retirées. Le texte ci-dessous décrit
la tentative, pas une correction validée. Nouveau prototype : un dessin réellement
de dessus, tourné rigidement dans le plan, conserve tout son gabarit à chaque cap.

Demande propriétaire : « meme longueur a l'ecran, les joueurs n'apprecieront pas les changements de taille ».

| Référence | Artefact vérifié |
|---|---|
| Longueur visible | masque alpha des véhicules dans `game/assets/travel/vehicles*.png` |
| Direction et transformation | `game/scripts/train_renderer.gd`, `frame_for`, `registration` |
| Espacement sur les rails | `train_renderer.gd`, `poses`, historique `train_journey.gd` |
| Changement de zoom automatique | `game/scripts/travel_world.gd`, `_keep_train_in_view` |

Symptôme : taille visuelle différente au changement de cap.
But : longueur projetée du masque opaque dans l'axe du wagon identique à la vue E, à zoom utilisateur identique.
Hors périmètre : règles de conduite, rails d'origine, commerce et armement.
Stratégie refine : verified_reasoning, avec mesures externes des PNG et capture native.

La décision remplace le raccourcissement perspectif des versions précédentes.
Normaliser chaque dessin par un facteur isotrope constant calculé à partir de
son masque alpha (seuil 128, même convention que le rapport de silhouettes).
Ne pas adapter le facteur à la corde du virage. Ne pas cisailler le dessin.
Conserver l'espacement visuel de référence E, mesuré sur l'arc projeté des rails.
La simulation continue de mesurer ses distances en unités monde.
La caméra peut se recentrer, mais seul le joueur change le zoom.
À la première ouverture, choisir un zoom d'après la somme des longueurs visibles
E et le plus petit côté de la fenêtre ; ce choix ne dépend pas du cap. Ensuite
le déplacement ne modifie jamais ce zoom. Un zoom manuel élevé peut couper la
queue du train ; dans ce cas le recentrage garde la locomotive visible.

Acceptation : étendue alpha projetée normalisée identique pour les 48 couples
véhicule/cap (erreur numérique inférieure à 0,01 px à zoom 1), pas de zoom
automatique même si le convoi dépasse la fenêtre, contacts voisins sur le
même chemin projeté, 9 suites Godot et comparaison native des huit caps.
