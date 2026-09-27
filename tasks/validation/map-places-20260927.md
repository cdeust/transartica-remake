# Bandeau, villes et ennemis — 27 septembre 2026

La référence explicite du propriétaire est la capture MacintoshRepository
`TAB.PLAY_.A.gif`, fournie en conversation le27septembre. Le bandeau ECS est
maintenant dessiné depuis les ressources YODA privées, avec ses commandes de
carte contextuelles, ses aiguilles et les miniatures de la composition réelle.
Les flèches défilent les longs trains ; les compteurs affichent l’état courant.

Extraction reproductible, depuis la racine du dépôt :

```sh
python3 tools/export_panel_resources.py reference-private/unpacked/yoda.alis reference-private/panel-resources.json
python3 tools/export_panel_resources.py reference-private/unpacked/carte.alis reference-private/map-resources.json --palette 0
```

Ces fichiers restent privés et ignorés par Git. Le dessin généré précédemment
reste le repli sans données historiques ; cette PR ne prétend pas le rendre
identique. La distribution publique ne contient aucun pixel historique.

Le brouillard persistant du prototype ne cache plus les villes et les voies de
la carte détaillée. La perception des ennemis est séparée : carré original de
rayon1,2ou4 selon les wagons en état de servir. Les ennemis retirés ou sortis du
champ disparaissent. Leur représentation actuelle est une locomotive, sans
convoi ennemi complet ni interpolation entre cases.

Les six décors de villes déjà produits sont intégrés dans une scène plein écran
suivant les bandes39/110/51 de l’original. Les commandes de commerce existantes
restent actives. Les textes et contrôles de transaction sont encore modernisés ;
les pages narratives de ville manquent. La fidélité complète n’est pas acquise.

Sources : [bandeau](../evidence/panel-layout.md),
[visibilité](../evidence/map-discovery.md), [entités](../evidence/map-entities.md),
[écrans originaux](../evidence/original-visuals.md).
[Wiki transmis par le propriétaire](https://transarctica.fandom.com/wiki/Transarctica_Wiki)
à consulter pour la suite : sa lecture directe a échoué dans cette session.
[Remake communautaire](https://sourceforge.net/p/transarctica-remake/wiki/Home/)
et [ALIS](https://github.com/maestun/alis) restent les pistes techniques identifiées.

Les tests couvrent les hotspots, les compteurs dans leurs cadres, le défilement,
les six familles de villes, les transactions et la perception ennemie.
Capture native conservée uniquement dans reference-private : elle contient
les ressources originales. Les résultats finaux et le SHA publié sont conservés
dans le reçu de revue du projet avant suppression du worktree.
