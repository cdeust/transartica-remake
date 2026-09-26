# Proposition visuelle : chaufferie

Demande : interface reconnaissable de Transarctica Amiga, ambition de pixel art
comparable à Noita. La génération intégrée image_gen a produit engine-room-v1.png
à partir de la capture de référence originale ; le prompt complet est conservé
dans engine-room-v1-prompt.txt. Aucun appel API payant externe configuré ni CLI
supplémentaire n'a été utilisé.

Référence de composition :
https://www.dazeland.com/en/Amiga/Transarctica.html
https://www.dazeland.com/images/Amiga/T/Transarctica-2.png
Copie de recherche : reference-private/art-direction/original-engine-room.png.
Le quartier général a aussi été examiné dans Transarctica-4.png.

La proposition reprend la chaufferie frontale, les deux chauffeurs, la galerie
supérieure, le foyer central et le bandeau mécanique inférieur. Elle remplace
l'interface générique à cartes et onglets comme direction artistique souhaitée.

Statut de engine-room-v1.png : image de conception conservée comme référence. Les
compteurs imprimés, cadrans et petites illustrations du bandeau sont décoratifs.
Le petit dessin de carte ne représente pas le réseau original. Ce n'est ni une
capture du jeu fonctionnel ni une preuve de fidélité mécanique. La densité de
texture est supérieure au prototype précédent ; une grille de pixels uniforme,
les silhouettes, les animations et la lisibilité en situation restent à produire
et vérifier. Ne pas annoncer un niveau Noita atteint sur cette seule image.

Intégration attendue : séparer fond, foyer, chauffeurs, vapeur, leviers et bandeau;
remplacer les compteurs peints par les valeurs de simulation ; conserver une
interaction identifiable avec les postes de conduite de l'original. Les futurs
assets dérivés de cette référence historique ne sont pas déclarés MIT par défaut.

## Intégration jouable

Trois couches distinctes ont été produites avec image_gen puis intégrées dans
`game/assets/engine-room/` : background.png, stokers.png et fire.png. Les prompts
exacts sont conservés dans background-prompt.txt, sprite-prompt.txt et
fire-prompt.txt. Les huit poses sont recadrées selon leurs marges mesurées ;
les quatre flammes sont animées. Compteurs, aiguilles et survols sont rendus
par Godot. La génération ne garantit pas une grille pixel uniforme ni un
niveau de finition comparable à Noita.

L'écran indépendant des instruments utilise aussi instruments.png ; son prompt
est instruments-prompt.txt. Il reprend la disposition A–F du manuel et les
matériaux de la chaufferie validée ; aiguilles, thermomètre, chiffres et régulateur
sont calculés en jeu. Ce décor est une création de présentation, pas une preuve
de correspondance pixel à pixel avec l'original.
