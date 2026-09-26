# Premier trajet de conduite

Référence des règles : ../evidence/navigation-playable.md. Parcours volontairement
limité à la ligne initiale (12,62) → (33,62), cap est. Les aiguillages code18 sont
traversés tout droit; arrêt de préversion avant code14 en x34. Cet arrêt est une
limite du portage, pas un événement original. Pas de villes, d'acteurs mobiles,
de marche arrière ni de sélection d'aiguillage dans ce jalon.

Sept suites Godot : PASS. Test intégré : moteur chaud, 60 cycles depuis la carte,
consommation constatée, position avancée et découverte mise à jour, sauvegarde
partielle/reprise, pause, frein, rejet d'une découverte malformée, sélection
ancienne effacée au redémarrage. Modèle : égalité aux cadences15/60Hz et limite.

Fenêtre native source : démarrage à froid depuis M; chargements normaux des deux
combustibles, régulateur174, vitesse observée174, cases et branche voisine
révélées, puis frein: vitesse0 au cycle suivant. Aucun crash constaté pendant
cette vérification; ce n'est pas un essai d'endurance. Les coordonnées à l'écran
et les deux lignes fixes de chargement ont été ajoutées après cette inspection.

La sauvegarde3 ne contenait aucun trajet: reprise du moteur existant au point
de départ, message explicite. La sauvegarde4 conserve la progression de trajet.
Le test utilise exclusivement .cache/trip-test-save.json, pas la sauvegarde joueur.
