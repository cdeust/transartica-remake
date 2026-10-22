# Validation du runtime C++ et de l'interface restaurée

18 octobre 2026, macOS ARM64. Base 2ea408a, modifications locales non commitées.
Le mandat complet reste ouvert. Cette preuve couvre N1–N3 et la restauration
des écrans cités ci-dessous ; aucune acceptation artistique globale n'est déduite.

## Artefact réellement exécuté

`output/standalone-native/Transartica.app/Contents/MacOS/Transartica`

SHA256 : `1b65dee276763eca2f8aaac0a7fcf85522c3774604b1d3edb4ab94bd248f96e0`.

Build final : interface-final-build.log, sortie 0, 26,261 s, pic RSS 212912 Kio.
Liens inspectés avec otool : SDL2, libpng, FreeType, OpenSSL Crypto, json-c,
zlib, libc++ et System. Aucun Godot, godot-cpp ou GDExtension. Le programme ne
charge pas les scripts ; ils servent de références de portage.

Le lanceur `native-game/launch.command` démarre cet artefact. Ce paquet local
dépend encore des bibliothèques Homebrew et des assets du checkout. Les huit
peintures retenues sont liées à leurs originaux, voir artwork-links.json.
CARTE et peintures sont authentifiés au démarrage. Pas de preuve Windows/Linux.

## Vérification native avec entrées réelles

Lancement sérialisé sous tools/run_map_check.py, plafond 1024 Mio, SDL Metal.
Entrée démarre la partie. Les clics sur le bandeau ouvrent carte détaillée,
carte générale, quartiers, boudoir et cabine. Le capitaine ouvre l'inventaire ;
Échap le ferme. Un clic sur les cadrans ouvre les instruments ; le glisser du
régulateur règle 296. Deux pressions L activent le lignite FAST. L'horloge passe
de facteur 1 à 3 par un clic. La chauffe réelle mène au déplacement sur rails.
Espace met en pause ; F5/F9 ouvrent le livre, la saisie NATIVE1 et Entrée
écrivent/rechargent la sauvegarde. R réinitialise ; F6 montre l'accueil/options.
Le retour Échap depuis ces options n'a pas été vérifié dans cette exécution.

Captures F12 du framebuffer de cette application, examinées à l'écran :

| Fichier dans interface-captures | Écran |
|---|---|
| native-1.png | Cabine et bandeau de production restauré |
| native-2.png | Carte détaillée et commandes du bandeau |
| native-3.png | Carte générale |
| native-4.png | Quartiers généraux |
| native-5.png | Boudoir |
| native-6.png | Inventaire et cadre source |
| native-7.png | Instruments |
| native-8.png | Train déplacé, pause avant sauvegarde |
| native-9.png | Livre de sauvegarde et nom saisi |
| native-10.png | Carte après restauration |

Sources de composition : original_panel.gd, engine_room_art.gd,
engine_room_controls.gd, boudoir_session.gd, reception_screen.gd et save_book.gd.
Le premier prototype à barres de texte est rejeté par le propriétaire ; ses
preuves ne valent pas validation de cette interface. La restitution actuelle
réemploie les images et les régions de clic de production.

## État sauvegardé réellement restauré

interface-state.log et native-save-roundtrip.json consignent le parcours :
cycle 395, position (40,108695652173914 ; 63,108695652173914), vitesse/régulateur
296, carburants 1638/500, chauffe 1614, réserve 31803, jour 1 à 19:45,
facteur 3, pause active. Après sauvegarde, B/Gauche/L modifient frein, régulateur
et alimentation. F9 restaure les valeurs précédentes. Une seconde sauvegarde
produit exactement les mêmes octets :
`9e15ce8ee7e1874ee7768be73e63dc3c079000cf0e06b6349f139ada4c8e9e8e`.

## Tests et ressources

core-final-tests.log : 93 contrôles, zéro échec, CTest 0,47 s ; rails, moteur,
calendrier, pont temporisé, frontières, aiguillages, sauvegardes invalides et
cadence indépendante du découpage des frames. Le premier test contenait une
attente de géométrie droite sur une queue réellement courbe ; ce mauvais oracle
a été corrigé d'après la voie. L'échec initial est conservé dans core-tests.log.

interface-launch.log : sortie 0, arrêt automatique à 600 s demandé par CLI,
601,015 s mesurées par la garde, aucun dépassement, pic RSS du groupe possédé
196224 Kio (191,625 Mio). Il ne s'agit pas d'un benchmark apparié avec Godot.
Les vérifications de style/source n'établissent pas la fidélité du jeu.

## Critères encore ouverts

N4 : rendu complet des rails, occlusions, installations, villes et transitions,
marche arrière et tous les écrans/états de production. N5 : campagne, économie,
équipage, événements, IA, combats, audio, finale et migration des sauvegardes.
N6 : empaquetage indépendant du checkout, exécution Windows/Linux et mesures
comparables. Les contrôleurs absents arrêtent le parcours ou annoncent leur
indisponibilité. Aucun contournement de frontière ni règle inventée.

L'ancienne régression GDExtension Task31 reste conservée et incomplète. Aucun
commit, push ou publication n'a été effectué. Nettoyage propre : cleanup.json.
