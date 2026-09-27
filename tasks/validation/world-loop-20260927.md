# Rencontres et combat automatique — 2026-09-27

Le calendrier déclenche les apparitions selon la difficulté originale. Les
ennemis avancent sur le réseau et une rencontre interrompt immédiatement les
cycles supplémentaires du temps accéléré. L’option Combat de l’accueil active
la résolution automatique attestée par le manuel. La victoire applique pertes,
wagons détruits, butin et retrait définitif de l’ennemi ; le voyage reprend après
le rapport. La défaite bloque le voyage et ramène aux options.

Les sauvegardes conservent les ennemis, leur historique d’aiguillages, les
réglages, la rencontre en attente et l’état du générateur aléatoire sans perte
sur ses entiers64bits. Le chargement JSON rétablit les champs ennemis en entiers
pour conserver l’arithmétique du déplacement. Une force négative est rejetée
avant toute mutation, correction issue de la revue indépendante.

Validation : les20suites de `game/test.sh`, dont trois ajoutées au lanceur,
et le test `test_world_encounters.gd` exécuté aussi dans une fenêtre native
Godot4.5 sur macOS. Ce dernier exerce les contrôleurs d’entrée de la scène,
pas une automatisation des clics du système. Les scénarios couvrent le défaut
manuel, l’apparition, la sauvegarde en attente, le choix automatique, la victoire,
la défaite, le refus des sauvegardes invalides et l’absence de double butin.

Limites : le combat tactique reste indisponible ; les rencontres manuelles
l’indiquent et donnent accès à l’option automatique. Le rapport de défaite
reste provisoire : l’épitaphe105 et la séquence de mort propre au combat ne
sont pas encore présentées. Les ennemis ne sont pas encore dessinés sur la
carte. Le générateur Godot n’est pas celui d’ALIS. La campagne complète,
l’acceptation graphique et les exécutables Windows ne sont pas validés.

Sources : [règles ennemies](../evidence/enemy-trains.md),
[transaction automatique](../evidence/automatic-combat-integration.md).
Ce lot dépend de la PR#4 et ne justifie aucun pourcentage global de portage.
