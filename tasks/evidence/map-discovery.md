# Position initiale et visibilité de la carte originale

Offsets de script : fichiers ALIS décompressés dans `reference-private/unpacked/`; décodage avec la source ALIS révision `19a95afdc07b45d997467806d4dd1bf83c5f8076` et les listings JSON privés. Les positions `(x,y)` emploient l'origine et l'ordre de `CARTE.FIC`, `data[x×73+y]`.

## Départ de la partie normale

Dans le bloc d'initialisation de TABLE qui attribue aussi les six wagons et les stocks de charbon (`0x699–0x744`), `0x714` écrit `12` dans `main+0x2fbe` (x), `0x71a` écrit `62` dans `main+0x2fb1` (y), et `0x744` applique `masque[12,62] |= 1`. La grille CARTE.FIC originale donne le code de rail `2` à cette case; le snapshot RAM observé plus tard et `TIME 0x496` concordent avec `(12,62)`. TABLE contient d'autres blocs de scénario fixant `(22,40)` (`0x123c–0x125a`) et `(157,68)` (`0x159a–0x15b9`) : ce ne sont pas les stores du bloc initial normal.

## Le tableau auxiliaire n'est pas une mémoire des cases parcourues

MAIN `0x34` déclare `main+0x3080` par `cdim` avec pas `0x48 = 72`. TABLE `0x54–0x85` remplit ce tableau de zéro pour x `0..159`, y `0..71`, avant d'y poser des bits particuliers. Son bit 1 marque d'abord la case de départ. Au déplacement, TIME `0x5c5` choisit le bit 1; après le commit des nouvelles coordonnées (`0x5f3/0x5f9`), `0x605` l'efface de l'ancienne case et `0x623` l'ajoute à la nouvelle. **Le bit 1 est donc un marqueur de position courante, pas un historique persistant de l'exploration.** D'autres bits existent pour d'autres états : TABLE pose par exemple `16` à `(12,40)` (`0x44b`) et `128` sur plusieurs cases spéciales (`0x463–0x4b7`). Une case dont le masque est non nul n'est donc pas nécessairement une case « déjà vue ».

## Fenêtre de dessin et rayon non établi

CARTE configure une vue de tuiles de largeur `320` et hauteur `150` pixels par `csetmap` (`0x13d`), avec des tuiles de `16` pixels (`cdefmap 0x128`). `cputmap 0x86a` prend les coordonnées de la fenêtre et la grille brute `main+0x76`; `src/image.c:4074–4144` parcourt les codes de cette fenêtre et saute seulement le code zéro. Ce chemin ne consulte pas `main+0x3080` pour cacher les voies non parcourues. Une autre boucle de CARTE (`0x305–0x3e2`) inspecte le tableau auxiliaire dans un carré borné autour de la position; son demi-côté local vaut `1`, `2` ou `4` selon `main+0x307b`, puis les coordonnées sont bornées à x `0..159`, y `0..71`. Cette boucle dessine des éléments auxiliaires selon les bits du masque; ces demi-côtés **ne sont pas un rayon de révélation des rails**.

La preuve exécutable donne donc un départ `(12,62)` et une **fenêtre cartographique locale**, mais aucun masque persistant de parcours ni rayon original de découverte. Ne pas déduire un rayon de brouillard de `1/2/4`, qui contrôle ici la recherche d'éléments auxiliaires.

Le [manuel Amiga original reproduit par Lemon Amiga](https://www.lemonamiga.com/doc/transarctica/1676)
(`MAPS`) distingue deux vues : une carte générale, présentée comme un plan
officiel de l'Union viking dont le réseau peut être incomplet, et une carte
détaillée centrée sur le train, défilable aux bords de l'écran. Le manuel dit
que les éléments mobiles sont visibles lorsque le wagon d'observation les
repère, puis disparaissent de la carte lorsqu'ils quittent son champ de
vision ; le train initial n'a pas de tel wagon. Cette règle de perception
concerne les **éléments mobiles**, pas la révélation persistante des voies.
Une carte qui conserve visitées les cases déjà parcourues serait donc une
règle de conception supplémentaire, à distinguer de la carte générale et de
la fenêtre détaillée attestées.
