# Les 25 véhicules · sources artistiques détaillées

Ouvrir `index.html` pour consulter les 25 dessins et accéder à chaque PNG en taille réelle.

La livraison couvre les 19 types jusque-là sans dessin, ainsi que des versions détaillées des six véhicules de départ. Chaque fichier mesure 1024 × 1536 pixels, possède un canal alpha et correspond à un identifiant original du jeu. `catalogue.json` conserve les dimensions, empreintes SHA-256 et mesures alpha; `prompts.json` contient les 25 prompts exacts. Génération par l'outil intégré `image_gen`, sans CLI externe.

## Références

- Style : `../vehicles-overhead-prototype-v2.png`, six véhicules retenus par le propriétaire.
- Noms : `reference-private/commerce.json`, table `wagon_names`, types 1 à 25.
- Fonctions : `reference-private/city-scripts/texte2k-messages.txt`, messages 60 à 81.
- Composition initiale : `game/scripts/train_wagons.gd`, types 1, 21, 2, 3, 17, 23.

Les silhouettes, matériaux visibles et équipements sont des créations artistiques du remake. Les descriptions originales servent à distinguer les fonctions, sans prétendre reconstituer les sprites historiques. Ainsi, TANK est une citerne, distincte de OIL; OBSERVATORY et OBSERVATION BOX ont deux dessins différents.

L'affectation des six images initiales reste celle choisie pour le remake : 1 locomotive, 21 tender, 2 sleeper, 3 boxcar, 17 observation, 23 armored. Les dessins 17 et 23 conservent donc respectivement la verrière et la tourelle du train retenu, malgré les noms historiques MERCHANDISE et BARRACKS.

## Utilisation par Opus

Ces fichiers sont des sources artistiques; ils ne remplacent pas directement l'atlas du voyage. Le code d'intégration n'a pas été modifié par cette livraison. Utiliser l'identifiant `type_id`, jamais la position d'un fichier dans un dossier, pour relier un achat au dessin.

Les dimensions de canvas sont identiques, mais les largeurs dessinées ne sont pas encore recalées sur un gabarit commun. Mesurer les attelages et la largeur du châssis avant de définir les ancrages et l'échelle. Conserver une rotation rigide et une échelle constante pour chaque véhicule dans tous les caps.

L'alpha a été vérifié : les coins sont transparents et les silhouettes sont non vides. Il reste des pixels semi-transparents, notamment autour des contours; ce contrôle ne certifie pas un détourage sans halo. Les sources conservent aussi certains détails de volume hérités de la référence, notamment aux extrémités et aux équipements. Examiner les images sur le décor du jeu avant de les accepter comme atlas final.

## Préparation du combat

Les détails sont dessinés dans les sources, pas obtenus par agrandissement d'un petit sprite. Le zoom final doit néanmoins être validé dans le jeu : une résolution de fichier n'établit pas la taille physique ni le niveau de détail de simulation.

Séparer couleur, occupation solide, matériaux et pièces mobiles. Les armes sont encore présentes dans l'image de la caisse : il faut extraire une couche indépendante et définir son pivot avant de faire tourner ou arracher une tourelle, un harpon, une foreuse ou une grue. Une couleur de pixel ne doit jamais décider du matériau physique.

Les tirs, explosions et débris devront partager un état de dégâts par instance, conservé au changement de zoom et à la sauvegarde. Les cartes de matériaux et d'occupation, les intérieurs découverts par destruction et les pièces détachées ne sont pas livrés comme implémentés. Le contrat et les critères du futur combat sont dans `tasks/wagon-art-catalogue.md`.

## Contrôles effectués

- 25 identifiants uniques couvrent exactement 1 à 25.
- Les 19 identifiants absents de la composition initiale ont chacun leur PNG.
- Les 25 fichiers se décodent; ils sont RGBA, 1024 × 1536, avec des coins transparents.
- Les prompts, fichiers et empreintes sont associés dans l'inventaire.

Ces contrôles valident la livraison des dessins, pas leur raccordement au moteur de combat ni le rendu final du voyage.
