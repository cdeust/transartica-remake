# Retouches locales des raccords world-hd

Mandat du propriétaire, 18 octobre 2026 : « je veux une carte similaire niveau rendu, mais correctement liee ». Garder la DA des huit peintures sélectionnées. Root réalise les éditions avec image_gen. Ce document fixe leur registration ; aucun raster, script ou moteur n'a été modifié pour le préparer.

## Références et limites des sources

Les peintures à éditer sont `game/assets/travel/artwork/world-hd/region-00.png` à `region-07.png`. `owner-selection.json` identifie leurs originaux et empreintes. `tasks/evidence/owner-hd-integration-20261012.md:17–20` confirme que chaque canevas complet occupe son rectangle CARTE, sans recadrage. Le même document, lignes58–62, laisse les raccords ouverts et indique que les anciens masques visent d'autres PNG et une autre partition.

Les données géométriques sont dans `reference-private/artwork-world-20261011/production-plan.json`, champs `regions[].shared_edges`, `features`, `city_records`, `rail_ports`, et dans `world-inventory.json`, champs `cells` et `features`. Leurs contrôles dessinés sont `guides/region-00.png` à `region-07.png`, avec la légende et les coordonnées dans `guides/guides.json`. Ces guides indiquent les contraintes CARTE ; ils ne sont pas des paysages de remplacement.

L'empreinte CARTE déclarée par le manifeste actif est `8e1067619b254d57717348fefedc1b5013eb1d7ba23200a815e36f9b856d811a`. Le monde mesure160×73 cellules. Origine en haut à gauche ; x vers la droite, y vers le bas. Aucune rotation ni symétrie. Les guides ont32 pixels/cellule, sans bordure. Leurs points au bord droit ou inférieur gardent leur coordonnée mathématique commune avec le guide voisin. Voir `guides/README.md`.

## Les dix frontières internes

Les extrémités ci-dessous sont des coordonnées monde exactes tirées de `shared_edges`. Les cellules adjacentes servent à retrouver les classes et les ports dans l'inventaire ; les intervalles de cellules sont inclusifs.

| Raccord | Peintures | Segment monde | Cellules adjacentes à conserver |
| --- | --- | --- | --- |
| V1 | 00 / 01 | (40,0) → (40,37) | x39/40 ; y0..36 |
| V2 | 01 / 02 | (80,0) → (80,37) | x79/80 ; y0..36 |
| V3 | 02 / 03 | (120,0) → (120,37) | x119/120 ; y0..36 |
| V4 | 04 / 05 | (40,37) → (40,73) | x39/40 ; y37..72 |
| V5 | 05 / 06 | (80,37) → (80,73) | x79/80 ; y37..72 |
| V6 | 06 / 07 | (120,37) → (120,73) | x119/120 ; y37..72 |
| H1 | 00 / 04 | (0,37) → (40,37) | y36/37 ; x0..39 |
| H2 | 01 / 05 | (40,37) → (80,37) | y36/37 ; x40..79 |
| H3 | 02 / 06 | (80,37) → (120,37) | y36/37 ; x80..119 |
| H4 | 03 / 07 | (120,37) → (160,37) | y36/37 ; x120..159 |

Turin traverse H1 : footprint unique `(28,36,3,2)`, ancrage `(30,37)`, `source_index:35`, type comptoir. Ses six cellules71..76 sont réparties entre00 et04. Protéger les deux moitiés comme une même ville ; ne pas créer un second bâtiment pour fermer le raccord. L'inventaire `features`, lignes152773–152829, porte ce contrat. Aucun autre footprint de ville ou composé déclaré ne traverse une frontière interne dans cette partition ; les villes proches restent protégées même sans traverser le segment.

V4 est le défaut observé dans `disk-hygiene-54i1ct98/native-captures/native-2.png`. Dans les colonnes39/40 entre y37 et72, l'inventaire ne déclare aucun massif ou forêt. Les seules cellules de relief/eau de ces deux colonnes sont les rivages `(40,48): code -107`, `(39,49):106`, `(40,49):107`, `(40,50):110`, `(39,51):115`. Conserver les états signés. Le contour de l'eau doit suivre ces données. Un bosquet peint qui arrive au bord peut retrouver une lisière dans son voisinage autorisé ; sa coupe ne justifie pas une extension de forêt sur de la neige CARTE.

## Les trois intersections

Chaque intersection appartient à quatre peintures. Préparer une seule retouche commune aux quatre coins, puis répartir ses pixels selon les rectangles d'origine. Deux retouches indépendantes des lignes risquent de se contredire au même coin.

