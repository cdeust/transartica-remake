# Obstacles de voie : messages TIME et traitements YODA (27 septembre 2026)

Décodage statique ; listings complets privés dans `reference-private/observations/obstacle-handlers-20260927.txt` (produits par `tools/alis_disasm.py --all-entries`). Aucune exécution de ces chemins n'est présente dans `runtime.trace.gz`.

## Destinataire

TIME envoie ses messages à `LOC-40`, soit YODA : `olocw -40` lit vram−0x28 (`opernames.c:121`), écrit par `clivin` (`opcodes.c:1083`) ; YODA 0x356 lance `clive 6` (TIME). Le répartiteur YODA 0x1c/0x20 a un cas pour chaque code envoyé. La case candidate n'est pas franchie (`L0x3eb=1`).

## Traitements

Le traitement commun 0x2390 compte les RAILS (wagons 17/18 dont la marchandise vaut 1) et les esclaves (wagons 5/6). Il pose la question, puis consomme les rails dans l'ordre des wagons. Les textes viennent de TEXTEK (`reference-private/city-scripts/textek-messages.txt`).

| Tuile | TIME | YODA | Conditions | Effet si oui | Fin |
|---|---|---|---|---|---|
| 67, 69 crevasse | 0x24ed | 0x111 | rails ≥ 10, esclaves ≥ 15 | texte 74, 16–20 rails consommés, case → 63 (de 67) ou 64 (de 69) | voie franchissable |
| −116, 114 lac | 0x24ed | 0x126 | rails ≥ 8, esclaves ≥ 15 | texte 75, 21–25 rails, case → −121 ou −117 | voie franchissable |
| −105 < t < 0 voie détruite (msg 81) | 0x2401 | 0x13b | rails ≥ 2, esclaves ≥ 5 | texte 76, 2 rails, case → abs(case) | voie franchissable |
| 65 | 0x24d0 | 0x1e2 | aucune | atelier de gare (glieu + mine) | demi-tour (0x18e3), vitesse 0 |
| −120 pont | 0x24d0 | 0x104 | aucune | texte 52 | demi-tour |
| 78 mine | 0x2509 | 0x200 | aucune | question 22, mine d'anthracite, case → 79 | demi-tour |
| 79 | 0x2565 | 0x23a | aucune | texte 17 « END OF TRACK STRAIGHT AHEAD » | arrêt, pas de demi-tour |

Durée des travaux : esclaves + 30 × wagons LIVESTOCK (7) + 150 si une CRANE (16) est présente. La grue raccourcit les travaux, elle ne conditionne rien.

THE DRILL (8) n'est testée qu'en TIME 0x1c31 : premier ou dernier wagon, ligne y = 67, pour la case (32,67) code 35 → 2.

Refus de la question : effet exact non décodé (0x3037, libération du frein `main+0x614a`).

## Écart avec le souvenir du propriétaire

Le propriétaire se souvient de rochers percés par la foreuse et de ponts réparés par la grue. Le bytecode montre des crevasses et lacs franchis avec rails et esclaves, la grue n'accélérant que les travaux, et une seule case liée à la foreuse. Décision du propriétaire requise avant portage (FIDELITE.md).
