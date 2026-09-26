# Surcharge et instruments : limites de la preuve originale

Les offsets ci-dessous désignent les scripts ALIS décompressés privés. Le
décodage suit `reference-private/alis-source/src/opcodes.c` à la révision
`19a95afdc07b45d997467806d4dd1bf83c5f8076`.

| État dans MAIN | Règle vérifiée dans `TIME` | Ce qu'une jauge peut dire |
| --- | --- | --- |
| `+0x2fc6` | `0xea` ajoute `10 × taux_lignite + 30 × taux_anthracite`; `0xff` compare strictement à `5000` | Chaleur accumulée en unités du script. C'est la variable du seuil de surcharge. |
| `+0x2fc2` | `0x18a–0x1ce` copie `min(chaleur après refroidissement, 600)` | État borné de chaudière ; son plafond de 600 n'est pas un seuil d'explosion. |
| `+0x2fc0` | `0x1ed–0x20b` borne la réserve motrice à `32000` | Réserve calculée pour la traction ; ce n'est pas la variable testée à `0xff`. |

Si la chaleur excède `5000`, `TIME 0x10d` crée le script `SON` avec
l'identifiant `32`, `0x112` fixe sa propriété `5`, puis `0x11a` envoie au
parent le message `(26, 102)` et `0x123` suspend le script. Après reprise,
`TIME 0x124` continue le débit du combustible. Ce bloc seul ne prouve ni une
valeur de pression physique ni une transition terminale immédiate. Les textes
originaux corroborent la scène : `textek.alis` porte le titre anglais
« BOILER EXPLOSION » ; `texte2k.alis` décrit l'explosion et blâme la pression
dans la chaudière. Le titre et le dialogue n'ajoutent aucun second seuil de
pression au calcul de `TIME`.

Le [manuel Amiga original reproduit par Lemon Amiga](https://www.lemonamiga.com/doc/transarctica/1676)
(`THE ENGINE` puis `ENGINE CONTROLS`) décrit un écran d'instruments séparé,
accessible depuis la chaufferie. Son schéma place le régulateur réglable en
haut (`E`), la jauge de pression de chaudière en bas à gauche (`A`), la vitesse
au centre (`B`), la pression des pistons en bas au centre (`C`), le thermomètre
à droite (`D`), et la sortie en bas à droite (`F`). Le manuel donne la vitesse
en km/h, la température de l'eau en °C, un plafond de vitesse de 300 km/h et
une pression de pistons plafonnée autour de 300. Il avertit que dépasser le
repère de la jauge de chaudière peut produire une explosion. Les unités de
pression ne sont pas précisées ; les correspondances exactes entre les deux
pressions du manuel et les champs `+0x2fc6`, `+0x2fc2`, `+0x2fc0` nécessitent
encore le tracé de leur rendu dans `TRAIN`.

Le tracé de `TRAIN` affine la correspondance :

| Zone rendue par le script | Valeur et conversion exactes | Interprétation |
| --- | --- | --- |
| Sprites `0x537–0x579`, puis `0x6ee–0x743` | `main+0x2fc2 / 15 + 1`, position native `(0,20)` | Température `D` probable : cette valeur bornée à 600 suit la chauffe/refroidissement de TIME. Le graphisme original n'a pas été isolé. |
| Sprites `0x58d–0x5b3`, puis `0x757–0x790` | `53 + main+0x2fc6 / 510 + 1`, position `(0,5)` | Pression chaudière `A` probable : c'est `+0x2fc6` qui déclenche l'explosion au-delà de 5000. Le graphisme original n'a pas été isolé. |
| Chiffres `0x8cf–0xab6` | `local14 = trunc(main+0x2fc0 / 200)` ; trois chiffres à x `169`, `161`, `153`, y `5` | Pression pistons `C` probable, car le manuel décrit celle-ci comme numérique. La source prouve le nombre affiché, pas son étiquette. |
| Chiffres `0x5be–0x5c9` avec sous-programme `0xab7` | `local14 = main+0x2fb4` ; chiffres à x `169`, `161`, `153`, y `5` | Vitesse `B` probable, aussi affichée sur le bandeau commun selon le manuel. |
| Curseur `0x5cd–0x5e2`, modifié à `0x628–0x665` | position `120 + trunc(main+0x2fc4 × 4 / 15)`, bornée `[120,200]` | Régulateur réglable `E`. |

La fonction ALIS `cputnat` (`src/opcodes.c:1323–1339`) confirme que les deux
premiers opérandes sont les positions x et y ; les suivants choisissent
profondeur, image et élément. Les groupes de chiffres de vitesse et de réserve
partagent les mêmes x/y, mais leurs identifiants d'élément et leur phase de
rendu diffèrent. Le plafond interne `32000` de `main+0x2fc0` donne `160`
après division par `200`, alors que le manuel dit « autour de 300 » pour C :
ce désaccord doit rester visible tant qu'une capture ou un tracé de la
présentation ne le résout pas. Il exclut une conversion supposée de 32000 en
300 et interdit surtout d'étiqueter la réserve comme la pression de chaudière
`A` sans preuve.

Les deux captures originales locales, `reference-private/art-direction/original-engine-room.png`
et `original-command-room.png`, montrent la chaufferie et la salle de
commandement avec le bandeau commun inférieur. Elles ne montrent pas l'écran
d'instruments ; son agencement textuel provient du manuel.
