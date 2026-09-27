# Lieux fixes et trains sur la carte

Source privée : listings ALIS `observations/listings-20260927/carte.json` et
`glieu.json`, lecture via `tools/claude/alis_pretty.py`.

CARTE `0x305–0x34f` choisit un demi-côté de carré inclusif de 1 par défaut,
2 si `main+0x307b=1`, 4 si cette variable vaut 2. GLIEU `0x27c3–0x2832`
parcourt les wagons dont l'état est strictement inférieur à 3 : type4 fixe
le flag à2, type10 le porte à1 seulement s'il est inférieur à1. Le type4
prime donc quel que soit l'ordre des wagons.

CARTE `0x463–0x4a4` cherche le bit16, retrouve l'entrée ennemie, lit sa phase
et sa direction, puis appelle `0xb3b`. Le dessin ennemi `0xe7c` utilise sa
position x stockée plus40 et y, sur des cellules16px. Le rendu moderne
réemploie une seule locomotive du train_renderer à son échelle habituelle,
orientée d'après le heading réel. Il n'invente ni composition ni effectifs.
La position dessinée est la cellule logique, sans interpolation de phase.

Les slots actifs, y compris négatifs scriptés, sont relus à chaque dessin.
Aucune liste de trains vus n'est sauvegardée : sortir du carré les retire
immédiatement du rendu. La suppression et la reprise utilisent EnemyTrains.

Les lieux fixes ne consultent aucun masque de découverte (voir
`map-discovery.md`). Le code de tuile vient de la grille réelle, jamais d'une
conversion supposée du type de ville. `ecs_panel_art` charge les ressources
CARTE privées dans `map-resources.json`; chaque texture conserve sa taille
rapportée aux cellules originales16px. `draw_city_tile` permet au rendu des
rails de dessiner aussi les morceaux de ville voisins. Sans données privées,
le symbole de ville déjà écrit dans world_view sert de repli explicitement
moderne; il ne prouve pas une restitution originale.

Intégration : instance MapEntities, appel `draw(view)` au lieu de l'ancien
`_draw_cities`, propriétés view.encounters et view.wagons liées à app. La
méthode `draw_city_tile(view,cell,code)` est disponible pour les clusters.
Le parent conserve la responsabilité des hit-tests et du retrait du fog.

Test natif : visibilité aux limites/diagonales, rayon par wagon et état,
trains scriptés, disparition hors champ, suppression après sauvegarde,
présence des textures réelles de chaque lieu et couverture des six types.
