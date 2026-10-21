# Paquet macOS natif privé

`--artwork-dir CHEMIN` sélectionne un candidat world-hd privé situé dans le projet.
Le dossier doit contenir son `manifest.json` et les huit `region-00.png` à
`region-07.png`. Seules leurs empreintes PNG/RGBA peuvent différer du manifest
source ; la registration et les dépendances restent identiques. Les SHA PNG sont
vérifiés et les liens sortant du dossier candidat sont refusés. Le paquet conserve
les chemins `Resources/game/assets/travel/artwork/world-hd/`, sans modifier les
assets partagés. L'option fonctionne aussi avec `--plan`.

Le script prépare un `.app` local à partir du binaire C++ déjà compilé et validé.
Il ne construit, télécharge ni lance aucun programme de jeu. Le paquet contient
des données historiques privées et ne doit pas être publié. Le code MIT, les
bibliothèques, la police OFL et les données historiques sont identifiés séparément.

La sélection `runtime-assets.json` suit les chemins des modules `app`, `screens`,
`view`, `audio`, `economy` et `campaign`. Elle inclut toutes les branches jouables,
puis suit les références des atlas, de la carte et des manifests audio. Les PNG
de travail, imports du moteur, copies alternatives, sources GDScript et caches ne
sont pas copiés. Un fichier référencé plusieurs fois est copié une seule fois.
Chaque fichier privé présent dans `original-data-manifest.json` est comparé au
SHA et à la taille de cette édition, comme `public_data_pack.gd::validate` ; les
nouveaux fichiers absents de cet ancien manifest portent explicitement
`edition_verified: false` dans l’inventaire. Les peintures sont toujours vérifiées
contre leur manifest courant, comme `View::load_artwork`.

Le graphe des bibliothèques est extrait des vrais `LC_LOAD_*_DYLIB`, y compris les
liaisons faibles et réexportées. Les bibliothèques Apple `/usr/lib/` et
`/System/Library/` restent fournies par macOS. Toutes les autres sont résolues,
copiées une fois, et leurs références deviennent relatives au chargeur. Aucun
`LC_RPATH` n'est conservé. Des bytes identiques ne sont mutualisés que si leurs
résolutions de dépendances concordent. Les architectures du binaire doivent être
présentes dans chaque dépendance. Aucune preuve universelle, Windows ou Linux
n'est inférée d'un exécutable arm64 local.

Disposition convenue avec l'adaptateur `main.cpp` :

```text
Transartica.app/Contents/
  MacOS/Transartica
  Frameworks/<bibliothèques réellement requises>
  Resources/game/assets/<sélection + références de manifests>
  Resources/game/private-data/<sélection historique>
  Resources/fonts/NotoSans.ttf
  Resources/licenses/<textes complets>
  Resources/resource-inventory.json
  Resources/PRIVATE-DATA-NOTICE.txt
  Info.plist
Transartica.app.receipt.json
```

Le reçu externe est écrit après signature : l'ajouter dans les ressources après
signature invaliderait le sceau. Il comprend tous les SHA256 et tailles du paquet
signé, le graphe final Mach-O et les identités des entrées. Il porte
`runtime_tested: false`. La signature ad-hoc vérifiée ne constitue ni une
notarisation ni une autorisation de redistribution. Les chemins source du reçu
servent à l'audit ; le vérificateur du paquet n'y accède jamais.

