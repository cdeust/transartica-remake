# Publication du runtime C++, 21 octobre 2026

Le runtime autonome utilise SDL2, sans processus Godot. Les sources sont dans
`native-game/`; les anciennes intégrations GDExtension restent des références.
La publication préserve séparément les changements encore indexés dans le
worktree `noita-pixel-world`.

## Validation effectuée

La dernière compilation sérialisée et les vingt suites CTest ont réussi après
les correctifs finaux. Le journal privé `graphics-corrections-20261021/logs/ctest-final2.log`
rapporte vingt succès, zéro échec, sortie0. Le compositeur passe ses24cas et
la fixture analytique du raccord passe avec les moteurs logiciel et accéléré.
Ces essais ont utilisé les ressources privées, sous le garde de1Gio du projet.

Les neuf scénarios dans l'interface réelle sont détaillés dans
[le rapport UI](cpp-interface-map-review-20261020.md). Les sauvegardes de
reproduction V4/H2 ne provoquent plus le crash de coordonnées UV. Les contrôles
d'entrée et de sortie du tunnel montrent le masquage corrigé des véhicules.
La capture du dernier binaire livré montre la façade continue de Turin.
Cette exécution quitte normalement, avec un pic RSS de145744Kio.

[La revue carte](map-final-review-20261021.md) couvre33captures. La comparaison
avant/après trouve139109pixels modifiés, tous dans la bande calculée du raccord
ou dans le masque local de Turin. [La revue de code](graphics-code-review-20261021.md)
décrit les fichiers examinés et les limites de son indépendance.

Les journaux et captures complets restent dans
`reference-private/graphics-corrections-20261021/` sur la machine de travail.
La campagne complète par entrées joueur reste à valider. Aucun lancement
Windows ou Linux n'est revendiqué. Le défilement souris n'a pas été vérifié,
l'outil de contrôle ayant retourné `noWindowsAvailable`.

## Ressources et distribution

Le dépôt public contient le code MIT et la police Noto Sans avec sa licence OFL.
L'atlas auteur `bridges-only-v1.png` est une copie régulière de la ressource
utilisée par le jeu, SHA256
`19fc7e79c5da692cca2813fdcd1480051f7f059bf4d26545e08bc047e1c3c4a5`.
Sa provenance est consignée dans
[le relevé des passages](../standalone-cpp-20261018/world-passages-native.md).

Les données Amiga et les peintures mondiales sélectionnées restent privées.
Le clone doit recevoir `game/private-data/` et les huit `region-*.png`
correspondant au manifest. Certains tests demandent aussi les fixtures de
`reference-private/validation/`. Le manifest artistique final a pour SHA256
`af395bffada3efba7a4063ffdbab7757edfc7bb88c8ad67a2adf1d7dfdc70186`.

Le lanceur local vise le paquet privé
`output/standalone-native-graphics-20261021/Transartica.app`.
Ce paquet a été déplacé et revérifié, y compris ses141fichiers et sa signature
locale. Il contient les ressources privées et ne fait pas partie du push.
Le README natif donne les commandes de compilation depuis les sources.

## Base de publication

La branche part de main0ae9574. L'ancien historique local reste conservé
séparément : il contient des rasters globaux dérivés des données originales.
L'aperçu général `game/assets/travel/terrain/world-artwork.png` conserve la
version publique de main. Pour reproduire exactement le paquet local testé,
fournir aussi sa version privée dans le répertoire de ressources privé.
Le descripteur natif des obstacles est isolé dans
`game/assets/travel/terrain/scenes/obstacles-native.json` pour préserver le
lecteur Godot existant. Le contenu authentifié reste identique au fichier testé.

## Vérification de la branche publique

La compilation depuis main avec le descripteur isolé réussit, sortie0,
pic272160Kio. Les20CTest repassent sur cette compilation, sortie0,
pic69024Kio. Les18tests du packager final passent après extraction
du parseur Mach-O. Le paquet réellement reconstruit contient141fichiers ;
le vérificateur confirme leurs empreintes et la signature.

Le paquet utilise cette fois l'aperçu général public de main. Son lancement
réel utilise Metal et CoreAudio, reçoit les entrées clavier et quitte
normalement après sept cycles, avec un pic194608Kio. Cette vérification
complète les essais graphiques antérieurs ; elle ne rejoue pas les neuf
scénarios ni une campagne entière.

La revue indépendante compare le packager à sa sauvegarde antérieure :
publication transactionnelle identique et parseur Mach-O identique dans l'AST.
Le contrôle de structure passe sans avertissement. Le contrôle des sources
passe avec quatre avertissements numériques informatifs. La licence OFL
est conservée verbatim avec son espace final original ; son SHA annoncé
reste exact. Aucun fichier historique privé n'entre dans la sélection Git.
