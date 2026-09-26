# Règles de travail

- Correction du propriétaire : ne pas faire de l'identification exhaustive des versions un préalable au travail sur Transarctica. Avancer avec Amiga 500 ECS anglais ; enquêter sur les variantes seulement si un écart concret menace la fidélité. La taille des disquettes ne sert pas de preuve d'identité entre éditions.

- Correction du propriétaire du 24 septembre 2026 : ne jamais assimiler « remake communautaire » ou « jouable » à une reproduction complète et fidèle. Exiger des preuves pour la carte, l'histoire et une campagne terminée avant toute affirmation de complétude. Référence : FIDELITE.md.
- Précision du propriétaire : son expérience de référence est l'édition Amiga 500 ECS anglaise. Ne pas substituer les langues d'une fiche catalogue à la langue de son édition ; ne pas déduire non plus l'absence générale d'une traduction de ce seul témoignage.

- Lors du décodage ALIS, suivre les appels auxiliaires avant de fixer la taille d’une instruction : `clive` appelle `clivin`, qui consomme un identifiant 16 bits puis un opérande de stockage. Lire uniquement le corps direct décalait les instructions suivantes.
- Les adresses du journal ALIS ne sont pas des offsets de fichier : `readexec` imprime une adresse dérivée entre crochets, puis le PC après lecture de l’opcode. Comparer le PC moins un à la base du script chargé pour obtenir un offset de bytecode.
- Vérifier les dimensions des objets de carte dans le code : les villes utilisent une empreinte de plusieurs tuiles et un ancrage, ce qui rend les essais de translation sur une seule tuile insuffisants.

- Keep all project work, caches and generated files in Developments/Transartica per owner direction.
- PRD runner run IDs are session scoped in this setup: root could resume its run while a subagent received unknown run_id. Do not delegate an active run across MCP sessions.

- ALIS tests were plain test functions without unittest discovery integration. Keep load_tests so the documented test command actually executes all eight disassembler checks. Running that file directly previously executed none.

- Godot importe les CSV comme traductions : conserver les octets privés sous une extension neutre pour FileAccess et tester le PCK exporté.
- Godot 4 expose template=true et standalone=false dans un runtime exporté. Tester les chemins sur le binaire exporté et conserver les sauvegardes hors du bundle signé.
- Restaurer la caméra après la première mise en page ; un fit différé exécuté ensuite annule silencieusement la restauration.

- Retour du propriétaire : le premier pixel art était trop sommaire. Une poignée de rectangles animés ne suffit pas ; prévoir silhouette détaillée, matière, lumière et une place lisible dans la composition avant de qualifier la présentation.

- Correction du propriétaire : Transartica doit être un jeu de gestion et d'histoire, pas un atlas illustré. Ne pas consacrer un nouveau jalon uniquement à un train décoratif. La carte, le décor glaciaire et les rails doivent servir la conduite, le combustible, les échanges, l'équipage et la campagne. Le train dessiné est accepté, les autres éléments sont à reprendre.


- Une archive macOS exportée et son application déjà décompressée sont deux
  artefacts distincts. Le build doit actualiser aussi l'application citée dans
  le README avant de lancer le test du binaire ; sinon il contrôle une ancienne
  version. Le test des ressources empaquetées a détecté cet écart.

- Correction artistique du propriétaire : qualité attendue comparable à Noita,
  interface fidèle à Transarctica. Les panneaux génériques et les formes simples
  dessinées par code ne satisfont pas cette cible. Comparer la composition aux
  écrans Amiga originaux et travailler une scène de cabine illustrée avec matières,
  lumière et personnages avant de poursuivre l'habillage de l'interface.

- Sur les écrans illustrés, ne jamais afficher les rectangles techniques des
  zones de clic comme survol. Une surbrillance doit suivre la silhouette alpha
  du sprite, le cercle d'un volant ou le contour réel de l'objet représenté.
  Garder les zones de clic tolérantes et invisibles ; vérifier le rendu au survol.

