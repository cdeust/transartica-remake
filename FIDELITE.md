# Contrat de fidélité

Décisions du propriétaire, 24 septembre 2026.

Édition de référence confirmée : **Amiga 500 ECS en anglais**. Le propriétaire ne dispose plus des disquettes. Cette identification suffit pour avancer. La révision exacte ne constitue pas un préalable ; comparer les versions uniquement lorsqu'une différence concrète apparaît dans les sources ou le jeu.

## Résultat attendu

Un remake complet de Transarctica, conservant histoire et carte du monde originales. Les adaptations concernent les commandes clavier/souris et la présentation en pixel art moderne. Toute modification des règles de fond exige une décision explicite du propriétaire.

Projet personnel et gratuit, code nouvellement écrit sous MIT. Multiplateforme, priorité à une release Windows téléchargeable depuis le dépôt. Unity ou Unreal restent des possibilités pour une future présentation 3D ; aucun portage 3D n'est inclus dans la première version.

## Preuves exigées

| Domaine | Référence à établir | Critère de validation |
|---|---|---|
| Édition originale | Amiga 500 ECS anglais ; provenance des fichiers lorsqu'ils seront disponibles | Référence suffisante pour avancer ; approfondir les variantes seulement en cas de différence constatée |
| Carte | Relevé des voies, aiguillages, lieux, connexions et passages spéciaux | Comparaison systématique, aucun lieu ou raccord supprimé ou ajouté sans décision |
| Histoire | Inventaire des événements, dialogues, indices, conditions et conséquences | Chaque élément associé à une preuve dans l'original et à son équivalent dans le remake |
| Campagne | Parcours de référence du début à la fin, avec sauvegardes intermédiaires | Partie complète dans le remake, mêmes étapes obligatoires et même dénouement |
| Règles | Observations des ressources, commerce, déplacement, combat et IA | Cas de comparaison reproductibles ; écarts explicitement examinés |
| Commandes | Correspondance entre actions originales et nouvelles commandes | Toutes les actions utiles accessibles ; raccourcis configurables sans changement implicite des règles |
| Temps | Horloge de simulation séparée du rendu | Résultats identiques à temps simulé égal pour mêmes entrées et même graine, aux cadences testées |
| Distribution | Paquet autonome Windows ; autres plateformes à préciser | Lancement, sauvegarde et reprise vérifiés sur chaque plateforme annoncée |

Ces vérifications sont prévues, pas encore réalisées. Une démonstration technique ou une zone jouable ne prouvera pas la complétude du remake.

## Méthode documentaire

L'original est la référence. Les remakes communautaires sont des pistes techniques ; ni leur existence ni leur statut « jouable » ne prouvent une campagne complète ou une carte fidèle.

Chaque élément relevé distinguera : preuve originale observée, description du manuel, information communautaire à confirmer, ou proposition d'adaptation. Les inconnues resteront explicites. Les remakes tiers ne fourniront pas silencieusement les éléments manquants.

Prochaine étape : rechercher une source vérifiable de l'édition Amiga 500 ECS anglaise, puis établir les inventaires de carte et de campagne. Les documents et vidéos peuvent alimenter ces inventaires dès maintenant ; la fidélité complète ne sera pas déclarée sur cette seule base. Le choix du moteur reste provisoire jusqu'à ce cadrage.

## Couverture visuelle : clarification du 27 septembre 2026

L'intégralité des visuels de l'original entre dans le périmètre du remake, avec
une qualité de pixel art inspirée de Noita : scènes, villes, intérieurs, cartes,
voies, aiguillages, obstacles et travaux, personnages, véhicules, combats,
interfaces et séquences de campagne. Les exemples donnés par le propriétaire
ne constituent pas une liste limitative. L'inventaire incombe au designer.

Le combat exige une scène et une échelle de présentation étudiées séparément
du voyage. Partager la composition et l'état du train ne suffit pas à en définir
le cadrage. Comparer les références ECS avant de fixer projection et dimensions.
L'exigence de gabarit invariant lors des changements de direction demeure.

Chaque élément doit relier une preuve originale à un dessin du remake, ses
variantes, son intégration et une vérification dans le jeu. La clôture exige
une revue des scènes et états de campagne ; aucune complétude ne sera déduite
du seul nombre de PNG. Suivi : `tasks/visual-coverage.md`.

## Licence des contenus

MIT est le choix pour le code créé dans ce projet. La provenance et les permissions des éléments de contenu seront suivies séparément ; le choix MIT du projet ne constitue pas une autorisation sur les éléments originaux. Les sources sur ce point figurent dans DOSSIER.md.

## Adaptations confirmées : 26 septembre 2026

Le 4 octobre 2026, le propriétaire autorise la même entrée et sortie masquées
qu'en ville pour les impasses sans ville : « Oui pareil que pour les villes ».
Le départ réutilise la gare source, sans ajouter de voie ni modifier marchandises,
ressources ou histoire. Les wagons réapparaissent progressivement derrière la
locomotive. Les demi-tours ordinaires conservent leurs contacts physiques.

Le propriétaire demande un frein de service progressif, pour anticiper l'arrêt.
Les scripts ECS arrêtent au prochain pas logique avec le levier : le comportement
progressif du levier est donc une adaptation explicite du remake. Sa calibration
initiale réutilise la baisse de5 par cycle du régulateur d'origine; elle ne prouve
pas un modèle physique réel. Le frein conserve le réglage du régulateur.

Les explosions des combats seront modernisées en pixel art inspiré de Noita,
avec débris, fumée et lumière, sans reprendre les sprites d'explosion d'origine.

Le propriétaire confirme une longueur visible constante pour un même wagon dans
toutes les directions, y compris de face. Le gabarit doit rester identique ; le
zoom ne doit pas changer automatiquement pendant un virage. Le raccourcissement
perspectif était exclu dès le départ. Les prototypes ne satisfont pas encore
cette exigence.

## Carte du monde : prochaine passe visuelle, 5 octobre 2026

Le propriétaire demande, après la fin du premier playthrough, une carte du monde à la qualité des visuels des villes. Les paysages doivent s'inspirer des villes alentours et constituer un relief cohérent, en conservant la géographie et les connexions ferroviaires originales. Cette passe est planifiée, pas encore réalisée ; le playthrough reste prioritaire.
