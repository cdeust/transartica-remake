# Couverture du jeu original — état local du 25 septembre 2026

Référence fonctionnelle : [manuel Amiga original reproduit par Lemon Amiga](https://www.lemonamiga.com/doc/transarctica/1676).
Les règles exécutables sont recoupées avec les scripts ALIS privés, leurs
listings et les notes dans `tasks/evidence/`. Cette grille décrit le code
actuellement présent dans `game/`, pas une promesse de campagne complète.

| Écran ou système original | Présent dans le projet | Écart à fermer |
| --- | --- | --- |
| Bandeau permanent : train, horloge, accès wagons, combustibles, vitesse | Chaufferie avec compteurs, horloge et commandes partielles | Composition cliquable, raccourcis entre scènes et accélération originale. |
| Chaufferie et chargeurs de lignite/anthracite | Décor interactif et calculs de chauffe, réserve, vitesse, frein | Direction inverse, sifflet, alarme et événements complets. Cadence réelle Amiga inconnue ; calibration provisoire. |
| Écran distinct des instruments | Code de jauges en chantier (`engine_instruments.gd`) | Reproduire disposition A–F du manuel, navigation depuis chaufferie et rendu lié aux champs ALIS ; vérifier chaque correspondance. |
| Salle de commandement, quartiers du capitaine, inventaire, journal, équipage | Journal sommaire et image de référence locale | Scènes complètes, zones actives, sauvegarde dans le boudoir, inventaire, personnel et décisions. |
| Carte générale et carte détaillée | Grille originale, villes, glyphes et vue locale partiels | Deux vues distinctes, aiguillages, défilement, coordonnées, événements et train réellement mobile. Le brouillard persistant des rails n'est pas établi par source. |
| Commerce, mines, ateliers, villes, espionnage, dynamite, éclaireurs, missiles | Données et recherches privées ; aucune boucle jouable complète | Interactions, ressources, missions et conséquences originalement déterminées. |
| Combat ferroviaire en scène entière | Absent | Wagons, soldats, armes, ordre, dégâts, victoire/défaite et mode de résolution automatique. |
| Récit, événements, fins, sauvegarde de campagne | Texte d'introduction et sauvegarde de session limitée | Scénario interactif, états de campagne, déclencheurs, fin et reprise cohérente. |

Le manuel établit que l'écran d'instruments est séparé de la chaufferie, avec
pression chaudière, vitesse, pression pistons, température, régulateur et sortie.
Il distingue une carte générale (plan officiel possiblement incomplet) d'une
carte détaillée centrée sur le train. Le champ de vision limité concerne les
éléments mobiles repérés par le wagon d'observation ; il ne prouve pas un
historique des cases ferroviaires découvertes. Ces points doivent guider les
écrans sans attribuer à l'original les choix de présentation de la préversion.

## Arbitrages du propriétaire après comparaison au manuel

Le 25 septembre, le propriétaire confirme explicitement le brouillard de guerre
comme évolution de gameplay voulue. Il privilégie la vue latérale des combats
originaux comme référence du voyage : train, wagons et paysage visibles, avec
mise à l'échelle sur le monde. L'histoire et la géographie restent originales.
Cette direction remplace l'interprétation « simple atlas de villes » et ne doit
pas être décrite comme une copie sans changement des règles de visibilité.

La scène de voyage et le combat partageront les positions du réseau et la
composition du train. Une projection latérale doit être définie sans confondre
l'abscisse du décor et les coordonnées de la carte. La connexion des aiguillages,
la progression et les règles de combat restent à implémenter et valider.

**Décision finale de projection, même échange : 2D oblique autorisée par le
propriétaire (« tu peux garder une 2d oblique, ca doit marcher »).** Elle remplace
la contrainte de vue strictement latérale ci-dessus, tout en gardant la proximité
visuelle du train et du combat comme objectif. Voyage et combat partagent le
monde, la composition et un zoom continu ; brouillard de guerre confirmé.

## Composition du train — exigence confirmée par le propriétaire

La vue d'ensemble et son menu, le bandeau listant tous les wagons, leurs fiches et
la réorganisation dans les villes équipées doivent être jouables. L'ordre est
persistant et partagé entre voyage, combat, inventaire, poids et capacités. Un
atelier peut réordonner les wagons ; cette action ne doit pas être un simple
changement du dessin. Les réparations, achats et mise à la casse ont également
leurs conséquences dans cette composition centrale. Référence : manuel,
CONTROL PANEL, INDUSTRIAL TOWNS et WORKSHOPS.

## Phases ultérieures confirmées : villes et commerce

Le propriétaire demande les écrans de ville avec achats/ventes de ressources et
achats de wagons. Ils appartiennent aux phases suivantes, après stabilisation de
la conduite et du déplacement. Les transactions doivent modifier stocks, lignite
et capacités réelles ; atelier et ville industrielle restent des services
situés dans le monde, distincts d'un menu universel accessible en route.