| Point | Peintures NW / NE / SW / SE | Contraintes immédiates CARTE |
| --- | --- | --- |
| (40,37) | 00 / 01 / 04 / 05 | (39,36)=neige0 ; (40,36)=montagne88 ; (39,37)=neige0 ; (40,37)=neige0. Le relief NE ne doit pas devenir un plateau rectangulaire couvrant les trois autres cellules. |
| (80,37) | 01 / 02 / 05 / 06 | (79,36)=rail10 ; (79,37)=rail13 ; (80,36) et(80,37)=neige0. Le port commun est(79.5,37), à gauche du coin, pas(80,37). Les autres ports sont(79,36) et(80,38). Préserver ces couloirs sans peindre de voie dans le fond. |
| (120,37) | 02 / 03 / 06 / 07 | Les quatre cellules119/120×36/37 sont de la neige0. Faire continuer la matière neigeuse et son éclairage ; aucun nouveau massif ou site à cet endroit. |

Ces lectures sont dans `world-inventory.json:77001`, `77459`, `77926`, `78905`, `79367`, `79825`. Les guides montrent aussi les alentours ; les quatre cellules ne bornent pas la silhouette complète d'un objet voisin.

## Stratégie d'édition par patches

Commencer par V4, avec les originaux04/05 et leurs guides comme références distinctes. Composer un contexte joint dans l'orientation monde. Demander à image_gen de terminer les silhouettes coupées et de poursuivre la texture neigeuse avec l'éclairage existant. Interdire les villes ajoutées et les voies peintes. Conserver les parties centrales des images et les villes ; retoucher seulement les zones de jonction explicitement masquées.

La largeur du masque dépend de la silhouette coupée et de son pied réel. Ne pas choisir une bande constante pour toutes les frontières. Inclure assez de contexte intact de chaque côté pour lire l'objet entier, puis protéger ce contexte lors du réassemblage. Une transition de couleur ne répare pas une falaise interrompue. Le résultat doit montrer une rive ou une lisière complète lorsque la formation s'arrête, et une même formation lorsque CARTE la fait traverser.

Les PNG00..03 mesurent1304×1206 pour40×37 cellules. Les PNG04..07 mesurent1322×1190 pour40×36 cellules. Une jonction horizontale ne s'aligne donc pas par juxtaposition de lignes natives de même longueur. La projection de chaque image reste `pixel_x=(world_x-region_x)*image_width/40`, `pixel_y=(world_y-region_y)*image_height/region_height`. Garder ces transformations, les dimensions et les crops du manifeste. Tout rééchantillonnage nécessaire au contexte de travail doit rester dans le patch réimporté ; ne pas redimensionner les centres des peintures.

Conserver hors masque les pixels d'origine lors du réassemblage final, même si image_gen a changé le contexte. Protéger les villes par leur silhouette complète et leur footprint CARTE. Pour Turin, vérifier d'abord si la silhouette fournie est elle-même coupée : corriger une ville coupée peut exiger une retouche de son contour. Ne pas promettre simultanément une réparation de ce contour et la conservation de tous ses pixels ; soumettre cette zone précise à root avant de l'élargir.

Traiter les intersections avec leur contexte quatre régions avant de finir les patches de segments qui les rejoignent. Conserver un seul auteur de pixels pour chaque coin partagé. Livrer des copies candidates privées à root ; les fichiers actifs sont des liens vers un autre worktree et ne doivent pas être écrasés.

## Sources antérieures écartées pour ce raccord

`terrain/world-artwork.png` est le maître1857×847 de l'ancien ensemble ; `world-region-*.png` y mesure1312×1199 et `world_artwork.gd::region_rect` partage la hauteur à36.5 cellules. La capture de ce maître montre aussi des corridors déjà peints. Ces pixels ne fournissent pas la suite manquante des peintures12Oct et leur adoption déplacerait le contenu central. Voir `tasks/evidence/world-artwork-20261006.md:12` et `tools/build_painted_map.py:437–446,609–610`.

Les originaux04/05 cités par `owner-selection.json` mesurent eux aussi1322×1190 ; leurs crops actifs utilisent tout le canevas. Aucun recouvrement hors crop n'a été trouvé pour cette paire. L'ancien `build_painted_map.py:183–196` invente un recouvrement par miroir avant une coupe et un fondu. Il ne reconstruit pas une forêt ou une falaise tronquée et ne fournit pas une solution de registration pour les nouveaux PNG.

`reference-private/artwork-ultrawide-20261012/world-panorama-5120x1440.webp` est classé `generic_landscape_study_not_complete_world_map` dans `assembly-receipt.json:76–77`. Son reçu déclare `geography_registered:false`. Il ne sert pas de maître de raccord CARTE. Le candidat par matériaux abandonné n'entre pas dans cette retouche.

## Remise à root

Pour chaque patch : indiquer le segment concerné, son rectangle monde, le masque effectivement modifié et les pixels source conservés. Fournir un aperçu de la jonction entière et des coins partagés. Root vérifie les ancrages des villes et les couloirs de rail avant activation ; il compare ensuite les dix raccords dans le rendu natif, dont H1 à Turin et les trois intersections. Ce brief ne rapporte aucun nouveau test ni validation artistique des patches.
