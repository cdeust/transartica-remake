# Transartica : runtime C++ autonome

Le nouveau programme ne charge ni Godot, ni GDScript, ni GDExtension.
Les anciens fichiers restent des références de règles et de données.
Le runtime C++ est compilé et jouable sur le Mac de validation avec les
ressources privées. Le paquet final a été lancé après les corrections graphiques
du 21 octobre 2026. Une campagne complète terminée par un joueur reste à vérifier.

## Construire

Prérequis de compilation : C++20, CMake >=3.20 et pkg-config. Installer aussi
SDL2 >=2.0.18, libpng, FreeType, json-c et OpenSSL Crypto.
Sur le Mac de validation, les bibliothèques proviennent de Homebrew.

```sh
cmake -S native-game -B CHEMIN_BUILD -DCMAKE_BUILD_TYPE=Release
cmake --build CHEMIN_BUILD --parallel 1
ctest --test-dir CHEMIN_BUILD --verbose --parallel 1
CHEMIN_BUILD/Transartica
```

Créer/enregistrer le répertoire de build selon la procédure disk-hygiene du
projet. Sur la machine de travail, les vérifications sont sérialisées et bornées
à1Gio par le garde local du projet.

Le dépôt publié contient le code ; les assets historiques et les jeux de données
dérivés restent privés. La compilation seule ne fournit pas un jeu jouable.
Pour lancer le programme et les tests dépendant des données, disposer du jeu de
ressources privé du projet dans `game/private-data/` et `game/assets/`.
L'inventaire [runtime-assets.json](packaging/runtime-assets.json) précise les
entrées nécessaires ; les manifests référencent aussi leurs images et sons.
Conserver ces dépendances et leurs empreintes, notamment le manifest d'édition
`game/assets/interface/original-data-manifest.json`. Une image disque du jeu
historique ne remplace pas directement ce jeu de données déjà décodé.

Pour retrouver exactement le paquet local validé, fournir également sa version
privée de `game/assets/travel/terrain/world-artwork.png`. Le dépôt conserve
l’aperçu public déjà présent sur main.

Les chemins de développement sont compilés par CMake. Le programme accepte
`--game-dir`, `--artwork-dir` et `--font` pour les remplacer. La police par défaut
est `native-game/assets/fonts/NotoSans.ttf`, distribuée sous OFL. Les tests CTest
utilisent les chemins du checkout définis dans `CMakeLists.txt` ; les options du
programme ne changent pas ces chemins.

Le [guide du paquet macOS](packaging/README.md) décrit la construction du `.app`
privé à partir du binaire compilé. Le raccourci local `native-game/launch.command`
lance `output/standalone-native-graphics-20261021/Transartica.app`. Ce paquet
contient ses ressources et ses dépendances ; il n'est pas publié avec le source.
Sur un nouveau clone, utiliser le binaire construit ci-dessus avec les ressources
privées, ou fabriquer un paquet selon ce guide avant d'adapter le raccourci.
Les lancements Windows et Linux restent à vérifier.
CARTE.FIC et chaque peinture sont authentifiés par SHA256 au démarrage.

## Commandes

- Entrée ou plaque centrale : nouvelle partie.
- Clic sur un chauffeur, L / A : alimentation OFF / NORMAL / FAST.
- Gauche / droite : régulateur par15 ; Shift : par1. Glisser le mécanicien
  utilise la plage de commande dessinée.
- B : frein progressif ; Espace : pause/reprise.
- M : carte détaillée ; Échap : cabine ; clic sur un aiguillage : changer sa branche.
- F5 : sauvegarde rapide dans `SESSION.native`, sans dialogue.
- F9 : ouvrir le livre de chargement ; S dans le boudoir : livre de sauvegarde nommée.
- F12 : capturer le rendu.
- Ctrl+Q ou Cmd+Q : quitter ; Échap quitte l'accueil, ferme la carte ou met
  la cabine en pause selon l'écran.

Le train part à l'arrêt. Avec lignite FAST, la chaudière doit chauffer avant
la première accélération. Aucun départ préfabriqué n'est injecté par l'interface.
Une perte de focus met en pause ; Espace reprend. Les scènes modales possèdent
leurs propres commandes. La carte comporte zoom et déplacement manuel, avec
retour au cadrage du train. Le défilement à la souris reste non validé dans les
essais conservés, l'outil de pilotage n'ayant pas trouvé de fenêtre exploitable.

En développement, les sauvegardes vont dans `output/standalone-native/saves`.
Le paquet utilise le dossier de préférences utilisateur fourni par SDL.
L'option `--save-dir` permet de choisir un autre dossier.
Noms normalisés sur huit caractères ; extension native. F6 ouvre les options,
R redémarre une nouvelle partie hors des champs de saisie.
L'enveloppe courante porte l'en-tête `TRANSARTICA_NATIVE_GAME 1`. Elle contient
le noyau, l'économie, le monde et la campagne, avec rencontres, présentation,
audio et lance-missiles ; une rencontre tactique ajoute son état complet.
Le chargement valide les sections avant de modifier la partie en cours.
La présentation inclut la caméra et le retour des écrans. Les anciennes archives
limitées au noyau et les sauvegardes Godot sont refusées. `core/README.md` décrit
le format interne du noyau, qui ne suffit pas à charger une partie complète.

## Portée et validation

État publié et limites : [rapport du 21 octobre 2026](../tasks/evidence/cpp-publication-20261021.md).
Les plans détaillés et les preuves privées restent conservés dans le projet.

| Modules écrits | Portée actuelle |
| --- | --- |
| `core`, `view` | Voyage avant et arrière, contacts partagés, rails et aiguillages, mobiles et tunnels, interpolation, caméra persistée et contrôles de carte. |
| `economy`, écrans de ville et chantier | Commerce, recrutement et atelier ; stations, mines et travaux raccordés à la session. |
| `world`, `combat` | Trains ennemis, troupeaux et nomades, combat automatique et tactique avec présentation et rapport. |
| `campaign` | Campagne, protection manuelle, équipage et espions, faune et embuscades, voiture d'inspection, morts et finale. |
| `launcher`, `audio`, autres écrans | Lance-missiles et continuation sauvegardée ; canaux audio et scores, introduction, aide et préférences clavier. |
| `app` | Composition des modèles et écrans, archive complète et commandes de sauvegarde. |

Les 20 suites CTest passent après la dernière correction graphique. Neuf
scénarios ont été exercés dans l'interface réelle. La revue couvre les 33 raccords
de carte ; les corrections comprennent les UV de V4/H2, le masquage du train
souterrain et la continuité de Turin. Le test analytique du raccord passe avec
les moteurs SDL logiciel et accéléré. Le paquet final a quitté normalement.
Le rapport publié distingue ces vérifications des parcours encore ouverts.

Le générateur `tests/gameplay_scenarios.cpp` prépare des archives pour vérifier
les scènes dans l'application. Ces états préparés ne prouvent pas une campagne
complète jouée jusqu'à la victoire. La campagne complète par joueur et les
lancements Windows/Linux restent non validés.

Code MIT ; police Noto Sans sous OFL (licence jointe). Assets historiques et
jeux de données dérivés restent privés. Références de bibliothèques :
https://wiki.libsdl.org/SDL2/README-cmake ;
https://freetype.org/freetype2/docs/tutorial/step1.html ;
https://docs.openssl.org/master/man3/EVP_DigestInit/ .
