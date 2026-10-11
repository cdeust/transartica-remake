# Conservation des fichiers Transartica

Règle du propriétaire du11octobre2026 : conserver les fichiers finaux validés. Les études en cours et les captures de travail sont temporaires ; retirer les essais remplacés et les doublons vérifiés.

| Chemin | Statut et règle |
| --- | --- |
| game/assets, code et tests versionnés | Sources de la version exécutable. Leur présence ne prouve pas l’acceptation de toute la DA. Publier les modifications validées sur GitHub. |
| reference-private/manifest.json et ses fichiers | Sources historiques privées authentifiées. Conserver les seuls originaux et les données nécessaires aux vérifications ; aucun envoi public. |
| reference-private/observations, map, city-scripts, audio, finale | Références décodées utilisées par les outils et les preuves de fidélité. |
| .cache/native-play/saves et reference-private/validation | Sauvegardes acquises et scénarios utiles. Hors nettoyage des captures. |
| tasks/evidence et preuves citées dans tasks/validation | Rapports utiles et sélection de résultats. Les journaux de campagne volumineux sont conservés sans perte sous .gz. |
| .cache/disk-hygiene-8liikow7 | Temporaire enregistré de cette session : anciennes études et captures DA encore non validées. Aucune image de ce dossier ne constitue un livrable accepté. |
| reference-private/artwork-world-20261011, reference-private/map-scenes | Manifestes et données de travail temporaires encore consommés par la DA. Chemins conservés pendant l’intégration ; supprimer les candidats remplacés lors de la promotion finale. |
| .worktrees/map-object-renderer/game/assets/travel/terrain/scenes | Assets de travail non validés du worktree actif. Conserver leur chemin jusqu’à la validation puis ne promouvoir que les fichiers retenus. |
| builds et output | Sorties de fabrication et sources d’auteur intermédiaires. Elles restent provisoires sauf lien explicite vers une validation finale ; ne pas les présenter comme une nouvelle release. |

Les nouveaux journaux et captures du pilote vont dans .cache/native-play/captures, relié au temporaire enregistré. Le worktree possède sa propre destination. Son exporteur de revue DA écrit aussi dans ce cache. Pour une nouvelle session, créer un temporaire avec disk-hygiene/create-temp avant de raccorder les sorties ; ne pas recopier les images pour constituer un historique.

Avant de disposer le temporaire, conserver la sélection finale et retirer ses liens de sortie. Les checkouts contenant des modifications non publiées restent protégés. Le reçu tasks/evidence/reference-cleanup-receipt-20261011.json décrit les suppressions ; reference-cleanup-relocations-20261011.json décrit les déplacements sans copie.
