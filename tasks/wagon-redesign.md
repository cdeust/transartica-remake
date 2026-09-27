# Redesign des 19 wagons — 26 septembre 2026

Demande : « Fais le redesign... » après mesure de largeurs de 95 à 139 pixels dans l'atlas.

Référence de gabarit : les six sources détaillées déjà intégrées, types 1, 2, 3, 17, 21 et 23. `vehicles-overhead.json` mesure leurs largeurs solides à 134–139 texels, avec une réduction commune 1/3. Le type 3 fournit le châssis visuel de référence. Ces dimensions sont un choix artistique du remake, pas une mesure des véhicules historiques.

Cause : génération séparée avec une référence de style, sans verrouiller le même châssis. Une toile identique ne garantit pas une largeur de véhicule identique.

Objectif : redessiner les 19 types sur le gabarit des six véhicules initiaux, avec leur équipement distinct, et mesurer les sources obtenues avant remise à Opus. Aucune déformation non uniforme ni changement du moteur de rendu. Conserver les sources détaillées et documenter les limites pour les futurs combats destructibles.

- [x] Éditer un premier wagon en conservant le châssis et les attelages du type 3.
- [x] Vérifier visuellement et mesurer le gabarit avant de produire les autres.
- [x] Redessiner et vérifier les 19 types, conserver les six références.
- [x] Livrer catalogue, prompts, galerie comparative et mesures pour Opus.
- [x] Commiter localement les livrables et le suivi.

Mesure : comparer l'enveloppe solide avec la convention alpha >= 128 utilisée par `tools/build_overhead_atlas.py`, et examiner séparément la largeur du châssis, afin qu'un accessoire saillant ne masque pas une caisse trop étroite. L'objectif est le gabarit observé des six références. Tout écart restant doit être rapporté, pas masqué par un changement d'échelle.

## Revue de livraison

19 PNG édités, 1024 × 1536, avec prompts et SHA-256 conservés dans `output/imagegen/wagon-redesign-20260926/`. Les six références sont liées sans duplication dans le catalogue complet.

Mesure source : 401–407 pixels de large pour les 19 redesigns, contre 401–417 pour les six références. Mesure après exécution en mémoire des fonctions `clean_alpha`, `downscale` et `solid_box` de `tools/build_overhead_atlas.py` au commit `db3c4b4` : 134–136 texels pour les 19 redesigns, contre 134–139 pour les six références. Résultats par type dans `atlas-measurements.json`. Aucun PNG source ni atlas de jeu modifié par cette mesure.

Les 25 fichiers sont lisibles; les 19 longueurs restent dans la plage des six références. Les coins à alpha 1 des types 4, 8 et 19 sont rapportés dans les mesures; garder le détourage existant. Revue visuelle des 19 images effectuée. Ruff et vérification des liens de galerie effectués. Aucun test de jeu revendiqué : cette livraison est artistique et attend le raccordement d’Opus.

## Revue de l’intégration 8242d1c

Codex a examiné `overhead-atlas-after-purchase.png` et `overhead-atlas-curve.png`. Les caisses ajoutées ont une largeur visuellement cohérente avec le convoi initial sur la capture à dix véhicules. À cette échelle de voyage, les équipements les plus fins se confondent partiellement; ces captures ne valident pas encore la lisibilité au zoom de combat. Le journal `overhead-atlas-redesign-tests.log` contient 11 PASS et exit=0; les tests n’ont pas été relancés par Codex pour cette revue.

Responsabilité de la suite artistique : Codex. Livrables restants : châssis et intérieur sous le toit, toit séparé, armes et équipements mobiles séparés avec pivots, cartes de matériaux et occupation contrôlées sur les pixels. Opus assure leur intégration et la simulation. Les coefficients physiques et règles de dégâts ne sont pas décidés par les images.
