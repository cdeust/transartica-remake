# Catalogue graphique des wagons · 26 septembre 2026

## Demande

> Opus is managing the current work, but said explicitely he would not design the other wagons, so you'll have to handle this with the list of wagons present in the game and designing them the same way you did the first 6. Also keep in mind we will need a much more zoomed version and highly detailed version of the wholes wagons and train motrice for the fights. Keep in mind we're using noita like pixel management. so explosion will have impact and fights and cannon fire also.

## Références

| Référence | Preuve locale |
|---|---|
| Six dessins retenus | `output/imagegen/vehicles-overhead-prototype-v2.png` et manifeste JSON |
| Décision de dessus | commit `98760c0`, `tasks/todo.md` |
| Types 1 à 25 | `reference-private/commerce.json`, `wagon_names` |
| Fonctions originales | `reference-private/city-scripts/texte2k-messages.txt`, messages 60 à 81 |
| Six types initiaux | `game/scripts/train_wagons.gd`, `INITIAL`: 1, 21, 2, 3, 17, 23 |
| Travail parallèle | `.claude/worktrees/overhead-train`, branche `feat/overhead-train` |
| Effets de pixels | `game/scripts/pixel_field.gd`: effets visuels, pas de destruction de caisse |

Symptôme : dix-neuf types achetables n'ont pas de dessin dédié.
But : livrer ces dix-neuf dessins originaux du remake, avec des sources détaillées pour préparer le combat rapproché.
Hors périmètre : modifier l'intégration d'Opus, les règles historiques ou implémenter le combat dans cette livraison artistique.

Stratégie refine : contexte établi par les sources locales et exemples visuels réels; vérification externe par inventaire, métadonnées PNG et comparaison des images. Les nouvelles silhouettes sont des choix artistiques du remake.

## Plan et réception

- [x] Retrouver la planche et les 25 noms avec leurs fonctions originales.
- [x] Produire un fichier distinct par type manquant, avec prompt conservé.
- [x] Préparer les six véhicules de départ en version détaillée, locomotive comprise.
- [x] Vérifier les 19 identifiants manquants, dimensions, alpha et empreintes des fichiers.
- [x] Documenter les besoins artistiques des impacts et explosions.
- [x] Conserver les livrables et un compte rendu pour l'intégration locale.

## Combat : exigences à préserver

Les dessins détaillés fournissent la couleur. Ils ne constituent pas à eux seuls des véhicules destructibles. Voyage et combat doivent conserver la même silhouette, les mêmes attelages et positions de pièces. Un zoom ne change ni la taille physique ni les coordonnées des impacts.

L'intégration devra séparer caisse/châssis, toit, équipement mobile et chargement. Canon, mitrailleuse, harpon, foreuse et grue auront un pivot et une image indépendante avant de bouger ou d'être arrachés. Ne pas tourner tout le wagon pour orienter une arme.

Les données de destruction distingueront occupation solide et matériaux (métal, bois, verre, charbon, liquide, végétation selon le dessin), avec un état par instance. Ne pas déduire le matériau de la couleur : neige et métal clair peuvent partager une teinte. Les images générées ne sont pas des masques physiques certifiés.

Les impacts retireront les cellules touchées; rendu, collisions et débris devront utiliser le même état. Résistance, inflammation et propagation restent à mesurer dans le prototype de combat : aucun coefficient physique ni performance n'est promis ici.

Acceptation future : perforation persistante après un tir localisé, éléments détachés par explosion, dégâts conservés après zoom et sauvegarde/reprise, résultats identiques pour mêmes entrées/graine à différentes cadences. Une explosion décorative ne suffit pas.

## Revue

25 PNG individuels, 1024 × 1536, soit 43 153 389 octets au total. Contrôles de lecture, identifiants, dimensions et transparence des coins : 25/25. Inventaire avec SHA-256 : `output/imagegen/wagon-catalogue-20260926/catalogue.json`. Galerie locale : `output/imagegen/wagon-catalogue-20260926/index.html`. Les 25 prompts exacts sont conservés dans le même dossier.

Les dessins sont des sources artistiques non intégrées. Les contours semi-transparents, les quelques détails de volume et le recalage du gabarit restent à vérifier sur le décor lors de la préparation de l'atlas. Matériaux, pièces mobiles, intérieurs destructibles et ancrages de combat ne sont pas encore produits. Aucun test de jeu n'est revendiqué pour cette livraison d'images.

## Commits disponibles pour Opus

Livraison locale déjà présente sur `feat/station-arrival`, dans cet ordre :

- `314e869` : premier lot de dessins, prompts et contrat artistique.
- `6d36928` : suite des types manquants et locomotive détaillée.
- `ce06da1` : variantes détaillées des véhicules initiaux.
- `3905d66` : galerie, inventaire vérifié et documentation d'intégration.

Contrôle de remise : les 25 empreintes SHA-256 du catalogue correspondent aux fichiers locaux et aux blobs de `HEAD`; les 25 PNG mesurent 1024 × 1536 et couvrent les identifiants 1 à 25. Opus peut utiliser ces commits pour préparer l'atlas. Ils sont déjà dans l'historique de cette branche : ne pas les cherry-pick une seconde fois sur celle-ci.
