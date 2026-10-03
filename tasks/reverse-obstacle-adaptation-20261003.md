# Proposition : arrêt du convoi en marche arrière devant un obstacle

Statut : autorisée par le propriétaire le3 octobre2026 : « Oui on fait cette correction ».
La campagne reste ouverte ; aucun acte livré.

## Défaut réellement observé

La partie continue depuis START atteint la seconde crevasse, cellule6,9,
en marche arrière avec13 véhicules. Les captures natives7150..7152 montrent
zéro véhicule avant le dialogue7154. Le journal Serov-Rum.log enregistre une
perte progressive6→5→4→3→2→1→0. La sauvegarde réellement gagnée est conservée
sans modification dans reference-private/validation/reverse-crevasse-earned-save.json.
Le jeu reste arrêté dans la question de travaux, avant paiement.

## Preuve et conflit

Le relevé privé obstacle-handlers-20260927.txt, TIME0x05e7..0x063f,
ne déplace le point logique que si l'entrée est autorisée ; sinon phase2 reste.
YODA0x18e3..0x1972 inverse le sens sans déplacer sa position.
La carte privée donne6,8=voie verticale,6,9=crevasse69,6,10=gare37.

Le remake dessine un convoi étendu, avec contacts arrière échantillonnés à
cursor-distance. Au dialogue réel, cursor=0 et l'historique disponible part
vers le nord depuis6,8.5. Les contacts requis vers le sud dépassent la limite
de voie avant la réparation. Refuser cette extension est correct ; le défaut
est d'avoir autorisé le déplacement du point locomotive jusqu'à cet endroit.
L'audit indépendant reverse_obstacle_geometry confirme cette incompatibilité.

## Adaptation proposée

Calculer l'occupation physique du convoi à partir des contacts déjà utilisés
par le rendu, séparément du point de déplacement TIME. En marche arrière,
le contact du dernier wagon devient le contact d'approche des obstacles.
Interrompre la progression dès que ce contact atteint la limite de la voie
autorisée et ouvrir les travaux pour cette même cellule obstacle.

Cela avance le déclenchement des travaux par rapport au point locomotive ECS.
Il faut donc autoriser explicitement cet écart, conformément à FIDELITE.md:9 :
« Toute modification des règles de fond exige une décision explicite du propriétaire. »

La réparation conserve la cellule, les prérequis, les coûts et le déroulement
ECS. Après validation réelle du rapport de travaux, les contacts peuvent
continuer sur la voie réparée. Inverser le sens conserve les positions de
tous les véhicules ; aucune téléportation ni rotation instantanée du convoi.
Les raccords, les villes et les événements de campagne ne sont pas redessinés.

### Conséquence vérifiée à la gare de Rum

La régression de l'approche gagnée montre qu'après réparation de6,9 le dernier
wagon atteint immédiatement la gare6,10, tandis que la locomotive est encore
à10,2. Garder l'ancien point locomotive pour cette arrivée recrée la disparition.
La correction utilise donc aussi le premier contact physique avec le port
réel de la gare pour déclencher son handler. Elle répond à la demande initiale
du propriétaire : entrée réelle en gare en avant/arrière, invitation au bon
endroit, aucun train disparu avant l'arrivée. Le départ reste l'émergence depuis
l'intérieur de gare déjà accepté le26 septembre, documenté dans
tasks/evidence/station-arrival.md. Les conditions de ville et de campagne restent
celles des cellules originales ; cette arrivée n'est pas un test de proximité.

## Portée à examiner avant implémentation

Trajet et persistance : définir l'arrêt d'approche physique, conserver la
cellule de travaux et la progression fractionnaire dans la sauvegarde.
Rendu : exposer les contacts exacts sans approximation de longueur cumulée.
Session/travaux : déclencher le handler sur la cellule rencontrée par le
contact de tête du mouvement, puis reprendre depuis le point d'arrêt physique.
La migration doit traiter les sauvegardes déjà invalides7150/7154 sans les
utiliser comme preuve d'une approche correctement jouée. Rejouer l'approche
depuis la vraie sauvegarde Serov6524 pour la réception.

## Vérification exigée

- Régression de l'approche réelle : convoi complet, aucun contact dans la
  crevasse non réparée, arrêt au premier contact avant/arrière.
- Continuité des positions individuelles à chaque inversion de sens.
- Refus de travaux sans ressources et demi-tour depuis l'arrêt.
- Paiement, rapport, réparation puis poursuite via commandes natives.
- Sauvegarde/reprise avant arrêt, pendant travaux et après réparation.
- Gares, aiguillages et caméra : suites existantes, puis observation native.
- Reprise de la même campagne jusqu'à Rum, foreuse et Urga ; release de
  l'acte1 seulement après sa validation complète.

Les changements de signe du sampler, l'extension dans la crevasse et la
conservation artificielle des dernières poses sont rejetés : ils masquent
le défaut ou déplacent le convoi sans respecter sa géométrie.
