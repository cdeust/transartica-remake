# Voyage et présentation, lot du4 octobre2026

Périmètre : masques d’interaction, panneau partagé, horloge et compteur
de cycles, composition entre flèches, notices du quartier général, matériaux
de la carte mondiale, reliefs/crevasses et raccords des voies. Les règles ECS
et la carte source sont conservées ; l’arrêt au contact arrière du convoi
est l’adaptation explicitement autorisée le3 octobre.

## Preuves

- Livre recalé sur la source moderne ; sept autres cutouts conservés.
  Test natif des huit highlights, GUI, redimensionnement et modals réussi.
- Panneau normal/travaux comparé sur images natives aux deux tailles.
- Partie réellement gagnée7190 reprise via OPTIONS :7217/7235, treize
  contacts pendant les travaux. Rapport7236..7238 :17 rails dépensés,
  cellule6,9 réparée au clic de fermeture, frein conservé.
- Carte mondiale7240 inspectée : papier propre, cadre commun, tracés de
  l’overview original conservés. Carte détaillée7242 : pont réparé,
  reliefs et rails visibles. Notices réelles7244/7246 : scène149 lignes,
  bande des wagons conservée.
- Voyage réel jusqu’à Rum7295 : contact physique6,10, treize wagons
  conservés. Foreuse800 sélectionnée7298, quantité1/prix confirmé7299,
  achat7300 et sauvegarde7301 : quatorze wagons, foreuse en dernière position.
- Ancienne restauration dans assert échoue en moteur macOS release réel ;
  correction réussie, debug=false. Test explicite des trois refus de restore.
- Main valide les préentrées foreuse/Hima/centrale et le cap physique.
  SessionSaves natif valide l’arc synchronisé et treize contacts au dessin.
- Revue indépendante des corrections de limites/reprise : APPROVE.

Les sauvegardes, captures intégrales et données historiques restent privées.
Les scripts de test les référencent pour les vérifications locales.

## Limites

L’acte1 et la campagne complète restent en cours. Les tests préparés de gares
ne remplacent pas les parcours réellement joués. La neige, certaines berges
et l’intégration du décor autour des villes restent à améliorer. Aucune
release Windows native n’est validée dans ce lot. La nouvelle correction
du livre a été inspectée par l’agent ; sa revue artistique propriétaire reste
ouverte. Le test tactique exige le moteur natif : tentative headless expirée,
puis exécution native réussie.

## Intégration distante

La tête distante f50c3cd contient23 commits d’animations de combat depuis
la base locale3f8efc6. Les conflits de cadence ont été résolus en retenant
l’implémentation distante, équivalente aux corrections de ce lot. Les
assets et rythmes Opus restent conservés. Deux documents locaux de handoff
diffèrent du distant : restaurés comme modifications non indexées, sans
publication ni suppression. L’intégration impose une extraction mécanique
de tactical_actor_motion.gd (913 lignes) pour satisfaire le contrôle
de taille ; validation du comportement après extraction requise.

Extraction vérifiée indépendamment contre le SHA source distant :52
signatures,31 wrappers, constantes et état conservés ; corps des fonctions
identiques après substitution du receveur et annotations de type.
Tests natifs de registration et mouvement réussis après intégration, sans
erreur de script. Le test vérifie notamment le modèle inchangé, les appuis,
les morts, la dynamite, les échelles et le démontage des cavaliers.
