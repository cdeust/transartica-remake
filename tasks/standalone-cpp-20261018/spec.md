# Exécutable C++ autonome — décision propriétaire du18octobre2026

La demande explicite « Godot ne doit plus servir du tout » remplace la décision
précédente de conserver Godot4.5. La nouvelle cible ne charge, ne lie et ne lance
ni Godot, ni godot-cpp, ni GDExtension, ni GDScript. Le code et les reçus antérieurs
restent des références de comportement ; leur ancien build n'est plus poursuivi.

Le résultat attendu reste le jeu complet : carte et histoire Amiga500ECS,
commandes, économie, événements, combat, audio et sauvegardes, en C++ autonome.
FIDELITE.md reste applicable. Aucun dessin générique ni chemin ferroviaire inventé.
Les assets privés ne sont ni recopiés dans les sources publiques ni publiés.

Choix de réalisation de l'agent : C++20, CMake, SDL2 pour plateforme/rendu/audio,
libpng pour les images et types standard C++ pour la simulation. Bibliothèques
portables, sans garantie déduite de performance ou compatibilité effective.
SDL2 est disponible ici en2.32.10 ; les dépendances devront être empaquetées
pour chaque distribution. Cibles Windows, macOS et Linux, validées séparément.
Sources plateforme : https://wiki.libsdl.org/SDL2/Introduction et
https://wiki.libsdl.org/SDL2/README-cmake .

Architecture : native-game/core contient le domaine sans moteur ; platform
encapsule SDL et les formats ; app compose un seul état et le rendu visible.
Les références actuelles sont consultables comme texte/données, jamais exécutées
pour faire fonctionner le nouveau programme. Aucun adaptateur Variant imitant
Godot et aucun relais vers les scripts. Les contrôles n'utilisent pas d'état
préfabriqué pour simuler un voyage ; la machine et les rails pilotent le train.

Premier parcours d'intégration : accueil, cabine visible, vraie CARTE.FIC,
commandes de chauffe/régulateur/frein, progression sur rails, pause et reprise
d'une sauvegarde native. Une frontière non encore portée arrête le voyage et
reste annoncée comme incomplète ; elle ne doit pas être traversée par hypothèse.
Ce parcours ne vaut pas campagne complète. L'horloge de1s du remake reste
provisoire et ne prouve pas la cadence originale.

Validation : tests C++ autonomes fondés sur les données et règles décodées,
vrai exécutable inspecté avec absence de lien Godot, fenêtre principale visible,
entrées réelles et capture, état avant/après sauvegarde, ressources mesurées.
Conserver plafond1Gio et sérialiser builds/lancements. Aucun push ou suppression
du travail concurrent. Les consultations Cortex n'ont pas fourni de rappel
exploitable ; source, documents d'évidence et reçus locaux guident l'extraction.
