# Couverture visuelle du remake

État du 27 septembre 2026. Exigence : tous les visuels de Transarctica Amiga
500 ECS anglais, redessinés avec la qualité de pixel art demandée, inspirée de
Noita. Codex possède le design, la préparation des assets et la revue visuelle.
L'intégration et le moteur restent dans la répartition existante avec Opus.

Cette matrice est un inventaire initial des familles, pas un inventaire exhaustif
des images originales. Les variantes inconnues restent à relever. Le statut
« complet » est interdit tant que cette recherche et le parcours des scènes
n'ont pas fermé les omissions. Les souvenirs du propriétaire orientent la
recherche ; ils ne bornent pas le périmètre.

## Sources et méthode

- Contrat et corrections : `FIDELITE.md`, `tasks/lessons.md`.
- Fonctions documentées : `INVENTAIRE.md`, `tasks/original-game-coverage.md`.
- Captures originales inspectées : `reference-private/art-direction/`.
- Édition et scripts disponibles : `reference-private/manifest.json`,
  `reference-private/unpacked/`, `reference-private/game-data/`.
- Villes et services : `tasks/evidence/city-scripts.md`,
  `reference-private/villes-decoded.csv`, `reference-private/city-scripts/`.
- Réseau et obstacles : `tasks/evidence/rail-network.md`,
  `tasks/evidence/obstacles.md`, `reference-private/CARTE.FIC`.
- Wagons : `tasks/wagon-art-catalogue.md`, `tasks/wagon-redesign.md`.

Les noms de scripts servent à orienter l'examen ; leur seule présence ne prouve
ni le contenu d'une scène ni toutes ses variantes. Pour chaque référence,
conserver une capture ou un relevé précis du script, l'état permettant de
l'atteindre et son équivalent dans le remake. Le propriétaire autorise les extrapolations artistiques : les signaler comme
telles. Elles ne prouvent ni une composition ECS ni un mécanisme de travaux.

## Livraison graphique du 27 septembre

32 PNG et leur remise sont disponibles dans [la galerie](../output/imagegen/visuals-20260927/index.html)
et [le document pour Opus](handoff-visuals-20260927.md). Intérieurs, villes, combat
avec 25 types, carte, voies, travaux, rencontres et campagne ont des dessins.
Les états ci-dessous décrivent le constat initial, avant cette production ;
le document de remise donne les livraisons et limites actuelles.
L’intégration et la fermeture des variantes restent ouvertes.

## Matrice de départ : constat avant production

| Famille | Preuve / point d'inspection | État constaté et livraison à réaliser |
| --- | --- | --- |
| Chaufferie | Capture `original-engine-room.png`, `engine_room_art.gd`, assets `engine-room/` | Décor et couches présents. Revue de cohérence avec toutes les nouvelles scènes à faire. |
| Instruments de conduite | `engine_instruments.gd`, `instrument_art.gd`, couverture fonctionnelle | Écran présent ; réception graphique à taille réelle à distinguer de la validité des valeurs. |
| Salle de commandement | Capture `original-command-room.png` inspectée | Première illustration produite ci-dessous. Couches, zones actives et intégration manquent. |
| Boudoir / quartiers du capitaine | Couverture fonctionnelle, types GENERAL QUARTERS et BOUDOIR du catalogue | L'extérieur du wagon ne fournit pas son intérieur. Relever la scène propre au boudoir avant dessin ; ne pas la remplacer par le commandement. |
| Journal, pensées, inventaire, équipage | `tasks/original-game-coverage.md`, journal de `main.gd` | Journal textuel partiel. Relever les présentations et objets interactifs originaux, puis dessiner leurs scènes et états. |
| Villes vues depuis le voyage | `_draw_cities` dans `travel_world.gd` | Repères circulaires et noms. Architectures, silhouettes et raccords à la voie à produire d'après les variantes originales. |
| Écrans des villes | `city_screen.gd`, preuves des scripts de ville | Transactions en panneau textuel. Décors illustrés, personnages et zones actives à produire. |
| Services urbains | Menus de `city_screen.gd`, scripts `glieu`, `usine`, `mine` à examiner | Commerce, marchés, garnisons, ateliers et mines à distinguer selon les preuves. Ne pas déduire le nombre de décors du nombre de villes. |
| Vue générale du train et fiches de wagons | Couverture fonctionnelle, table `train_wagons.gd` | Atlas extérieur présent. Vue de gestion, fiches illustrées et représentation de la réorganisation à inventorier et produire. |
| Train en voyage | Atlas `vehicles-overhead`, catalogue de 25 types | Dessins intégrés selon le suivi existant. Revue des extrémités, attelages et variantes de chargement reste ouverte. |
| Scène de combat | Couverture fonctionnelle ; scripts privés à tracer | Scène entière à relever et produire : cadre, rails, décor, distance entre convois et échelle lisible. Aucun écran de combat final validé. |
| Train au combat | `tasks/wagon-art-catalogue.md`, PNG détaillés | Dessins de couleur disponibles ; détails adaptés à la vue rapprochée, intérieurs, matériaux et pièces mobiles manquent. |
| Adversaires et acteurs du combat | Inventaire mécanique ; scripts et captures à relever | Trains ennemis, soldats, armes, projectiles, actions et résultats à recenser dans l'original, puis dessiner/animer. |
| Dégâts et effets | Contrat artistique des wagons, `pixel_field.gd` | Effets isolés insuffisants : prévoir états intacts/endommagés/détruits, impacts, fumée, débris, lumière et occupation matérielle par instance. |
| Carte générale | Couverture fonctionnelle, `world_view.gd` | Présentation cartographique à refaire en conservant la géographie décodée. Vérifier son accès et sa distinction avec la carte détaillée. |
| Carte détaillée / paysage de voyage | `travel_world.gd`, `ice-field.png`, données originales | Fond glaciaire présent. Inventorier terrains et lieux spéciaux prouvés ; habiller sans modifier les coordonnées ni masquer les voies. |
| Rails | `_draw_rail_tile`, `_draw_rail_segment`, `rail_glyphs.gd` | Tracés fonctionnels. Produire une famille graphique cohérente de lignes, courbes, croisements et raccords couvrant les codes décodés. |
| Aiguillages | `_draw_switch_state`, réseau décodé | Traits et pastilles colorés. Dessiner lames, traverses, mécanisme et états de direction ; rendu lié à l'état réel du réseau. |
| Obstacles et zones de travaux | `tasks/evidence/obstacles.md`, travaux en cours dans `track_works.gd` / `works_dialog.gd` | Crevasse, lac et voie détruite documentés statiquement. Produire états avant/pendant/après selon les traitements vérifiés. Le dialogue de travaux ne remplace pas leur présence visible sur la carte. |
| Ponts, passages et foreuse | Même preuve d'obstacles, lignes propres au pont et à THE DRILL | Relever les images originales. Ne pas transformer automatiquement tout pont en chantier ni toute montagne en passage forable. |
| Récit, rencontres, introduction et fins | `CAMPAGNE-SOURCES.md`, scripts privés `present`, `scene*`, `soleil`, `mort` à examiner | Dénomination des fichiers = piste seulement. Recenser les scènes réellement affichées, personnages, variantes, transitions et dénouements. |
| Interface commune, menus, sauvegarde et transitions | Captures originales, code d'interface et couverture fonctionnelle | Harmoniser bandeau, icônes, états actifs/inactifs, curseurs et écrans de transition ; établir la liste originale avant clôture. |

