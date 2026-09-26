# Contrat et constat de stabilité

Demande : « Les performances sont inquietantes, le jeu crash alors qu'on a juste la salle des machines. Meme pas encore de phase de jeu ».

| Référence | Artefact | Preuve |
|---|---|---|
| Salle des machines | game/scripts/main.gd, engine_room_art.gd, engine_room_controls.gd, shaders/stoker_hover.gdshader | boucle _process, advance_visual, refresh |
| Crash | Godot-2026-09-25-221058.ips, PID 22993 | pile Main::setup, RotatedFileLogger, OS_MacOS_Headless ; lancement confirmé par agent |
| Ancienne préversion | PID 4360, export macOS ouvert depuis plus de 2 h | ps : 42,7 % CPU, RSS 46672 KiB |
| Préversion actuelle | PID 96151, Godot --path game | ps : 3,3 % CPU, RSS 428512 KiB ; aucun message d'erreur dans game.log |

Symptôme : alerte de crash et inquiétude de performance. Objectif : identifier la fermeture et mesurer la chaufferie. Les réglages visuels et la découverte restent des tâches ouvertes distinctes.
Stratégie refine §5 : context_engineering + verified_reasoning, fondée sur rapport macOS, processus et mesures reproductibles.
Acceptation : test headless avec journal absolu réussit sans crash ; banc natif en activité puis pause mesure CPU/mémoire et erreurs ; préciser si le crash utilisateur correspond bien à cette alerte. Ne pas annoncer un crash du jeu corrigé sans reproduction.

## Vérification obtenue

Cinq suites et le témoin du paquet macOS passent sous lancement escaladé avec
journal absolu. Le crash headless initial est attribué au logger avant script,
pas à la scène ; une autre fermeture utilisateur reste non reproduite.
Banc natif : 10 s activité + 10 s pause, même script, une exécution avant/après.
Avant : 120 FPS, CPU utilisateur+système 3,18 s / 22,36 s, RSS maximum247824384.
Après plafond60 FPS, cache de dessin et faible consommation : CPU2,12 s /21,31 s,
RSS258670592. Le décor d'instruments a aussi été ajouté entre ces versions :
la comparaison n'isole pas chaque changement. Pas de test d'endurance annoncé.