Les textes de licence installés avec les bibliothèques Homebrew sont copiés.
Tout texte complet manquant doit être fourni par `--license-map`. Sur ce Mac,
FreeType `2.14.1_1` ne contient que `LICENSE.TXT`, renvoyant à `FTL.TXT` absent.
L'orchestrateur peut récupérer uniquement ce texte depuis le tag officiel exact :
[FreeType 2.14.1 FTL.TXT](https://raw.githubusercontent.com/freetype/freetype/VER-2-14-1/docs/FTL.TXT).
Le packager ne télécharge rien et refuse la fabrication sans ce texte.
Le téléchargement autorisé par root a donné le SHA256
`5a5ee54c5001bbad1cdc1a57cc3dd4c42199b2da09d39c7ee41fab002d02967f`.

Exemple de fichier local de licences, à conserver dans le scratch enregistré :

```json
{"freetype":["/chemin/dans/le/projet/FTL.TXT"]}
```

Après réussite du binaire, l'orchestrateur sérialise les commandes suivantes.
`SORTIE` doit être un nouveau chemin `.app` situé dans le projet, y compris le
scratch enregistré du checkout principal si `--repo` désigne un worktree :

```sh
python3 -B native-game/packaging/test_macos_bundle.py
python3 -B native-game/packaging/macos_bundle.py --binary CHEMIN_BUILD/Transartica --output SORTIE --license-map LICENCES.json --plan
python3 -B native-game/packaging/macos_bundle.py --binary CHEMIN_BUILD/Transartica --output SORTIE --license-map LICENCES.json
python3 -B native-game/packaging/verify_macos_bundle.py SORTIE
```

Le script ne remplace jamais un paquet ou reçu existant. En cas d'échec de
mutation/signature, son répertoire `.incoming-<uuid>` est conservé et son chemin
est imprimé. Le reçu candidat complet est écrit, fermé et synchronisé avant de
publier le paquet. Si l'installation du reçu final échoue, le paquet revient au
staging et le candidat reste disponible ; un reçu concurrent n'est jamais écrasé.
Deux chemins distincts ne peuvent pas être publiés par un seul renommage : en cas
d'interruption brutale, ou d'échec du rollback, les chemins réellement conservés
permettent la récupération explicite. Le diagnostic n'annonce pas un staging
inexistant. L'orchestrateur inspecte puis nettoie uniquement les chemins créés par
son invocation. Ni le binaire d'entrée ni les bibliothèques installées ne sont
modifiés. Une licence fournie extérieurement est lue, pas déplacée.

Pour prouver l'autonomie réelle, déplacer ensuite ce paquet avec son reçu vers
un autre dossier enregistré, vérifier à nouveau puis le lancer depuis un cwd
différent, avec `--save-dir` dans le projet pour les essais. Contrôler les images
chargées par dyld et exercer accueil, carte, ville, campagne, combat et audio.
Le `--plan` et les tests de parseur ne prouvent pas ce lancement. Le protocole
JSON du moteur historique n'est pas importé par le runtime natif.

Sources de plateforme consultées localement :

- `SDL_filesystem.h` SDL2 : dans un `.app`, `SDL_GetBasePath` renvoie par défaut
  `Contents/Resources/`, sélection explicite `SDL_FILESYSTEM_BASE_DIR_TYPE=resource` ;
  `SDL_GetPrefPath` désigne le dossier utilisateur inscriptible.
- `man dyld`, `man otool` : chemins `@loader_path`, `@executable_path`, `@rpath`
  et enregistrements des commandes de chargement.
- `man install_name_tool` : mutation de copie uniquement ; prévoir
  `-headerpad_max_install_names` au lien si les noms deviennent plus longs.
- `man codesign` : signature ad-hoc `--sign -`, vérification stricte du paquet.

État au 21 octobre 2026 : le paquet macOS privé final a été construit puis
exécuté après les corrections graphiques. Son inventaire de fichiers, ses
liaisons Mach-O et sa signature locale ont été revérifiés après déplacement.
Les 20 suites CTest passent ; neuf scénarios ont été exercés dans l'interface
réelle et les 33 raccords de carte ont été revus. Le reçu de fabrication garde
`runtime_tested: false` : les preuves d'exécution sont consignées séparément dans
le [rapport publié](../../tasks/evidence/cpp-publication-20261021.md).
La campagne complète par joueur et les lancements Windows/Linux restent non validés.

Pour reproduire la fabrication depuis un clone, fournir le jeu de ressources
privé décrit dans le [README du runtime](../README.md) et toutes les dépendances
de `runtime-assets.json`. Aucun paquet contenant ces données historiques n'est
inclus dans le dépôt publié. Le raccourci local vise
`output/standalone-native-graphics-20261021/Transartica.app` ; un paquet fabriqué
ailleurs se lance directement ou nécessite l'adaptation de ce raccourci.
