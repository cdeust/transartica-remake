# Banc de conduite et décor glaciaire

Validation native sous Godot 4.5 sur macOS : boutons des deux combustibles au
taux 1, régulateur 199, avance de 10 cycles : lignite 1990, anthracite 490,
chaleur 374, réserve 2400, vitesse 15. Activation du frein puis un cycle :
stocks 1989/489, chaleur 409, réserve 2900, vitesse 0, régulateur 199 conservé.
Ces valeurs ont été lues à l'écran après les clics, pas seulement dans un test.

Le décor a été inspecté : locomotive conservée, reliefs glaciaires bas et
irréguliers, congères, neige horizontale, traverses et attaches. Carte en onglet,
noms visibles, données brutes optionnelles. Il reste un dessin original de
prototype, pas une reproduction des décors historiques.

Les tests Godot couvrent aussi les états initiaux, trois cycles de chauffe,
les chargeurs indépendants, le seuil de mise en mouvement, la consommation
206 à vitesse 300 pour la composition initiale, le frein, la suspension à un
événement non porté et les contrôles/sauvegardes de carte existants.

Limites : un cycle est une mise à jour originale de locomotive, pas une seconde.
Le modèle ne reçoit pas encore les changements de masse, les événements de
campagne ou les états externes. F5/F6 sauvegardent la carte uniquement.
Le contrôle du binaire Windows demande toujours une machine Windows.

Paquets reconstruits. Test du binaire macOS actualisé : conduite, ressources
empaquetées, chemin de sauvegarde et reprise de carte réussis. Fenêtre du paquet
ouverte et rendu vérifié après extraction de la nouvelle archive.
