# Nettoyage des références,11octobre2026

La demande du propriétaire porte sur les références et fichiers conservés : seuls les résultats validés deviennent permanents. Les éléments de DA actifs restent provisoires.

## Résultat mesuré

40853 fichiers obsolètes ont été retirés. Les deux journaux de campagne complets ont été compactés sans perte, avec vérification SHA256 après décompression. Les suppressions et la compression retirent 2058605709 octets, soit environ2,06Go, avant les petits reçus ajoutés. Une variation globale de l’espace libre peut aussi provenir d’autres processus.

Le lot comprend40593 observations JSON et216 captures PNG non citées,27 copies d’images identiques à des assets conservés et9études explicitement refusées. Sept fichiers de l’application macOS étaient identiques aux membres du ZIP conservé; son lanceur généré devenu inutile a aussi été retiré. Les versions public-v1 dont les fichiers diffèrent des ZIP restent provisoires sous builds/public-v1.

Les empreintes de96sources du manifeste privé et21assets du candidat actif correspondent toujours à leurs manifestes. Les états de victoire/Sun et les preuves de sauvegarde sont présents. La fixture reverse-disappeared-journey.json et les scénarios nommés restent disponibles. Aucun jeu interactif n’a été lancé. Le test du protocole de captures sans fenêtre passe en0,999s, pic115792KiB, sous le plafond256MiB.

## Sorties temporaires

Trois anciennes études et l’ancien index de revue macro sont isolés dans le temporaire enregistré .cache/disk-hygiene-8liikow7. Les captures DA de travail du worktree ont rejoint ce même temporaire. Les déplacements n’ont copié aucun fichier.

Le pilote Python et la console Godot écrivent maintenant dans .cache/native-play/captures/. Le worktree utilise une destination distincte dans le temporaire enregistré. L’exporteur de revue DA écrit également dans ce cache. Les sauvegardes F5 restent à leur emplacement antérieur, hors captures.

Le déplacement global des assets actifs a été refusé par le contrôle automatique en raison du risque pour les chemins du worktree sale. Les assets et manifestes actifs restent donc en place, identifiés comme temporaires dans tasks/resource-retention.md. Aucun déplacement de ces chemins n’a été effectué.

## Vérification

Les4tests ciblés du pilote passent après la modification. Contrôles source et craft :0erreur,0avertissement. Relecture croisée : le spécialiste a contrôlé les dépendances du plan de suppression; l’orchestrateur a relu le correctif du pilote et ses tests. Le fichier optionnel snow-master-v2-candidate.png est supprimé; les4masters requis par build_combat_assets.gd sont conservés.

Reçus de cette passe : reference-cleanup-receipt-20261011.json, reference-cleanup-compression-20261011.json, reference-cleanup-builds-20261011.json, reference-cleanup-relocations-20261011.json et reference-cleanup-verification-20261011.json. Le détail des suppressions est conservé dans reference-cleanup-deletions-20261011.jsonl.gz. Les deux journaux de campagne compressés conservent leurs octets d’origine et restent locaux.

Les10worktrees existants sont conservés; aucun nouveau checkout n’a été créé. La DA reste en cours, avec le test de coins de relief encore à exécuter.
