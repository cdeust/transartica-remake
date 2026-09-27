# Visuels remis à Opus : 27 septembre 2026

Instruction du propriétaire : Codex produit les dessins, Opus les intègre.
Livraison : **32 PNG**, 32 prompts, manifeste avec dimensions, alpha et SHA-256,
et [galerie hors ligne](../output/imagegen/visuals-20260927/index.html).
Répertoire : `output/imagegen/visuals-20260927/`.

## Contenu

| Lot | Fichiers / contenu |
| --- | --- |
| Intérieurs | `captain-boudoir`, `command-room-background` : deux décors distincts ; commandement sans personnages. |
| Villes et services | `city-trading-station`, `city-industrial-workshop`, `city-mammoth-fair`, `city-information`, `city-slave-market`, `city-garrison`, `coal-mine`. |
| Carte et voies | `world-chart-frame` : cadre avec centre transparent pour la carte originale ; `world-landmarks-kit` : 12 lieux ; `rail-track-kit` : rails et aiguillages ; `bridge-works-alpha` : crevasse et lac, avant/pendant/après. |
| Combat | `combat-background` sans trains ; `combat-scene-reference` pour la composition ; quatre planches couvrant les 25 types ; `enemy-train-kit`, `combat-actors-kit`, `combat-equipment-kit`, `combat-effects-kit`. |
| Personnages | `crew-and-city-characters` : capitaine assis, officier, opérateur radio, marchand, recruteur, mécanicien. Plusieurs sont des bustes ; ce ne sont pas six acteurs debout complets. |
| Rencontres | `event-railway-works`, `event-nomad-camp`, `event-tunnel-ambush`. |
| Campagne | `story-urga-refuge`, `story-mammoth-mausoleum`, `story-oslo-vault`, `final-project-sun-overcast`, `final-project-sun-restored`. |

## Correspondance des wagons au combat

Ordre de lecture : gauche à droite, puis ligne suivante. Les noms des fichiers
sont historiques ; utiliser les identifiants du manifeste, pas leurs intervalles.

| Planche | Grille | Identifiants par ligne |
| --- | --- | --- |
| `combat-train-kit` | 3 × 2 | 1, 21, 2 / 3, 23, 11 |
| `combat-wagons-04-10` | 2 × 3 | 4, 5 / 6, 7 / 8, 9 |
| `combat-wagons-10-17` | 2 × 3 | 10, 12 / 13, 14 / 15, 16 |
| `combat-wagons-17-25` | 2 × 4 | 17, 18 / 19, 20 / 22, 24 / 25, vide |

Table de référence : `reference-private/commerce.json`, `wagon_names`.
Chaque identifiant 1–25 apparaît une fois, vérifié par le générateur du manifeste.
Les wagons armés sont des bases : monter les équipements de la planche séparée.
Le combat emploie une vue latérale dédiée ; le catalogue de voyage vu de dessus
reste dans les livraisons du 26 septembre.

## Références et extrapolations

Captures inspectées conservées dans `reference-private/art-direction/web-20260927/`.
Les fichiers `sources.json`, `ecs-sources.json`, `dos-sources.json` conservent
les liens collectés. Le manifeste indique les images utilisées pour chaque dessin.

- [Lemon Amiga ECS](https://www.lemonamiga.com/game/transarctica) et
  [AGA](https://www.lemonamiga.com/game/transarctica-aga) : intérieurs et scènes.
- [Galerie DOS, 52 captures](https://www.old-games.ru/game/screenshots/977.html) :
  composition du combat, villes, mine, travaux, nomades, tunnel et fin.
  AGA et DOS sont des références complémentaires ; elles ne prouvent pas
  l'identité de chaque détail avec l'édition ECS de référence.
- [Solution de Nikolaj Andersen](https://www.mogelpower.de/cheats/loesung.php?id=41910) :
  étapes de campagne utilisées pour les propositions Urga, mausolée et Oslo.
  Leur composition est inventée pour le remake et signalée comme telle.
- [Partie complète de NightTrapLongplays](https://www.youtube.com/watch?v=60OkMuX_H2o) :
  référence repérée, description consultée. La vidéo n'a pas chargé ses images
  dans cette session ; aucun visionnage complet ni minutage n'est revendiqué.

L'atelier, le marché aux mammouths, les kits de carte, les silhouettes ennemies
et plusieurs détails de véhicules sont des adaptations artistiques. Le
Minotaurus rouge et noir est une proposition, pas une restitution attestée.
Les inscriptions, codes et topologie doivent venir des données du jeu.

## Préparation à l'intégration

Les 32 PNG ont été décodés et leurs dimensions/empreintes mesurées ; 14 possèdent
de la transparence. Le fond en damier de la galerie sert uniquement à la voir.
Le manifeste donne les valeurs alpha mesurées, parfois plafonnées à 254.
Les dimensions et marges varient : les planches sont des sources graphiques,
pas des atlas avec rectangles et points d'attache déjà calibrés.

Relever les contours, supprimer les faibles pixels alpha isolés si nécessaire,
conserver les proportions et aligner roues/rails et attelages au montage.
Le rapport numérique d'échelle combat/voyage n'est pas établi par ces dessins.
La planche ennemie comporte des éléments très allongés : ne pas les normaliser
aveuglément sur la largeur des wagons du joueur.

`combat-scene-reference` est une illustration de composition avec acteurs et
trains fusionnés. Utiliser `combat-background` et les planches pour une scène
interactive. Les effets et poses sont des dessins clés, sans chronologie
d'animation validée. Les cartes de matériaux, masques de destruction, collisions
et états physiques ne sont pas inclus. Certaines scènes de récit ou de ville
contiennent des personnages et trains peints dans le décor.

Le cadre cartographique doit recevoir le réseau décodé, ses lieux et ses états
de travaux réels. Il ne fournit pas une nouvelle géographie. L'atelier comprend
des conifères lointains : choix artistique non vérifié dans la référence ECS.
Les scènes d'Urga et de fin modifient fortement la lumière ; vérifier leur
cohérence avec le moment du récit avant montage.

## Revue et périmètre restant

Livraison graphique examinée, fichiers PNG et couverture des 25 types vérifiés.
Aucun code du moteur modifié pour ce lot ; aucun lancement du jeu ni test
d'interaction revendiqué. Le rendu à la résolution de jeu reste à vérifier
avec Opus. Les fenêtres de journal/inventaire, fiches de gestion, menus,
transitions, toutes les variantes de dégâts et l'inventaire complet des scènes
ECS ne sont pas clos par cette livraison.

Deux brouillons de ponts remplacés ont été retirés du répertoire de livraison.
Les dessins retenus et les références privées sont conservés. Aucun processus
de test, worktree ou clone créé ; aucune publication distante.
