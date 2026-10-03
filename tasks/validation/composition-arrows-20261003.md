# Miniatures du train et flèches de défilement

La capture native7167 montre une miniature au-dessus de la flèche gauche.
Le code dessinait le dernier wagon, diminuait la position, puis contrôlait si
cette position avait dépassé la limite. Ce contrôle arrivait après le dessin.

`original_panel.gd` calcule désormais les transformations des miniatures et
leurs bornes alpha avant de dessiner. Une miniature qui dépasse la fenêtre
n'est pas dessinée ; elle devient accessible en faisant défiler le convoi.
La taille et l'ordre des miniatures restent ceux de l'atlas partagé du train.

Les bornes viennent du panneau existant : flèche gauche en dessous de x14,
flèche droite au-delà de x304, placement des wagons depuis x300, bande de
composition y149..158. La fenêtre x14..300 conserve donc aussi la séparation
originale de quatre pixels logiques à droite. Références :
`ecs_panel_art.gd::scroll`, `original_panel.gd::_draw_composition` avant correction
et `tasks/evidence/panel-layout.md` pour le cadre ECS320×200 et son adaptation.
Aucune marge nouvelle n'est inventée.

Vérification de modèle : `game/tests/test_composition_arrows.gd`, compositions
13 et14, tous les indices de défilement, fenêtres1440×900,1280×800 et600×1000.
La variante `--legacy-layout` conserve le placement fautif pour reproduire le
chevauchement ; elle échoue. Le placement corrigé et les commandes de défilement
gauche/droite passent. Journaux dans `reference-private/validation/` :
`composition-arrows-before.log` et `composition-arrows-after.log`.

Réception native restant à faire par le pilote principal : recharger l'application
corrigée, inspecter la flèche gauche et la flèche droite, faire défiler dans les
deux sens avec13 puis14 véhicules, redimensionner la fenêtre et inspecter à
nouveau les miniatures. Les calculs de bornes ne remplacent pas ces observations.
