# Reprise des découpes, 3 octobre 2026

Les huit SVG sont toujours refusés artistiquement. Huit nouvelles extractions imagegen depuis les scènes originales ont été produites sous game/assets/boudoir/cutouts/. Le premier essai de nettoyage de l’officier n’a pas corrigé les franges et n’est pas intégré.

Ces couches candidates conservent des franges colorées, des pixels extérieurs partiellement transparents et des variations RGB. Elles ne sont pas validées : le test natif échoue sur cinq assertions (tuyau du stoup, deux points de bottes opérateur, bois au-dessus du livre, bois près du cou de Kolotov). Rapport brut : validation/wagon-cutouts-native-20261003.log ; mesures : validation/wagon-cutouts-inspection-20261003.json. Ne pas modifier les assertions pour masquer ces défauts.

Le shader commun dispose maintenant d’un paramètre coverage_from_alpha, false par défaut. wagon_hover.gd choisit l’alpha pour les PNG, le rouge pour les SVG. Les deux scènes gardent leurs SVG ; les PNG sont examinés uniquement avec test_wagon_hover.gd -- --raster-candidates. Le test natif de référence passe. Aucun changement aux effets/animations d’Opus.

Le parcours natif complet du boudoir passe : navigation, inventaire, pause, sauvegarde/reprise, revolver. Preuve : validation/boudoir-resume-native-20261003.log. Le test menus/actions quarters passe mais un lancement sandboxé signale une erreur système de certificats macOS ; ce lancement ne constitue pas une validation du rendu natif.

Deux questions attendent la réponse du propriétaire : autorisation d’utiliser les outils raster locaux pour finaliser des découpes avec les pixels originaux, et actions reproduisant les dysfonctionnements du jeu. Les règles de l’outil imagegen imposent une instruction explicite avant une autre méthode de retouche ; aucune retouche locale n’a été effectuée. Le jeu n’est pas déclaré corrigé.

Processus propres d’import/test terminés. Aucun worktree ou téléchargement de dépendances créé. PNG candidats et rapports conservés pour reprise. Aucun commit/push de ce lot.

## Revue propriétaire et deux essais ciblés

Le propriétaire indique que les six autres couches semblent correctes ; table/carte et revolver seuls restent refusés. Six PNG conservés sans modification. Deux nouvelles extractions imagegen sont écartées : table déplacée et redimensionnée, revolver redessiné. Fichiers sous output/imagegen/wagon-cutouts-rejected-20261003/. Une tentative de couverture alpha binaire ne corrige pas la registration ; changement retiré. Retouche locale toujours en attente de réponse explicite, aucune retouche raster locale effectuée.

## Correction raster locale autorisée

Autorisation explicite « oui » reçue. Extraction locale des deux sujets depuis les pixels source, avec tracés manuels enregistrés dans tools/wagon-cutout-guides.json, sans détection de contours automatique. tools/author_wagon_cutouts.gd copie les pixels source et produit un alpha binaire. La table soustrait la silhouette alpha de l’officier déjà examinée ; aucune modification de ce PNG. Les six autres PNG restent inchangés. Les huit couches raster sont désormais raccordées aux scènes et le shader lit leur alpha.

Inspection indépendante : tous les pixels non transparents du revolver et de la table conservent exactement leur RGB source ; aucun alpha intermédiaire. Mesures : validation/wagon-local-inspection-20261003.json. Captures natives : output/wagon-cutouts-review-20261003/{boudoir-revolver,quarters-map}-local.png, galerie corrections.html ouverte. Validation artistique de ces deux corrections attendue.

Parcours natif complet boudoir après activation : PASS, validation/boudoir-local-cutouts-native-20261003.log. Le test hover conserve cinq échecs stricts sur les six autres couches inchangées (stoup, bottes opérateur, livre, Kolotov), validation/wagon-local-hover-native-20261003.log ; les interactions, rendu, resize/clear et point de cadre de table passent. Aucune suite entièrement verte annoncée. Aucun commit/push ; tous processus de test terminés.

