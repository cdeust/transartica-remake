# Transartica

Remake personnel de l’édition anglaise Amiga 500 ECS : carte, histoire, commerce,
conduite et combats fondés sur les scripts originaux décodés. Les illustrations
et sprites sont redessinés ; Noita guide la lisibilité des pixels, les matières,
les éclairages et les effets. La locomotive massive du dessin de couverture
sert de modèle commun aux scènes, au voyage et aux combats.

La campagne intégrée va du départ original jusqu’au rétablissement du Soleil.
Le parcours de validation utilise les ressources gagnées, les ennemis par défaut,
les événements de faune et les commandes du jeu. Une sauvegarde au Mausolée
retrouve exactement le résultat du parcours continu : 10 657 cycles source,
1 713 cases parcourues, jour23, lignite1 067.
Voir [les preuves de campagne](tasks/validation/campaign-route-cleanup-20261001.md)
et [la couverture actuelle](tasks/validation/completion-matrix-20261001.md).

## Jouer localement

Depuis les sources sur ce Mac : `game/run_local.sh`.
L’introduction mène aux options ; START commence la partie. Les cinq plaques
permettent de choisir difficulté, combat manuel ou automatique, musique,
démarrage et chargement. F6 revient aux options pendant la partie.

Le bandeau illustré ouvre locomotive, instruments, boudoir, quartier général et
cartes. Cliquer les chauffeurs règle les deux alimentations en charbon ; les
instruments donnent accès au régulateur. Aiguillages et marche arrière suivent
le réseau original. Les villes proposent marchandises, personnel et ateliers ;
la composition du train permet réparations, réorganisation et armements.
Le boudoir donne accès au journal, inventaire, sauvegardes nommées et commandes
du capitaine. Les rencontres conduisent aux choix du récit ou au combat.

Les raccourcis sont configurables dans les options. Par défaut : L/A pour les
chauffeurs, B pour le frein, Espace pour la pause, M pour la carte, J pour le
boudoir, H pour l’aide, flèches pour la navigation, F5 pour sauvegarder, F6 pour
les options et R pour recommencer. Les commandes contextuelles affichées dans
les scènes conservent leur priorité. Les sauvegardes comprennent moteur, voyage,
commerce, hasard, campagne, dialogues, faune, combat, lance-missiles et audio.

## Distributions privées

`python3 tools/build_preview.py all` prépare les données locales et exporte :

- macOS : `builds/macos/Transartica.app` et `builds/Transartica-macOS.zip`.
- Windows : `builds/Transartica-Windows.zip` ; conserver EXE et PCK ensemble.

Les preuves d’exécution des artefacts sont consignées dans
[tasks/validation/desktop-artifact.md](tasks/validation/desktop-artifact.md).
Un export Windows réalisé sur macOS ne prouve pas son exécution sur Windows.
La concordance avec le matériel sonore Amiga et l’inventaire exhaustif des
variantes visuelles historiques restent des limites de vérification explicites.

Le nouveau code est sous MIT. Les données et sons historiques restent privés
dans `reference-private/`, `game/private-data/` et les builds ignorés.
Ces paquets ne sont pas des distributions publiques sous MIT.

## Vérifier

```sh
UV_CACHE_DIR="$PWD/.cache/uv" uv run --with pillow --with numpy --with scipy python -m unittest discover -s tests -v
game/test.sh
python3 tools/build_preview.py all
```

Les tests vérifient les règles documentées, les entrées natives, les sauvegardes
atomiques et une simulation identique à30/60/144Hz. Les captures utilisent le
vrai moteur de rendu. Le toolchain Godot4.5 local est dans `.toolchain/`.
L’acceptation esthétique appartient au propriétaire.

- [Contrat de fidélité](FIDELITE.md)
- [Sources de campagne](CAMPAGNE-SOURCES.md)
- [Carte originale](FORMAT-CARTE.md)
- [Villes et commerce](FORMAT-VILLES.md)
- [Suivi et limites](tasks/todo.md)
