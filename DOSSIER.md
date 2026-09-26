# Transarctica : recherche du 24 septembre 2026

Inventaire initial et proposition de refonte. Recherche des mécaniques déléguée à Luna. Aucun exécutable testé ; règles numériques et campagne complète restent à relever.

## Identité

Transarctica est un jeu Silmarils de 1993. Arctic Baron est son titre nord-américain PC. Les éditions recensées comprennent Amiga, Amiga AGA, DOS, Atari ST, Falcon et Macintosh. [Fiche Amiga](https://www.lemonamiga.com/game/transarctica), [table ALIS](https://github.com/maestun/alis).

Conception : André Rocques. Programmation : André Rocques, Louis-Marie Rocques, Michel Pernot. Graphismes : Eric Galand, Jean-Christophe Charter, Pascal Einsweiler. Musique : Fabrice Hautecloque. Couverture : Rodney Matthews, œuvre Heavy Metal Hero (1985). Langues Amiga recensées : français, anglais, allemand. [Crédits](https://www.lemonamiga.com/game/transarctica).

## Mécaniques documentées

Le [manuel transcrit](https://www.lemonamiga.com/doc/transarctica/1676) décrit :

- Lignite : monnaie appelée Bak et combustible ; anthracite : combustible uniquement.
- Consommation liée à la vitesse et au poids ; surcharge de chaudière dangereuse.
- Mines épuisables, exploitées avec esclaves, mammouths et grues.
- Commerce à prix variables, wagons de stockage spécialisés.
- Convoi jusqu'à cent wagons ; vitesse, freins, sens et aiguillages à gérer.
- Dangers : loups, tunnels, voies abîmées, mines, immobilisation sur la glace.
- Combats en temps réel ou résolution automatique : canons, mitrailleuses, soldats, abordages.
- Défaite possible par perte de la locomotive, du boudoir ou du quartier général.
- Enquête autour du Projet Blind et de l'Opération Sun, récit commençant en 2714.

Les formules internes et les déclencheurs exacts de victoire ne sont pas établis par cette recherche.

## Corpus documentaire

| Ressource | Usage et niveau de vérification |
|---|---|
| [Manuel transcrit](https://www.lemonamiga.com/doc/transarctica/1676) | Source principale des règles ci-dessus ; comparaison au scan encore nécessaire |
| [Documentation Old-Games](https://www.old-games.ru/game/download/977.html) | Scans repérés, dont manuel multilingue ; pas de lecture comparative intégrale |
| [Amiga ECS](https://www.lemonamiga.com/game/transarctica) et [AGA](https://www.lemonamiga.com/game/transarctica-aga) | Captures, crédits, éditions, liens vers presse |
| [Amiga Revue 53](https://amigaland.com/dataz/press_magazine/AMIGA_Revue/PDF_TXT/AMIGA_REVUE_Numero_53_%2802-03-1993%29.pdf) | Archive contemporaine ; piste sur le rapprochement avec La Compagnie des glaces |
| [Amiga Power 32](https://amigaland.com/dataz/press_magazine/AMIGA_Power/PDF_originals/Amiga_Power_Issue_32_1993_Dec.pdf) | Critique de l'édition AGA repérée par le sous-agent |
| [Wiki communautaire](https://transarctica.fandom.com/wiki/Transarctica_Wiki) | Index de pistes, à recouper |
| [Séquence de fin](https://www.youtube.com/watch?v=FB7b7gdTHcA) | Longplay signalé par le sous-agent ; non visionné intégralement |
| [WHDLoad](https://www.whdload.de/games/Transarctica.html) | Installation ECS/AGA, correctifs, manuel et astuces ; les sources incluses sont celles du correctif, pas la preuve de disponibilité du code original |

## Projets existants et compatibilité

[Transarctica Remake](https://sourceforge.net/projects/transarctica-remake/) : projet Python, statut alpha, dernière mise à jour affichée au 19 juin 2022. Annonce graphismes HD, raccourcis et cartes personnalisables. Licence affichée : Creative Commons Attribution Non-Commercial 2.0. Fonctionnement et achèvement non testés. [Wiki technique](https://sourceforge.net/p/transarctica-remake/wiki/Home/).

[ALIS](https://github.com/maestun/alis) : réimplémentation de la machine virtuelle Silmarils, nécessitant les données originales. Transarctica y est classé Playable, défini comme partiellement testé sans bogue majeur trouvé, distinct du statut Complete. Dépôt sous licence MIT. Piste utile pour l'observation et les formats ; pas une autorisation d'utiliser les données originales.

Il existe donc des pistes d'exécution actuelles. [FS-UAE](https://fs-uae.net/docs/options/uae-cpu-speed/) propose une vitesse CPU real ou max ; [WHDLoad](https://www.whdload.de/games/Transarctica.html) documente l'installation Amiga. La cause du jeu trop rapide sur ta machine reste à diagnostiquer : émulateur, édition et configuration nécessaires.

## Proposition de refonte

Je propose **Godot 4 avec C#** pour ordinateur ; **GDScript typé** si le navigateur est prioritaire. La documentation actuelle exclut l'export web C# de Godot 4. [Source officielle](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_web.html).

Le langage seul ne garantit pas la bonne vitesse. Proposition : simulation à pas fixe, affichage séparé, horloge de jeu pour pause et accélération. Godot documente les mises à jour fixes et le temps écoulé entre images. [Documentation](https://docs.godotengine.org/en/stable/tutorials/scripting/idle_and_physics_processing.html).

Critère de validation proposé : mêmes commandes et même graine aléatoire doivent produire mêmes positions, consommations et résultats au même temps simulé, quelles que soient les fréquences d'affichage testées. Ajouter sauvegarde/reprise, pause et comportement sous forte charge. Aucun test de jeu exécuté à ce stade.

Direction artistique retenue par le propriétaire : **pixel art 2D moderne**. Un portage 3D sous Unity ou Unreal Engine reste envisageable ultérieurement. Séparer les règles et données de la présentation aidera cette évolution ; cela ne rendra pas le changement de moteur automatique.

Organisation : simulation indépendante des écrans, données éditables pour villes/wagons/événements, sauvegardes versionnées. Premier périmètre jouable proposé : trajet entre quelques villes, combustible, commerce, modification du train, rencontre hostile et sauvegarde. Il permettra d'évaluer les sensations avant de produire la campagne et tous les graphismes.

## Inconnues et décisions nécessaires

- Choix confirmés : remake fidèle, histoire et carte originales conservées, commandes adaptées au clavier et à la souris actuels ; pixel art 2D moderne ; multiplateforme avec priorité à un exécutable Windows pour une release sur le dépôt Git ; projet personnel gratuit, code original à placer sous MIT.
- Édition de référence confirmée : Amiga 500 ECS en anglais. Le propriétaire ne possède plus les disquettes. Révision exacte et source vérifiable des données restent à établir. Les langues recensées dans la fiche catalogue ne prouvent pas celles de son exemplaire.
- Inventaires complets des wagons, marchandises, villes, carte et états de quête.
- Mesures des consommations, dégâts, prix, cadences, IA et conditions finales.
- Titulaires actuels des droits non identifiés. Réécrire le code ne règle pas les droits sur nom, récit, images et musique. L'OMPI distingue idées et expression et décrit les licences d'adaptation. [Protection](https://www.wipo.int/en/web/copyright/protection), [jeux et droits](https://www.wipo.int/en/web/wipo-magazine/articles/video-games-and-ip-a-global-perspective-38773).

Aucune durée ni aucun budget global fiable annoncé avant l'inventaire de contenu. Ce dossier ne constitue pas encore la spécification du jeu. Voir [les critères de fidélité](FIDELITE.md).
