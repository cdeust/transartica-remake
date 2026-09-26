# Carte ECS : format et vérification

## Résultat du 25 septembre 2026

`CARTE.FIC` contient 11 680 codes de tuile, répartis sur **160 colonnes et 73 lignes**. L’index du code aux coordonnées `(x,y)` est `x * 73 + y`, avec origine `(0,0)`. Le fichier entier peut être exporté sans modifier ses octets.

La déclaration du script et les coordonnées du guide se recoupent : **43 des 44 villes** du [guide Andersen](https://www.mogelpower.de/cheats/loesung.php?id=41910) sont sur des codes 71 à 76. Tibesti `(43,70)` correspond au code 0. Cet écart reste ouvert : erreur du guide, coordonnées particulières ou autre mécanisme non décodé. Aucun déplacement correctif n’est appliqué.

## Preuve technique

Source : [ALIS, révision 19a95afd](https://github.com/maestun/alis/tree/19a95afdc07b45d997467806d4dd1bf83c5f8076). Le moteur reconnaît les données comme Transarctica Amiga, ALIS 2.2. Ses routines `cdim` et `cfreadb` sont dans [src/opcodes.c](https://github.com/maestun/alis/blob/19a95afdc07b45d997467806d4dd1bf83c5f8076/src/opcodes.c#L613).

Après décompression de `MAIN.CO` avec la routine `unpack_script` de cette révision, les octets à l’offset `0x18` sont `29 00 76 01 01 00 49`. Ils déclarent un tableau à l’adresse relative `0x76`, avec une dimension de `0x49`, soit 73. Le bloc de lecture à partir de `0x78d` charge CARTE.FIC : instruction `77 00 76 2d a0`, adresse `0x76`, longueur `0x2da0`, soit 11 680 octets. En version 2.2, `cfreadb` réalise une lecture brute. La zone suivante commence à `0x2e16`, exactement après ce buffer.

La taille divisée par 73 donne 160. Le rangement en colonnes produit des voies continues dans le rendu et retrouve les villes du guide. Les origines alternatives testées donnent 20/44, 28/44 et 13/44 correspondances, contre 43/44 pour les coordonnées inchangées. Les extraits de bytecode et l’empreinte du script sont dans [map-bytecode-evidence.json](data/map-bytecode-evidence.json).

Empreinte SHA-256 de CARTE.FIC : `8e1067619b254d57717348fefedc1b5013eb1d7ba23200a815e36f9b856d811a`. Provenance et limites de l’archive : [observation ECS](OBSERVATION-ECS.md).

## Ce que l’export permet

Consulter tous les codes et superposer les 44 positions du guide. Les couleurs sont diagnostiques ; elles ne reproduisent pas les graphismes du jeu. La catégorie 71–76 est une observation de concordance, pas encore une table complète des propriétés des tuiles.

Le décodeur ne déduit pas la praticabilité, les aiguillages, les rencontres ou les changements de carte liés à l’histoire. VILLE.FIC est désormais décodé : voir FORMAT-VILLES.md. Les règles de COMMERCE.FIC restent inconnues. Le réseau navigable demandera de lire les consommateurs de ces données. Une grille extraite ne constitue pas un remake complet.

## Reproduction

```sh
python3 tools/decode_map.py reference-private/CARTE.FIC data/villes.csv reference-private/map
python3 -m unittest discover -s tests -v
```

Les fichiers originaux et exports contenant leur carte restent dans `reference-private/`, exclu de la publication par `.gitignore`. Le décodeur et les relevés de preuve restent dans ce dossier.

## Livrables et contrôles

- Visionneuse locale : `reference-private/map/index.html` (recherche, sélection, survol et superposition des positions du guide).
- Grille et provenance : `reference-private/map/map.json`.
- Comparaison des villes : `reference-private/map/city-validation.csv`.
- Aperçu statique du réseau : `reference-private/map/map-preview.png`.

Quatre tests Python passent, dont le contrôle sur l’archive réelle, sans test ignoré. La conversion inverse du JSON exporté restitue exactement les 11 680 octets de CARTE.FIC et son SHA-256. Un contrôle JavaScript avec DOM simulé vérifie dessin, sélection de Tibesti, recherche d’Amsterdam, survol et bascule de superposition. Ce contrôle ne prouve pas le rendu dans un navigateur : les premiers outils ne pouvaient pas joindre Chrome ; Browser Use a ensuite confirmé sa connexion. L’ouverture de cette visionneuse locale a été bloquée par la politique du navigateur. L’aperçu statique de la grille a été inspecté.