## Combat : contrat de présentation

Le rappel du propriétaire impose une étude spécifique de la scène et de
l'échelle du train au combat. Le zoom de la vue de voyage ne vaut pas validation
du combat. La décision de véhicules vus de dessus en voyage reste acquise ;
elle ne dispense pas de retrouver et comparer la composition de combat ECS.

À relever sur une référence de combat : surface occupée par la scène et le
bandeau, orientations, proportions des wagons et des acteurs, disposition des
deux voies, défilement, sélection et effets visibles. Aucun rapport d'échelle
numérique n'est fixé avant ce relevé. La même composition et les mêmes dégâts
doivent persister entre les vues ; les virages ne changent pas le gabarit.

## Critères graphiques de réception

Chaque entrée détaillée devra passer séparément les étapes suivantes :

1. Référence identifiée, variantes et conditions d'apparition relevées.
2. Dessin original du remake produit ; prompt et fichier source conservés.
3. Matières lisibles, silhouettes distinctes, lumière cohérente, pixels nets
   et densité de détail organisée à la taille de jeu. La mention « Noita »
   dans un prompt ne prouve pas la qualité du résultat.
4. Découpage en décor, personnages, objets mobiles, masques d'interaction et
   états nécessaires. Pour le combat : matériaux et pièces séparés explicites.
5. Intégration raccordée aux états réels. Aucun bouton de décor sans action,
   aucun chantier toujours intact après réparation.
6. Capture native et essai des interactions ; revue du passage entre scènes,
   du zoom, de la lisibilité et de la sauvegarde lorsque l'état est persistant.

La couverture se contrôle dans les deux sens : chaque scène originale a son
équivalent ; chaque adaptation est identifiée comme telle. Un parcours de
campagne doit ensuite rechercher les scènes et variantes manquées. Aucun
pourcentage de complétude n'est publié tant que le dénominateur reste inconnu.

## Première production : commandement

Fichier : `output/imagegen/command-room-20260927/command-room-v1.png`.
Prompt exact : `output/imagegen/command-room-20260927/prompt.txt`.
Production avec l'outil intégré imagegen, capture ECS locale comme référence.
Dimensions vérifiées : 1821 × 864 pixels. Statut : illustration de travail,
non intégrée, non acceptée comme scène jouable.

Revue visuelle : table centrale, opérateur radio gauche, officiers au fond,
officier au premier plan droit, bibliothèques, fenêtres et éclairage suspendu
conservés dans la composition. Le bandeau est exclu pour être assemblé séparément.
La table dessinée est une illustration : elle ne remplace pas CARTE.FIC.

Limites à corriger avant intégration : personnages et décor fusionnés, détails
très fins à contrôler après réduction, image de largeur non standard pour la
grille actuelle, éclairage et contours à vérifier à la résolution native.
Le boudoir n'est pas couvert par cette image. Prochaine préparation : fond sans
personnages, sprites séparés, puis masques relevés sur les objets réels.

## Propriété et vérification de cette étape

Audit du code et des fichiers disponibles uniquement ; aucune nouvelle preuve
de lancement n'est revendiquée. Aucun fichier de moteur n'a été modifié pour
cette étape. Les modifications existantes de `main.gd`, `rail_network.gd`,
`train_journey.gd`, de son test et les nouveaux fichiers de travaux appartiennent
à l'intégration en cours et sont conservés. Pas de commit ni publication.
