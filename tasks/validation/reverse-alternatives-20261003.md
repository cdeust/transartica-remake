# Approches alternatives et arrêt physique

Statut : tests de modèle ajoutés ; réception native des variantes encore ouverte.
Aucune conclusion sur la campagne complète ou toutes les routes du monde.

Le contrat du propriétaire exige que les trajets non optimaux fonctionnent aussi.
`game/tests/test_reverse_alternatives.gd` utilise la carte ECS fournie et les
historiques effectivement parcourus. Les mutations de composition, ressources
et phase ci-dessous sont des préparations de tests, pas des actions de joueur.
Aucun raccord de carte ni événement de campagne n'est ajouté.

| Cas | Preuve de modèle | Réception native de cette variante |
|---|---|---|
| Approche en marche arrière de la crevasse6,9 avec6,9,13 véhicules | Trois préfixes de la composition réellement gagnée7087 ; contacts complets jusqu'à l'arrêt | À jouer pour6 et9 ; parcours13 sous la responsabilité du pilote principal |
| Demi-tour avant réparation puis retour | Dix pas du modèle sur l'historique réel, positions inchangées lors des deux inversions, nouvel arrêt sur la même crevasse | À jouer |
| Refus explicite de travaux puis réouverture | Dialogue original, cellule inchangée, arrêt conservé | À jouer |
| Rails absents ou juste sous le minimum | Quantités0 et minimum ECS moins1 ; aucun prélèvement ni réparation | À jouer |
| Ouvriers absents ou juste sous le minimum | Quantités0 et minimum ECS moins1 ; aucun prélèvement ni réparation | À jouer |
| Sauvegarde avant approche et à l'arrêt | Aller-retour JSON réseau, trajet et composition ; mêmes contacts | Reprise native à vérifier par le pilote principal |
| Sauvegarde pendant le rapport accepté | Rapport et quantités sauvegardés/rechargés ; aucun second prélèvement | À jouer |
| Sauvegarde après réparation | Même cellule réparée, même composition et mêmes contacts | À jouer |
| Arrivée en arrière à Rum et départ | Arrêt au port réel6,10, gare correcte, départ par l'intérieur caché accepté | Parcours principal en cours ; variantes6/9 à jouer |
| Arrivée avant à InSalah depuis une voie courbe | Historique gagné5020, phase ramenée dans la même cellule avant arrivée ; convoi complet, bonne gare | Arrivée5020 réellement jouée auparavant ; réception de la correction à refaire |
| Arrivée avant à Copenhagen depuis une autre voie | Historique gagné6027, phase ramenée dans la même cellule avant arrivée ; convoi complet, bonne gare | Arrivée6027 réellement jouée auparavant ; réception de la correction à refaire |

Les sauvegardes originales sont copiées sans changement dans
`reference-private/validation/reverse-obstacle-approach-earned.json`,
`forward-InSalah-earned.json` et `forward-Copenhagen-earned.json`.
Le test n'accède pas aux processus natifs en cours et ne simule aucun appel à
Main._process. Il appelle les composants du modèle, ce qui reste distinct du
playthrough demandé.

Résultat courant :32 cas de modèle passent. Journal privé :
`reference-private/validation/reverse-alternatives.log`.
Commande reproductible :

```sh
.toolchain/Godot.app/Contents/MacOS/Godot --headless --path game --script tests/test_reverse_alternatives.gd
```

Restent hors de cette réception : toutes les autres gares en jeu réel, approches
avec aiguillages différents, autres obstacles (lac et rails détruits), trains
plus longs que la composition gagnée13, sauvegarde complète Main pendant chaque
écran, événements de campagne et progression finale. Les suites existantes sur
les règles ECS et les gares ne remplacent pas ces parcours natifs.