- Correction propriétaire : le poste de conduite et les menus exigent des contours relevés sur les objets réels, pas des cercles ou polygones approximatifs. La carte de jeu doit filtrer rendu, recherche et sélection par découverte ; la vue complète appartient aux outils de recherche.
- Incident 2026-09-25 : Godot headless lancé en sandbox a planté dans RotatedFileLogger avant le script et produit une alerte macOS visible par le propriétaire. Utiliser le lancement escaladé déjà validé, avec chemin absolu de journal local au projet ; distinguer crash du banc et crash de la fenêtre du jeu.
- Correction propriétaire : les instruments, carte en déplacement, combats, quartiers du personnel/capitaine, journal et pensées sont des écrans de jeu dédiés. Ne pas transformer cette structure en collection de modales textuelles. Préserver navigation de scène et interactions du décor ; une illustration seule ne prouve pas une phase jouable.
- Rejet visuel confirmé par capture : une silhouette polygonale approximative autour du conducteur et de sa roue est inacceptable. Le survol doit utiliser un masque enregistré sur les pixels de l'objet, avec les trous de la roue et les occultations de la rambarde ; ne pas remplacer une boîte grossière par un contour grossier.
- Correction supplémentaire du propriétaire : corriger tous les survols du bandeau, pas seulement le conducteur. Livre et frein conservaient des polygones grossiers après la première correction. Utiliser le même mécanisme de masque pour chaque objet interactif et vérifier plusieurs cibles avant d'annoncer la correction.

- Priorité explicite du propriétaire : les survols sont suffisamment améliorés pour ce jalon. Reporter leur finition ; chaque prochain jalon doit apporter une action de gameplay vérifiable.

- Correction immédiate : « priorité gameplay » ne permet pas de remplacer la scène oblique demandée par une carte schématique et un panneau de banc. Garder la qualité et la structure visuelles exigées lors du raccordement des systèmes; un test interne ne constitue pas l’écran à livrer.

- Avant de qualifier une scène de conduite de jouable, vérifier mouvement relatif décor/rails/train, choix effectif des aiguillages, approche de ville et freinage. Un sprite beau ne compense pas des commandes sans effet sur la navigation.

- Correction propriétaire du 26 septembre : le train accepté représente la composition de départ. Chaque wagon doit avoir ses sprites directionnels et son armement séparé ; les achats et réorganisations doivent se refléter en voyage et en combat. Les images de convoi complet servent de références visuelles, pas de modèle final de composition.
- Handoff Opus du 26 septembre : valider aussi le sens physique des extrémités asymétriques (verrière, canon) entre les caps. Un axe et un ordre de wagons corrects ne prouvent pas leur orientation individuelle.

- Captures propriétaire du 26 septembre : un alignement de l’axe du convoi entier ne valide pas les roues sur les voies. Vérifier chaque véhicule sur le trajet parcouru pendant un virage ; ne pas tourner un bitmap oblique pour simuler une autre perspective.

- Correction propriétaire après SE v3 / NW v2 : « les wagons sont toujours plus gros quand ils changent de direction ». Une échelle uniforme ne valide pas les dimensions représentées dans des dessins générés séparément. Comparer une même caisse dans tous les caps avec des repères de hauteur et de largeur, à zoom fixe. Une réduction de la hauteur totale du sprite ne suffit pas à déclarer le défaut corrigé.

- Clarification décisive : « meme longueur a l'ecran, les joueurs n'apprecieront pas les changements de taille ». Le critère porte sur la longueur visible en pixels, y compris de face. Le raccourcissement perspectif physique est donc abandonné pour les véhicules. Normaliser les silhouettes par rapport à E avec un facteur isotrope constant et empêcher les changements automatiques de zoom en virage. Voir `tasks/screen-length-contract.md`.

- Nouvelle correction immédiate : « il n'a jamais ete question d'avoir un raccourcissement perspectif, c'etait hors de question des le depart ». La recommandation précédente de normalisation isotrope par cap est invalidée : elle grossit aussi la largeur des vues de face. Le critère est le gabarit complet invariant, longueur ET largeur. Les images obliques indépendantes n'assurent pas ce résultat. Ne plus présenter la perspective comme une préférence demandée par le propriétaire.

- Mise à jour des plugins Codex : une session ouverte conserve les chemins des hooks chargés. Retirer une version avec `codex plugin remove` supprime son cache et casse ces sessions. Lors d'une migration, désactiver l'ancienne entrée pour les nouvelles sessions mais conserver ses fichiers jusqu'à la fermeture des sessions existantes. Incident observé sur context-guard 2.0.0 après installation 2.1.0 ; copie exacte restaurée et nouvelle configuration vérifiée sans double activation.

- Correction propriétaire du 26 septembre : nettoyer les résidus avant chaque fin de session. Supprimer les worktrees de l’agent dès la PR poussée et son HEAD distant vérifié, sans attendre le merge. Retirer clones de revue terminés, processus possédés, captures temporaires et archives en double. Vérifier les fichiers ouverts et préserver tout travail actif ou non sauvegardé. Mesurer les suppressions réelles avant de déclarer le nettoyage terminé.
