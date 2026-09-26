# Personnel et récit initial — preuves et limites

## Personnel attesté par les scripts

Le désassemblage de `reference-private/textek-listing.json` montre l’écran d’effectifs : à l’offset script `0x1dc3`, `SLAVE(S) :` est concaténé avec la conversion de `odirw[196]`; à `0x1de4`, `SOLDIER(S) :` affiche `odirw[190]`; à `0x1e13`, `MAMMOTH(S) :` affiche `odirw[194]`. Cela prouve trois compteurs présentés par cet écran, mais pas leur valeur initiale : ces mots sont des variables locales du script, et leur initialisation n’a pas été suivie jusqu’à l’état du début de partie.

`reference-private/texte2k-listing.json` fournit les libellés d’actions économiques : « PURCHASE OF SLAVES » (`0x11e4`), « SALE OF SLAVES » (`0x1239`) et « ENROLMENT OF SOLDIERS » (`0x1289`). Des chaînes précisent aussi le prix par soldat et la capacité des wagons en soldats. Elles attestent achat/vente et enrôlement, pas un indicateur de moral.

## Journal et objectif

Le texte anglais de `texte2k` contient « ALEXANDRIA JOURNAL ON 21.04.2022 » (`0x71b`), puis dans une autre entrée « OPERATION ‘BLIND’ PROJECT. IT WILL BE » (`0x954`) et « COMMISSIONED ON 24 DECEMBER NEXT. » (`0x981`). C’est un contexte narratif daté autour du projet Blind. Les éléments consultés ne prouvent pas que ce journal constitue l’objectif initial jouable ni que cette date est le départ de campagne. Aucun objectif initial distinct n’a été établi ici.

## Limites

La recherche des chaînes anglaises `morale`, `moral`, `happy`, `rebel`, `crew`, `loyal`, `mutiny` et `unrest` n’a trouvé aucun libellé de jauge ou de règle de moralité. Les scripts attestent soldats, espions et esclaves comme catégories/actions, mais aucune jauge de bonheur, rébellion ou moral. Le snapshot RAM disponible est une observation en cours de partie, pas une preuve de l’état initial; ses compteurs ne sont donc pas présentés comme tels. Prochaine validation : capturer une sauvegarde juste après la création de campagne et tracer l’initialisation des variables affichées, puis suivre tout consommateur d’un éventuel compteur distinct.
