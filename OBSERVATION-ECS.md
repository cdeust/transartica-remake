# Observation de l'archive ECS

25 septembre 2026. Source : [page Amigaland](https://amigaland.de/transarctica), lien ECS vers `https://amigaland.de/wp-content/uploads/2021/03/transarctica.zip`.

Archive récupérée dans `/private/tmp/transarctica-ecs-research.zip` pour inspection locale. SHA-256 : `a401174cc59bb818a410c77af61a1d7f483bd10b5a0eb2e30e5e76827db994a3`. Vérification CRC ZIP avec la bibliothèque standard Python : aucune erreur.

Deux entrées ADF, chacune de 901120 octets :

| Entrée | SHA-256 |
|---|---|
| Transarctica (1991)(Silmarils)(M3)[cr Interpol](Disk 1 of 2).adf | dbddd8944e2b5f002ae785445733a802cefcb2262cf0e40744173eb90f497ef9 |
| Transarctica (1991)(Silmarils)(M3)[cr Interpol](Disk 2 of 2).adf | 2064bcc1cb658e7e8ac3a97f01949768c5271a9a94a9ece9dd4b27e508596106 |

Les deux en-têtes commencent par `DOS` suivi d'un octet nul. Leurs noms portent une indication de modification par Interpol. L'année du nom de fichier ne remplace pas la date de sortie documentée. Ces vérifications de structure ne certifient pas l’authenticité des images.

Copies de travail : `/private/tmp/transarctica-ecs-observation/disk1.adf` et `disk2.adf`. Ces fichiers temporaires ne sont pas inclus dans le dossier documentaire destiné au projet MIT. La provenance est conservée pour permettre de reproduire l'observation.

## Lecture du système de fichiers

Outil : [amitools / xdftool](https://github.com/cnvogelg/amitools), version 0.8.1, commandes `list` et `read` documentées [ici](https://amitools.readthedocs.io/en/latest/tools/xdftool.html). Les deux images ont pu être listées. Résultats conservés dans `data/disk1-listing.txt` et `data/disk2-listing.txt`. Cette étape de lecture des disquettes n’exécute pas le jeu.

Trois fichiers de la première disquette extraits dans le répertoire temporaire d'observation :

| Fichier | Octets | SHA-256 |
|---|---:|---|
| CARTE.FIC | 11680 | 8e1067619b254d57717348fefedc1b5013eb1d7ba23200a815e36f9b856d811a |
| VILLE.FIC | 138 | c2a51fb5f243502da0decc8877afb0f1b5a69e09744e6df629ece1d1f09000da |
| COMMERCE.FIC | 1472 | 6f32e1c4d4b806367f3f9ca93de6853f321995f451f34c174963d1cf84e5b951 |

Ces noms suggèrent des données du monde et du commerce ; leur format et leur contenu sémantique ne sont pas encore validés. La seconde disquette comporte notamment `CARTE.CO`, `VILLE.CO`, `USINE.CO` et des fichiers `SCENE*.CO`, pistes pour retrouver les traitements correspondants.

Exploration de VILLE.FIC : lire naïvement des coordonnées dans des enregistrements de deux ou trois octets ne retrouve aucune des 44 coordonnées du guide. Une hypothèse de décalage sur le premier octet de triplets n'en rapproche que 15. Cette hypothèse est insuffisante et n'est pas un décodeur retenu. Prochaine vérification utile : lire le traitement du fichier avant de proposer un format.

## Exécution et décodage ultérieurs

Le moteur ALIS à la révision `19a95afdc07b45d997467806d4dd1bf83c5f8076` a été compilé localement avec CMake et SDL2. Les ressources extraites ont permis d’afficher le logo Silmarils, l’introduction et le menu de langues : anglais, français et allemand. La sélection anglaise n’a pas abouti avec les entrées automatisées ; aucune partie jouable ni séquence finale n’a été observée. La référence de reconstruction reste ECS anglais. Le processus temporaire a ensuite été arrêté.

Le moteur a identifié Transarctica Amiga, version ALIS 2.2. Les scripts MAIN, CARTE, VILLE et USINE ont été décompressés avec sa routine `unpack_script`. L’analyse de MAIN a permis de retrouver le chargement brut de CARTE.FIC et sa dimension de 73 cases. Voir [format de carte](FORMAT-CARTE.md) pour le résultat et sa comparaison au guide. Les empreintes des deux disquettes sont restées identiques après inspection.

## Contrôle de la trace lors de la reprise

La relecture de la trace complète corrige la limite de l’observation visuelle précédente : `traduc.co` a effectivement reçu la touche `1` (valeur 49), puis écrit 1 à l’offset global `0x15`. La trace exécute ensuite `carte.co`, `time.co` et `souris.co`. Le menu anglais a donc été franchi dans cette exécution ; cela ne démontre pas encore une partie menée jusqu’à la fin. Les adresses et l’empreinte du journal figurent dans [runtime-observation.json](data/runtime-observation.json).

Les références sont désormais conservées dans `reference-private/`, exclu de Git par `.gitignore` : 60 fichiers, 3 291 047 octets, empreintes de chaque copie vérifiées contre les fichiers temporaires. Le journal complet est conservé séparément sous forme compressée. Aucun changement des données originales.
