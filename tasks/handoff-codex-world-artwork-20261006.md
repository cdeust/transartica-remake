# Instructions pour Codex — carte artwork (à donner le 6 octobre au soir)

Statut : EN ATTENTE. Ce bloc doit être recopié dans chaque checkpoint jusqu'à ce
que le propriétaire confirme que Codex l'a exécuté.

## Message à coller dans la session Codex principale

> Claude a revu ta carte artwork pendant que j'étais absent. Lis entièrement
> `tasks/review-world-artwork-claude-20261006.md` et
> `output/imagegen/world-artwork-20261006/regions-v2/README.md`.
> L'appel `cua.getApp('com.anthropic.claudefordesktop')` est bloqué depuis 07h49.
> Abandonne-le : la transmission à Claude a déjà été faite par fichiers.
> Ensuite, dans l'ordre :
> 1. Remplace `game/assets/travel/terrain/world-region-0..4.png` (v1, mal placées)
>    par les 8 tuiles v2 de `regions-v2/`. Importe-les avec Godot pour que les
>    `.import` et `.godot/imported` existent. Sans import, rien ne s'affiche en jeu.
> 2. Ajoute un test qui charge la vraie texture importée (pas seulement des vues
>    simulées), et vérifie en jeu natif le menu et la vue extérieure.
> 3. Ne masque les cases forêt/montagne d'origine dans `travel_terrain.gd` que là
>    où l'artwork est mesuré comme recalé.
> 4. Voies et relief : pose les portails `tunnel-*.png` sur les six entrées de
>    tunnel décodées (`tasks/evidence/underground-rendering.md` : (61,51) sud,
>    (30,58) et (51,39) ouest, (12,21), (105,23) et (113,58) est). Les portails
>    passent au-dessus des wagons qui entrent. Le tracé, les aiguillages et les
>    sabotages restent ceux de la source. N'invente pas d'autres tunnels.
> 5. Forêts : ajoute une couche de cimes (`canopy-*.png`) au-dessus du train et sous
>    le tableau de bord, sur les vraies cases forêt (116–132) qui touchent la voie.
>    Les cimes ne doivent masquer ni les aiguillages, ni les zones cliquables, ni
>    la flèche de direction.
> 6. Atténue les jointures entre tuiles (écart mesuré de 12 à 48 sur 0–255).
> 7. Valide en jeu natif (neige, montagne, forêt, lac, ville, menu), fais une
>    revue indépendante, puis commite et pousse. C'est ce qui remettra au vert le
>    contrôle de fin de session de Claude.

## Preuves

- Revue et captures : `tasks/validation/world-artwork-review-20261006/`
- Mesure : `tasks/validation/world-artwork-review-20261006/measure_regions.py`
- Livraison v2 : `output/imagegen/world-artwork-20261006/regions-v2/` (session
  Codex exec 01a11001, journal `.cache/codex/world-regions-v2-run.log`)

## Livraison Codex pour présentation par Claude

Les instructions ci-dessus ont été exécutées. Leur statut initial est conservé jusqu'à confirmation du propriétaire. Les huit régions v2, le master du menu, les cimes et les six portails sont importés et intégrés. Les tests chargent les vraies textures. Les masques vérifiés remplacent1012 cases de relief ;784 restent visibles par prudence. La revue indépendante et les captures natives passent.

À montrer au propriétaire :

- tasks/validation/world-artwork-native-20261006/public-menu.png : carte du menu dans le binaire macOS exporté, après reprise normale.
- tasks/validation/world-artwork-native-20261006/public-exterior.png : vue extérieure du même binaire et de la sauvegarde FINALQG.
- tasks/validation/world-artwork-native-20261006/terrain-{start,mountains,lake,forest,city}.png : scènes préparées.
- tasks/validation/world-artwork-native-20261006/forest-32-11-{off,on}.png et mouth-*-{off,on}.png : comparaisons préparées de couverture du train. Les sept sites ont des différences positives sous les pixels opaques des wagons, sans changement de simulation.
- .cache/public-release/orchestral-exploration-preview.mp3 : extrait de18 secondes ; les cinq compositions complètes sont dans game/assets/audio/orchestral/.

Preuves : tasks/evidence/world-artwork-20261006.md, world-foreground-20261006.md, orchestral-score-20261006.md et public-pack-independent-review-20261006.md.

La qualité artistique n'est pas déclarée acceptée : le relief paraît grossier au zoom rapproché, des anciens éléments restent superposés et les raccords régionaux sont atténués sans être parfaits. Claude peut maintenant présenter ces captures et recueillir l'avis visuel du propriétaire. Aucun message n'a été envoyé via Claude Desktop. La transmission utilise ce fichier demandé.

Le ZIP macOS courant est builds/public-v1/Transartica-macOS-v1.zip ; les anciens dossiers extraits peuvent être périmés. Le candidat Windows est exporté et inspecté, mais son exécution sur Windows reste à vérifier avant publication v1.