## Acceptation artistique

Le propriétaire valide la correction locale table/revolver : « bon comme ca ». Les six autres découpes avaient été jugées correctes. Version des huit PNG conservée ; ne pas relancer de génération. Cette acceptation artistique ne transforme pas les cinq assertions strictes encore rouges en tests réussis. Prochaine priorité : reproduire les dysfonctionnements du jeu indiqués par le propriétaire.

## Contrat des tests après acceptation

Le test actif protège désormais les huit PNG acceptés au moyen du manifeste
`validation/wagon-cutouts-accepted-20261003.json` : empreintes SHA256, dimensions
identiques à la scène, points extérieurs transparents et valeurs alpha mesurées.
Pour les deux extractions locales table/revolver, chaque pixel visible doit aussi
conserver le RGB du pixel source à la même position. Les autres couches ne sont
pas présentées comme des copies RGB exactes. Les contrôles natifs de surbrillance,
clics, redimensionnement, effacement et blocage modal restent conservés.

Les trois exclusions anciennes restent absentes dans l'art accepté : tuyau du
stoup alpha253/255, bois au-dessus du livre alpha253/255, frange près du cou de
Kolotov alpha23/255. Les deux pixels de bottes sont conservés avec alpha251/255
et252/255. Ces valeurs sont enregistrées comme état accepté, sans les renommer
« exclusions réussies » ni prétendre à un alpha binaire.

`test_wagon_hover.gd -- --legacy-svg` garde les assertions strictes des SVG
historiques. `-- --raster-candidates` conserve les mêmes exigences strictes pour
un examen de candidats PNG ; il ne leur attribue pas la réception des huit PNG.
Le mode par défaut exige les empreintes acceptées : toute nouvelle image provoque
un échec jusqu'à une nouvelle revue explicite. La réception artistique est celle
du propriétaire, documentée ci-dessus, et ne certifie pas la campagne complète.

Les mesures de fichiers et la comparaison RGB ont été effectuées sans retoucher
les assets. L'exécution native de cette nouvelle version du test est à réaliser
séparément avant d'annoncer son résultat.

## Correction du livre après nouveau retour propriétaire

Le propriétaire précise ensuite : « Il faudra revoir le mask du livre, c'est le
seul qui est casse. » L'acceptation antérieure est donc retirée pour le livre
seulement ; les sept autres PNG restent inchangés.

La capture native `validation/continuous-play-20261003/7166.png` montre un contour
parasite au-dessus et à gauche du livre réel. L'ancien PNG couvrait, avec
alpha≥128, x863..1748/y513..809 ; le tracé source du livre est situé dans
x1017..1628/y623..825. Le défaut provenait de la couche agrandie et décalée.
Le shader commun reste inchangé.

Extraction locale du livre depuis les pixels source, avec le contour manuel
`tools/wagon-mask-guides.json` recopié dans `tools/wagon-cutout-guides.json`.
Commande reproductible : `author_wagon_cutouts.gd -- --subject boudoir-book`.
L'option de sélection évite de réécrire les autres couches et produit un rapport
propre au sujet. Les pages, couverture, stylo et ruban sont conservés ; papiers
posés dessous et revolver sont hors silhouette.

Le PNG candidat reste1828×860, alpha binaire,77486pixels visibles avecRGB source
exact à leur position. Bounds inclusifs : x1017..1627/y623..824. Mesure
indépendante : `validation/boudoir-book-local-inspection-20261003.json`.
Les sept autres empreintes correspondent toujours au manifeste précédent.

L'ancien SHA accepté du livre reste conservé dans le manifeste pour l'historique ;
la nouvelle empreinte est enregistrée comme candidate, sans réception implicite.
Le test de réception doit donc encore signaler le changement du livre tant que
sa surbrillance native n'a pas été inspectée. La vérification visuelle native et
la nouvelle réception restent à réaliser ; aucune validation du candidat n'est
annoncée ici.
