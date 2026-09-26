# Frein et ralentissement dans les scripts originaux

Offsets relatifs aux scripts ALIS décompressés `train.alis` et `time.alis`.
Les octets ont été vérifiés directement ; le décodage suit la source ALIS
révision `19a95afdc07b45d997467806d4dd1bf83c5f8076`.

| Commande ou état | Règle exacte | Preuve |
| --- | --- | --- |
| Levier de frein de TRAIN | Bascule l'octet `main+0x614a` entre `0` et `1` ; il ne modifie pas le régulateur. | `TRAIN 0x377–0x38f` ; octets originaux à `0x377`. |
| Régulateur | Écrit la vitesse **cible** `main+0x2fc4`, entre 0 et 300, depuis la position du curseur. | `TRAIN 0x628–0x665`. |
| Vitesse réelle | Mot `main+0x2fb4`. Si la réserve `main+0x2fc0` est épuisée, baisse de 5 ; sinon, si réserve >1500 ou vitesse déjà positive, approche la cible de 5 (ou copie la cible si l'écart est <5). | `TIME 0x280–0x2e3`. |
| Frein engagé | **Après** le calcul précédent, si la vitesse est négative **ou** `main+0x614a != 0`, TIME écrit `0` directement dans `main+0x2fb4`. | `TIME 0x2e4–0x2fa` ; octets originaux à `0x2e4`. |
| Mouvement | La distance ajoutée au reliquat à ce même pas dépend de la vitesse réelle déjà mise à jour. Un frein engagé donne donc un ajout nul. | `TIME 0x486–0x57c`, voir `navigation-playable.md`. |

Les opérations ALIS `oinf`, `odiff` et `oor` de `TIME 0x2e4` calculent
`vitesse < 0 OR frein != 0` ; `cbz24` à `0x2f6` saute le store si la
condition est fausse, sinon `0x2fa` écrit directement zéro. La baisse de 5
à `0x293` est déclenchée par **réserve épuisée**, non par le levier.
Le levier a donc l'effet d'un arrêt au prochain pas logique de TIME dans
ce binaire, sans décélération intermédiaire dans `main+0x2fb4`. Entre
le clic et ce pas, l'état précédent peut encore être affiché : ce délai
de planification n'est pas une pente de freinage.

Vecteur avec composition initiale de masse `1266`, réserve `2000`, vitesse
`100`, cible `0`, aucun taux de charbon, chaleur nulle. TIME calcule d'abord
le coût de traction `trunc((100 + 100×10)/45)=24`, laissant réserve `1976`.
Frein **relâché** : le régulateur cible zéro réduit la vitesse à `95` au
premier pas, puis `90` au second (coût suivant `trunc((95+95×9)/45)=21`,
réserve `1955`). Frein **engagé** : la vitesse devient `0` dès le premier
pas, réserve `1976`. Ces résultats séparent la décélération progressive du
régulateur de l'arrêt binaire du levier ; ils ne présument pas d'une durée
réelle en secondes par pas.

Le [manuel Amiga original reproduit par Lemon Amiga](https://www.lemonamiga.com/doc/transarctica/1676)
dit que le frein arrête le train sans changer le régulateur ni le chargement
du charbon ; il ne décrit pas une courbe de décélération du levier. L'attente
d'un freinage progressif peut être satisfaite en baissant la cible du
régulateur, mais lui attribuer cette loi serait un choix de conception
différent du comportement de `TIME 0x2e4–0x2fa`. Aucun seuil de vitesse
spécifique à l'arrêt en ville n'est établi par cette chaîne frein → vitesse
→ mouvement ; les gardes d'arrivée doivent être tracées séparément.

## Portage dans le remake — 26 septembre 2026

- **Modification** : `game/scripts/engine_state.gd`, `_drive()`. Frein engagé : la
  consommation est calculée comme dans TIME, puis la vitesse baisse de
  `SERVICE_BRAKE_STEP = 5` par cycle jusqu'à 0, sans suivre la cible du
  régulateur. Réserve épuisée et frein ne se cumulent pas (−5 au total).
- **Raison** : décision du propriétaire « oui frein progressif pour le remake »
  (FIDELITE.md, adaptations confirmées). Le pas de 5 reprend la baisse du
  régulateur `TIME 0x280–0x2e3` ; ce n'est pas une règle ECS du levier.
- **Résultante** : vecteur vitesse 100, régulateur 300 → 95, 90, … 0 au
  20ᵉ cycle, puis maintien à 0 ; régulateur conservé à 300 ; relâchement →
  reprise à +5. Le train continue d'avancer pendant le freinage.
  Vérifié par `tests/run_tests.gd` et `tests/test_playable_trip.gd`
  (`game/test.sh` : 7 suites PASS). Choix non tranché par la source : le
  non‑cumul avec la baisse de réserve épuisée.
