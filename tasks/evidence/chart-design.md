# Carte de navigation : séparation du relevé et du rendu

La grille d'octets colorés est un outil de diagnostic, pas une carte finale.
Le rendu par défaut montre les positions des villes décodées dans FORMAT-VILLES.md,
sur un fond cartographique uniforme, avec repères de coordonnées. Il ne transforme
pas les codes opaques en montagnes, mers ou connexions ferroviaires supposées.
Les couleurs, marges et tailles sont des choix de présentation originaux.

La couche diagnostique reste accessible séparément. Elle conserve les données
exactes pour le travail de décodage, sans constituer une navigation jouable.
Le réseau complet attend la validation des transitions TIME, des obstacles et
des embranchements. Aucun déplacement libre hors des rails ne remplace ces règles.
