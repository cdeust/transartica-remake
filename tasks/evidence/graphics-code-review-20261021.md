# Revue du code graphique, 21 octobre 2026

Verdict : aucun défaut bloquant relevé dans les fichiers examinés. La revue est
indépendante pour la correction UV et le compositeur. Le relecteur avait écrit
le correctif d'occlusion et son test ; cette partie constitue une auto-revue.
Une validation indépendante de l'occlusion ne peut donc pas être déduite de ce document.

Périmètre : `.claude/worktrees/noita-pixel-world/native-game/`. Lecture seule du
code et des journaux existants, sans compilation ni nouveau lancement du jeu.
La retouche artistique de Turin encore en cours n'entre pas dans ce verdict.

| Partie examinée | Constat vérifié dans le code |
| --- | --- |
| `view/world_passages.hpp:11`, `view/world_passages.cpp:182` et `:209` | Les coordonnées source restent en double jusqu'à la conversion des UV SDL. Le calcul ne réintroduit pas l'addition en float qui dépassait le bord de la peinture de1322pixels. |
| `view/world_passages.cpp:86` et `:98`, `view/world.cpp:90` | Le plan de bouche reprend les métadonnées authentifiées. Le masquage entier exige les deux contacts ferroviaires et le milieu échantillonné souterrains ; un sommet visible au-delà de la bouche empêche cette suppression. Les axes des croisements15/16 reprennent `RailNetwork::progress_speed`. |
| `tests/world_join_compose.cpp:189` | Le mode `area-v1` intègre les intersections des texels source avec l'empreinte projetée. Les limites du crop sont respectées. La prémultiplication exclut la couleur des pixels transparents pendant la réduction ; le mode bilinéaire antérieur reste le défaut. |
| `tests/world_join_compose.cpp:283`, `:323` et `:386` | Une exception de ville vérifie son identité dans l'inventaire authentifié et reste locale au patch. Les protections explicites restent prioritaires. Un patch ultérieur sans autorisation conserve les pixels de ville déjà réparés. |

Les tests ont été lus : `world_cover_tests.cpp` soumet V4/H2 à trois densités ;
`world_train_cover_tests.cpp` contrôle les croisements et les six plans de bouche.
`world_join_compose_validation.py` vérifie des résultats RGBA attendus, dont les
poids fractionnaires et l'exclusion des couleurs transparentes. Il vérifie aussi
le refus des identités de ville incohérentes et la conservation des protections.

Journaux inspectés dans `disk-hygiene-1rt4a5v8/` :

- `cover-before.log` reproduit l'erreur UV, sortie1. `cover-metal.log` atteint les six soumissions V4/H2, sortie0.
- `ctest-tunnel.log` contient19tests réussis sur19, sortie0, pic du groupe de processus70304KiB.
- `area-after-test.log` contient24cas réussis, sources inchangées, sortie0, pic25424KiB.

Ces journaux établissent leurs contrôles ciblés. Ils ne constituent pas une
acceptation visuelle des peintures ni un parcours complet de campagne.

Empreintes SHA-256 des sources relues :

```text
ab0589deb2bd7d6e3218b59f14f548c54c1fd337d640acf7e014fa84276c7c7e view/world_passages.cpp
d065009f3cd3897c195f39ccd0a8078c967d4a3213f576a61367353945189407 view/world_passages.hpp
83b490c3040aa0db38b7f513b544c6034a821b91882ef11664a77f9c16167c43 view/world.cpp
b374cd0de98061e31487daf534ec9441093e2fda84cb6abe49fb52f6ab452ada view/view.h
18a0a54b6e77d08d4cce8f30241b5e454c224530a95f3ee4bcf1d3ea75a59b8d tests/world_cover_tests.cpp
29f14a6bc72a27d0c190cb7249cca98b91735bc2bb54620b59cc1e874d00bb2e tests/world_train_cover_tests.cpp
79f965d57bf60264d77d01f749cf0ab494a59f1b0f117f5fd3890a432296a7d8 tests/world_join_compose.cpp
ca5a0bc300a37313e07307abe13f6bb662d69b0a3de377fadb3d653a4fca0443 tests/world_join_compose_validation.py
```

## Complément : interpolation du raccord horizontal

Lecture indépendante de `view/world_painting_join.hpp` après la correction
SDL2 qui soumet chaque triangle séparément. Aucun défaut bloquant relevé dans
ce changement et ses appels depuis `world.cpp`, `world_passages.cpp` et
`tests/world_join_render.cpp`. Aucun test supplémentaire lancé par le relecteur.

L'intervalle commence au centre du dernier texel nord et finit au centre du
premier texel sud. Les UV sont calculés dans les crops validés. Le rectangle
optionnel réduit la bande dessinée sans modifier les références utilisées pour
calculer l'alpha. Le culling conserve les bandes qui intersectent le viewport.
Dans `cover_painting`, la reconstruction reste limitée au rectangle de couverture
demandé. La soumission séparée des triangles garde les mêmes sommets et leurs
attributs. Cette vérification suppose les peintures opaques déclarées par le helper.

Les20CTest, la fixture analytique GPU et la capture finale Turin sont signalés
réussis par root ; ce complément ne revendique pas une nouvelle exécution.

```text
ae402b69db274bdc35365b7a059931293bd4aabcd5cf8ebe445ec312b3b7c0d8 view/world_painting_join.hpp
5832b43deb837fbed112979d556215558a634102524e193f2ad394440e7157e9 view/world.cpp
2455eb54bdff9f9012f1a32c8c5156e824a503af2bd9fe2ae56490ec9e2e8649 view/world_passages.cpp
2a1d893713ee1d3e4a36c02db4cb1f64a9998a76e95bf1ca1bf6a51e3abfeb9d tests/world_join_render.cpp
```
