# Cadence logique de la chaudière originale

Les offsets de script ci-dessous sont des offsets des fichiers décompressés privés `reference-private/unpacked/{yoda,time,table}.alis`. Le désassemblage emploie les opérateurs ALIS de la révision `19a95afdc07b45d997467806d4dd1bf83c5f8076`. Cette note distingue un **rendez-vous logique du jeu** d'une durée en secondes réelles.

## Chaîne de déclenchement

| Étape | Preuve | Effet |
| --- | --- | --- |
| Callback de YODA | En-tête YODA: pointeur à `+6` vaut `0x3353`; `src/alis.c:1178–1191` l'ajoute à `+6` et exécute ce code après un tour de séquence; entrée effective `YODA 0x3359` | Un passage par le callback pour chaque tour planifié de YODA. `YODA 0x3f8` installe `cstart24`, donc sa séquence devient active. |
| Diviseur | `YODA 0x3359–0x337b` | Incrémente l'octet local `+0x12`, et déclenche quand il dépasse 15 **ou** quand `main+0x2fce` est non nul, à condition que l'octet local `+0x24` soit nul. Il remet alors le compteur local à 0. En fonctionnement initial ordinaire, cela fait un déclenchement pour 16 callbacks. |
| Garde du temps | `YODA 0x3380–0x338d` | Si `main+0x651b == 0`, copie le facteur `main+0x2fb8` vers `main+0x2fcc`. Sinon, pas de recharge de TIME à ce passage. |
| Minute du jeu | `YODA 0x3394–0x33ae` | Ajoute ce même facteur à l'octet des minutes `main+0x2fb0`; au-delà de 59, incrémente une autre composante du calendrier et applique le modulo 60. YODA initialise le facteur à 1 (`0x3d8`), mais des branches de YODA/TEXTEK lui affectent aussi 3. |
| Consommateur TIME | `TIME 0x4f–0x5d`, `0xca–0xe7`; `TABLE 0x1b9` | TABLE initialise `main+0x2fcc` à 1. Quand il est non nul, TIME le décrémente puis exécute une phase parmi 0 à 8, et recommence tant qu'il reste du travail. Quand il est nul, `cstop` suspend TIME jusqu'au prochain tour planifié. |
| Chauffe | Switch TIME `0x5d`, branches `0x7a`, `0x96`, `0xb2` vers `0xea` | La chauffe, la soustraction de combustible et le calcul de vitesse sont la phase 0, 3 ou 6 : **une fois tous les trois points de phase TIME**. |

Au facteur initial `1`, un déclenchement de YODA avance le calendrier d'une minute et commande une phase TIME. La chaudière évolue donc **toutes les trois minutes logiques du jeu** en régime ordinaire, avec une première phase initiale issue de `TABLE 0x1b9` et de la phase locale 0 de TIME. Au facteur `3`, un déclenchement commande trois phases et avance le calendrier de trois minutes; la chaudière évolue une fois par déclenchement. Les gardes ci-dessus peuvent suspendre ou accélérer ces rapports.

## Conversion en temps réel

`src/sys/sys_sdl2.c:58,277–280` vise 50 rafraîchissements d'affichage par seconde. Le planificateur ALIS version 2 (`src/alis.c:1140–1206`) parcourt les scripts actifs et appelle `sys_delay_loop()` après un tour de script; l'implémentation SDL2 (`src/sys/sys_sdl2.c:272–275`) attend au minimum 4 ms par appel si le tour a été plus court. Ni la cadence d'affichage, ni cette attente **par tour de script** ne fixent à elles seules le nombre de callbacks YODA par seconde : celui-ci dépend du nombre de scripts actifs et du travail effectué dans leurs tours. Un réglage autonome exprimé en secondes réelles réclame une mesure sur l'exécutable d'origine avec la composition de scripts correspondante. La relation prouvée ici suffit à cadencer les calculs par minutes de jeu dans un ordonnanceur logique, mais ne justifie pas un délai mural constant.
