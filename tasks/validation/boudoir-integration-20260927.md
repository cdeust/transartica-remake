# Boudoir, quartiers et bandeau — 27 septembre 2026

Les scènes utilisent les commandes et dispositions relevées dans
[evidence/boudoir-layout.md](../evidence/boudoir-layout.md) et
[evidence/panel-layout.md](../evidence/panel-layout.md). Les illustrations des quartiers et du bandeau sont nouvelles. Le plan général
historique est désormais chargé séparément depuis reference-private/general-plan.json ;
ce fichier et ses captures ne sont ni suivis par Git ni inclus dans les exports.

## Vérification

- 30 tests Python passent sans omission (Pillow et NumPy présents).
- 17 suites du lanceur Godot passent, ainsi que les suites combat, ennemis et mines.
- Le parcours natif Godot 4.5, OpenGL sur Apple M4, passe : clics sur les objets,
  clavier réel de la scène, saisie TRIP1234, sauvegarde/rechargement, redimensionnement,
  pause d’inventaire, changement de carte, événements de trajet et fin de partie.
- La revue indépendante a fait corriger les événements masqués par les quartiers,
  le rafraîchissement de carte globale, le retour vers la dernière pièce et
  l’alignement du nom de sauvegarde. L’édition native exige aussi LineEdit.edit()
  après grab_focus() ; le test sans fenêtre ne révélait pas ce défaut.

Captures natives : [quartiers](boudoir-quarters.png), [boudoir](boudoir-room.png),
[carte](boudoir-map.png), [inventaire](boudoir-inventory.png),
[sauvegarde](boudoir-book.png), [revolver](boudoir-revolver.png),
[épitaphe](boudoir-epitaph.png), [options](boudoir-options.png).

Les chiffres sont dessinés à la résolution de la fenêtre. Les réserves de
lignite et d’anthracite affichent l’état du moteur. Les nouvelles miniatures
conservent les coordonnées des commandes ECS. Le rendu visuel reste soumis
à l’acceptation du propriétaire ; aucune équivalence mesurée avec Noita n’est annoncée.

## Limites

La barre de composition reste vide. Les espions, la préparation complète des
wagons, le lance-missiles, l’inversion du train et les effets de récit restent
indisponibles. Les options difficulté/musique/combat ne sont pas raccordées.
L’inventaire ne restitue pas encore tous les détails des marchandises et citernes.
La carte générale affiche désormais le plan ECS privé, avec son réseau dessiné
et ses omissions exactes ; son remplacement artistique reste à produire pour
la distribution. La carte détaillée conserve le réseau original sur des axes
carrés. Le rapport wagon/case fixe de 0,75 permet six véhicules au départ, et le
cadrage initial contient le convoi sans zoom variable pendant le trajet. Les messages du bénitier sont conservés,
mais leurs effets attendent le portage. Aucun exécutable Windows n’a été validé ici.

Le livre accepte huit caractères, commence par une lettre et ajoute .SAV.
Un nom existant remplace la sauvegarde après validation, comme dans la routine
originale. Le revolver termine la partie courante après confirmation sans effacer
les sauvegardes ni fermer l’application.

## Dernière correction : cartes et convoi complet

Les axes ont été vérifiés contre CARTE et le rendu ALIS. L’essai avant correction
échouait sur les déplacements x/y ; il passe avec les axes carrés. Les six
véhicules occupent désormais le trajet connu au départ et sont entièrement
contenus dans la fenêtre native. Tests supplémentaires : huit caps, virage,
trois formats de fenêtre, constance du zoom, emprise complète des chiffres,
empreinte exacte du plan privé, sélection par la loupe et retour au train.
La revue a aussi identifié un recentrage automatique qui annulait l’inspection
lointaine ; un état d’inspection explicite le corrige sans révéler de nouvelles cases.

La dernière révision du bandeau emploie des surfaces métalliques plus sombres et
des contours plus nets. Sa qualité artistique n’est pas déclarée acceptée.
La PR reste un travail en cours sur la finition visuelle et les fonctions listées.
