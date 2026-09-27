# Publication Transartica et branches d'essai

Demande : « les changements doivent push, et les branches remote doivent etre clean ».

Dépôt : https://github.com/cdeust/transartica-remake (public).
Branche de livraison : `feat/station-arrival`, état initial `918e469`.
Elle contient les visuels, le nettoyage des ressources, le todo et les
intégrations moteur déjà réunies dans ce checkout. Publication par PR vers
`main`, sans fusion dans cette opération.

## Vérification avant push

- 30 tests Python réussis, aucun ignoré : `pre-push-python-20260927.log`.
- 11 suites du lanceur `game/test.sh` réussies : `pre-push-godot-20260927.log`.
- 4 suites complémentaires réussies (combat, ennemis, mines, quartiers) :
  `pre-push-godot-extra-20260927.log`.
- Aucun fichier suivi sous `reference-private/` ou `game/private-data/`.
- Les tests graphiques signalent encore la différence de largeur du sprite
  oblique de référence ; ce warning n'est pas une validation artistique.

## Branches d'essai retirées

Les PR #1 et #2 sont fermées. Leurs différences depuis `main` ne contiennent
que deux documents d'essai des hooks ; aucun code du jeu.

| Branche | SHA vérifié |
|---|---|
| `test/hook-cleanup-20260926` | `aa9deb0c70e33cc743c51e16bca01e608723c312` |
| `test/codex-hook-pr-20260926` | `ccdf0f9c7b623027d337ca6c094e785308572680` |

Le bundle `closed-hook-pr-branches-20260927.bundle` préserve les deux têtes et
leurs commits propres. `git bundle verify` réussit ; son prérequis est le
commit initial `6a45184ddb760a41846de643191bbe59aa3d3dce`, conservé sur `main`.
La suppression distante atomique a utilisé les SHA ci-dessus comme conditions
pour refuser toute suppression si une branche avait changé entre-temps.

Le checkout principal et le worktree d'essai d'une autre session sont conservés.
Les fichiers non suivis préexistants ne font pas partie de cette publication.

## Résultat distant vérifié

La [PR #3](https://github.com/cdeust/transartica-remake/pull/3) est ouverte vers
`main`. Le premier SHA publié et relu sur GitHub est
`c2d798bdeb6294129e84b071e28b86d487baea71` ; le présent compte rendu est ajouté
ensuite sur la même branche. GitHub indiquait `MERGEABLE`, sans contrôle CI
signalé pour cette PR ; les tests cités ci-dessus sont locaux.

`git ls-remote --heads origin` ne retourne plus que `main` et
`feat/station-arrival`. Les branches des PR #1 et #2 sont supprimées.
Le premier push avait échoué avec HTTP 408 ; le second a réussi avec
`http.version=HTTP/1.1` et `http.postBuffer=524288000` limités à la commande.
Aucun réglage Git persistant n'a été changé.

Les processus de test sont terminés. Quatre journaux moteur temporaires en
double ont été supprimés (555 octets) ; les journaux agrégés sont conservés.
Aucun nouveau worktree n'a été créé. Le checkout principal reste en place,
ainsi que `.claude/worktrees/hook-cleanup-20260926`, propriété d'une autre
session. Aucun de ces chemins n'a été supprimé.
