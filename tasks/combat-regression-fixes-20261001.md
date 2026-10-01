# Corrections après vérification de main

Demandes exactes : « fix les bugs du coup » ; « Tu dois garder ceci etant les animations de motion design d'opus ».

| Référence | Fichiers | Preuve |
|---|---|---|
| Clic wagon mobile | tactical_scene.gd / tactical_effects_geometry.gd | Reproduction native : wagon2 affiché, wagon1 sélectionné |
| Cache épave | tactical_scene._impact_fragments / tactical_materials.texture_for | Charge réelle : cache637×204, source épave667×220 |
| Secousse | tactical_scene._draw/_label/_gui_input et OriginalScreen.text_at | Reset du transform pendant les labels ; lumière séparée |
| Test chaudière | test_boudoir._events / boudoir_session / engine_state | Échec initial, puis3 passes ; cause à établir |
| Motion design conservé | assets/effects, assets/weapons, rocket shader, tactical_weapon_motion, launcher_scene/session, PACE | Commit main6dca252 et dernières consignes du propriétaire |

Symptôme : erreurs de sélection/rendu confirmées et assertion chaudière intermittente.
Objectif : corriger les causes et prouver les parcours natifs sans modifier les animations d'Opus.
Hors périmètre : direction artistique, nouveaux effets, rythme, règles source, publication distante.
Stratégie /refine : context_engineering et verified_reasoning, avec reproductions externes avant/après.

- [x] Fetch main6dca252 et créer/register le worktree isolé fix/combat-regressions.
- [x] Corriger sélection et cache avec fixtures avant/après.
- [x] Corriger cohérence du transform secousse et des clics.
- [x] Établir/corriger la cause de l'assertion chaudière.
- [x] Vérifier les animations et assets Opus inchangés.
- [x] Exécuter inventaire complet, parcours natifs et revue indépendante.
- [x] Garder une preuve durable et arrêter les tests ; nettoyage des sorties jetables après le commit.

Modules combat : combat_bugfix. Fixture chaudière : boiler_bugfix. Documentation et validation globale : root. Un propriétaire par fichier ; les autres worktrees restent protégés.

## Vérifications ciblées, 2 octobre

La nouvelle fixture native de combat échoue avec les trois fichiers source de
main6dca252, puis passe avec les corrections. Elle vérifie la sélection des
wagons interpolés, une destruction réelle par charge, les caches de matière et
de paroi avant, les profils de toit, puis les positions de pixels des labels et
des probes dessinées après les corps et la couche lumineuse. La tolérance est
zéro. Le modèle reste identique pendant les contrôles de présentation.

La comparaison initiale de toutes les couleurs de textures produisait des
écarts de rééchantillonnage nearest dans des rangées de neige et de halo.
Les probes opaques après les véritables méthodes de dessin contrôlent le
transform de sortie ; les glyphes natifs réels restent également vérifiés.
Les textures d'Opus restent dessinées par les méthodes existantes.

La reproduction chaudière injecte explicitement la perte de focus : session
en pause, chaleur5000, taux2, cycles0, aucun événement après callback. L'ancienne
assertion échoue. La fixture corrigée vérifie cette pause, reprend via la
commande existante sans await, puis vérifie exactement un cycle, chaleur5020,
surcharge, fermeture du boudoir et message de mort102 visible. Elle passe.
Le déclencheur exact de l'échec historique n'avait pas été journalisé ; cette
reproduction établit la dépendance au focus sans inventer cet historique.

Les 33 tests Python passent. Les assets, shaders, tactical_weapon_motion,
living_effects/living_particles/blast_pixel_volume et les modules de lanceur
d'Opus sont inchangés par rapport au main de référence. Aucun facteur PACE,
palette, durée ou recette d'effet n'a été modifié.

## Résultat final

`game/test.sh` sort avec0 : les64 suites passent, dont la nouvelle fixture de
registration, le boudoir natif et la campagne complète. Les66 lignes PASS du
journal incluent les résultats supplémentaires du parcours de campagne ; elles
ne représentent pas66 suites. Les33 tests Python passent également.

La campagne conserve10657 appels source,1713 cases, jour23 et lignite1067.
La sauvegarde/reprise au Mausolée donne le même résultat. La revue indépendante
approuve la correction des caches, coordonnées et transforms. Les règles source
et le motion design restent identiques.

Mesure CPU sur l'ancien benchmark d'effets inchangé,120 frames Apple M4 : draw
médiane3,655ms, p9511,362ms, maximum18,538ms ; update0,269/2,090/3,258ms. Le temps
GPU est exclu. Le benchmark n'appelle pas les trois modules corrigés ; les pics
de coût connus du motion design restent une limite, sans conclusion de gain
ou de régression causée par ce patch.

Preuves avant/après, inventaire, comparaison Opus, captures instrumentées et
benchmark dans [validation/combat-fixes-20261002](validation/combat-fixes-20261002/).
Les captures de probes valident la registration ; elles ne sont pas une nouvelle
proposition artistique. Aucun nouvel export ou lancement Windows n'est revendiqué.

Checkers source/craft sur le diff staged : zéro erreur et zéro warning.
Redaction et `git diff --cached --check` passent. Les processus de test sont
arrêtés. L'ancienne modification de todo du checkout principal, écrite par root
pendant la vérification, est conservée dans le patch de preuve avant intégration
locale. Les fichiers .DS_Store et les autres worktrees restent protégés.
