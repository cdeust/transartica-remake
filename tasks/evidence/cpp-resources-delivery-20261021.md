# Livraison des ressources natives, 21 octobre 2026

Le propriétaire demande que le dépôt contienne les ressources du jeu et que
la construction les intègre automatiquement. Cette instruction remplace leur
exclusion dans la première publication da03cd9.

Les 120 ressources du paquet graphique validé sont identifiées dans
[l'inventaire](cpp-resources-inventory-20261021.md). Les fichiers copiés sont
identiques aux empreintes conservées dans le reçu du paquet. Les entrées de
jeu décodées sont dans `game/data/`. Les huit peintures corrigées et l'aperçu
général restent dans leurs chemins `game/assets/`. Les licences des dépendances
et les métadonnées d'édition sont conservées.

Les trois fixtures de marche arrière sont versionnées dans
`native-game/tests/fixtures/`. Elles servent aux tests ; elles ne sont pas
copiées dans le jeu livré. Les captures et sauvegardes de diagnostic restent
dans les archives de développement.

Validation effectuée sur un export du seul index Git, sans lien symbolique ni
répertoire de données locales. CMake Release et compilation série réussis,
pic mémoire du groupe de compilation : 266112 Kio. Le relevé SHA256 compare les
sources et ressources testées aux fichiers préparés pour le commit.

- CTest : 21 suites réussies, 0 échec, dont les 8 cas de staging des ressources.
- Packager macOS : 18 tests réussis.
- Installation CMake : réussie après renommage du checkout source, 127 fichiers
  de ressources et notices. Le binaire installé puis déplacé démarre sans option
  de chemin de ressources et quitte avec le code 0.
- Paquet macOS reconstruit depuis cet export puis déplacé : 142 fichiers vérifiés,
  signature ad-hoc valide. Interface réelle : menu, nouvelle partie, cabine,
  carte de voyage et carte générale observés ; boutons et clavier exercés.
  Une seule instance du paquet final était active. Sortie normale, code 0,
  pic mémoire 155776 Kio.
- Revue indépendante de l'index : les 120 ressources attendues concordent en
  taille et SHA256 ; aucun fichier manquant identifié.
- Contrôles source et craftsmanship : 0 erreur, 0 avertissement.

Les journaux complets et les deux captures F12 sont conservés localement dans
`reference-private/resource-delivery-20261021/`. Le paquet exécutable validé est
`output/native-resources-20261021/Transartica.app`. Le reçu de fabrication conserve
`runtime_tested: false` ; la preuve d'exécution est ce rapport et son journal.

Les ressources sont des fichiers livrés automatiquement avec le binaire. Aucune
récupération séparée n'est nécessaire après le clone. L'installation CMake utilise
les bibliothèques du système ; le paquet macOS inclut ses dépendances non système.
La campagne complète par joueur et les exécutions Windows/Linux restent non
validées par cette vérification.
