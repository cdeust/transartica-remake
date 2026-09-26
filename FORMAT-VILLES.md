# Villes ECS

`tools/decode_cities.py` lit les 46 enregistrements de trois octets de
`reference-private/VILLE.FIC`. Les noms et catégories viennent des branches de
TEXTEK, pas d'une correspondance approximative avec le guide.

L'abscisse d'ancrage vaut `signed8(field0) + 40`, l'ordonnée est `field1`.
La valeur absolue signée de `field2` sélectionne l'une des six catégories ; son
octet brut est conservé car la signification complète du changement de signe
reste à établir.

Preuves : TIME, offsets 0x2797–0x28d6, normalise les six tuiles d'une ville vers
son ancrage inférieur droit. Les codes 71–76 donnent respectivement les décalages
(2,1), (1,1), (0,1), (2,0), (1,0), (0,0). TEXTEK sélectionne les noms à 0x3bc0
et les catégories à 0x3b09. L'interprétation des instructions suit la révision
ALIS conservée dans `reference-private/alis-source/`.

Après normalisation, les 43 points du guide placés sur une tuile de ville
correspondent exactement à l'enregistrement portant le même nom, avec trois
variantes orthographiques explicitement listées dans le décodeur.

Tibesti est l'enregistrement 43 : son ancrage original est (49,70), code 76.
Le guide indique (43,70), code 0. Les deux observations restent conservées.
Alexandria et Tribe of Nomads sont les deux noms absents du guide ; le dernier
enregistrement ne prouve pas une implantation fixe de la tribu.

Les résultats privés sont `reference-private/villes-decoded.json` et `.csv`.
Les trois tests de villes vérifient les octets signés, les tables réellement
extraites et le recoupement indépendant. COMMERCE.FIC reste à décoder.
