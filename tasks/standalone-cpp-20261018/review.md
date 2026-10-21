# Revue du premier runtime autonome

Revue statique indépendante par resume_checkpoint, 18 octobre 2026.

Correctifs avant validation native :
- Pas de régulateur : source15, Shift1 conservés.
- Commandes moteur/pause bloquées après arrêt de frontière ; état sauvegardable.
- Cadence schema1 limitée à1s, afin de refuser les sauvegardes à pas infinitésimal.
- Chargement transactionnel vérifie les ports et connexions ferroviaires, tout
  en autorisant les aiguillages modifiés après le passage du train.
- Erreur de création du dossier de sauvegarde affichée sans quitter la partie.
- SHA256 de CARTE et des huit peintures vérifiés au démarrage.
- Échecs de dessin SDL remontés explicitement.
- Temps écoulé rejeté lors de chargement, démarrage, perte de focus et pause.

La validation d'exécution est distincte, dans validation.md et les logs.
Les handlers de campagne, marche arrière, stations et travaux restent ouverts.

## Raccordement des panneaux

Revue indépendante suivante : R/options étaient inaccessibles après un arrêt ;
les raccourcis R et F6 sont rétablis. L'ancienne option --save ambiguë devient
--save-dir avec choix du nom dans le dialogue source. Le répertoire vide est
normalisé sans erreur de sauvegarde. Les clics du bandeau sont consommés une
seule fois ; les dialogues capturent les entrées et bloquent la simulation.
