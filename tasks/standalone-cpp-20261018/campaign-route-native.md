# Parcours continu de campagne C++

`native-game/tests/campaign_route_tests.cpp` porte le parcours de
`game/tests/test_campaign_route.gd`, son planner et son pilote. Le parent possède
la compilation et l'exécution. Le19 octobre2026, le parcours continu et le
parcours avec restauration complète au mausolée atteignent le Soleil puis les
options :17222 cycles et2390 cellules entrées chacun, au jour36.
Il s'agit d'une preuve des contrôleurs de production ; les événements SDL et
la présentation dans l'application restent hors du périmètre de ce test.

Preuves durables : [sortie de compilation et garde](evidence/campaign-native-20261019/run.log)
et [reçu avec empreintes et événements](evidence/campaign-native-20261019/receipt.json).
Le garde termine avec code0, sans interruption, pic267760Kio pour le groupe de
processus possédé et durée76,645s. La sortie inclut aussi la compilation ; cette
durée n'est pas présentée comme une mesure du seul simulateur.
Les journaux complets comportent252 et253 lignes ; ils sont identiques après
retrait de l'unique ligne `MIDPOINT complete archive restored` du second.
L'archive complète reste dans le scratch privé d'origine, sans copie dans ces preuves.

La réussite vérifie l'égalité des sections `core`, `economy`, `world`, `campaign`,
`encounters`, `presentation`, `audio` et `launcher` après le chargement et à la fin.
L'état gagné avant la sauvegarde est aussi identique entre les deux départs.
La section tactique est conditionnelle ; ce parcours utilise le combat automatique.
Les assertions finales vérifient le Gycode3 à157,68, les cinq wagons à152,48,
le retrait du Minotaure29 après combat et la fin `Sun` sans dialogue restant,
avec retour aux options. Aucun succès de combat manuel n'est revendiqué.

```text
campaign_route_tests <game-dir> <existing-scratch-dir> <max-operations-per-run>
```

Le budget est fourni par l'opérateur et provoque un échec s'il est dépassé.
Ce n'est pas une règle de simulation. Les deux journaux et l'archive du mausolée
sont conservés dans un sous-répertoire unique ; aucun dossier existant n'est écrasé.
Ces sorties contiennent des données privées et doivent rester dans les sorties
ignorées du projet. L'audio utilise un périphérique fermé et le budget propriétaire
de1Gio ; le garde de processus reste à appliquer par le parent.

Le trajet commence au départ TABLE avec les six wagons et les carburants initiaux.
Commerce et rencontres utilisent la graine1 de la référence. Le planner recherche
les chemins sur les ports et virages de production ; il prédit localement les
révélations documentées, sans écrire dans le réseau vivant. Seuls les contrôleurs
de production modifient la carte pendant les entrées réellement simulées.

Les étapes restent celles de la référence : financement par fourrures, wagons et
travaux, Drill, Urga, recrutement et mission d'espion, mausolée, acquisitions pour
Oslo, sabotage, atelier de Leeds, Minotaure puis Soleil. Les achats revalident
chaque incrément de quantité. Le code d'Oslo est extrait du document réellement
présenté au mausolée ; les réponses des questionnaires viennent des données privées.
Aucune position, cargaison ou ressource acquise n'est injectée. Aucun drapeau de
quête ni résultat de combat n'est assigné par le pilote.

Adaptation du pilote après le premier essai : les deux wagons XL déjà prévus sont
achetés au premier passage à Ruhr, au lieu de répartir les achats sur ses deux
visites. Les deux transactions sont payées par le modèle et la masse est recalculée.
Le second passage reste un waypoint. Au refus observé, le journal indiquait2684 de
lignite et54 d'anthracite : la capacité restante de2262 ne permettait pas de créditer
les2280 de la vente fixe de38 fourrures. Le garde `NoCoalRoom` du modèle est conservé.
Le premier journal ne contenait pas le code exact du refus ; le diagnostic imprime
désormais ce code, l'incrément concerné et la charge réelle. L'essai suivant a
franchi ces transactions. Aucun nombre de cycles identique à l'ancien pilote n'est exigé.

Premier reçu : `disk-hygiene-54i1ct98/campaign-route-1792334610293566-0/continuous.log`
et `campaign-route.log` dans le dépôt principal. Le train avait parcouru2814 cycles
avant le refus ; les premiers achats et la première vente avaient réussi.

Deuxième reçu : `disk-hygiene-54i1ct98/campaign-route-1792335386311956-0/continuous.log`
dans le dépôt principal. Urga et le mausolée ont été atteints ; l'espion a été
envoyé par le contrôleur. Après une victoire automatique de marge1 et les achats
de Copenhague, le pilote perd à58,16, au cycle9060, avec291 lignite. Le journal
initial ne conservait que le message moteur vide : il omettait l'épitaphe de campagne.

La lecture de `native-game/app/game_events.cpp::GameSession::encounter` montre que
la défaite automatique efface le rapport et présente l'épitaphe105. Les autres
morts moteur ont un message explicite. Cette branche est donc la cause indiquée
par les sources ; le reçu ne permet pas encore d'identifier la force adverse ni
les wagons détruits. `game/scripts/combat_outcome.gd:247` et
`native-game/combat/outcome.cpp` utilisent la même puissance entière
`(soldats + mammouths*20 + canons*50)/50` et perdent si
`puissance - force_adverse/100 <= 0`. Une victoire peut détruire des wagons.
`game/tests/test_campaign_route.gd:141` remplace explicitement le premier canon
après les commerces Kiev/Baku/Turin ; ce remplacement n'a pas encore eu lieu ici.
Le reçu suivant confirme cette destruction.

Le diagnostic ajouté imprime la scène et l'épitaphe, les wagons avec leur état,
ainsi que les ennemis actifs et la marge au contact. Les victoires consignent leur
puissance initiale et les indices détruits. Aucun tirage aléatoire supplémentaire
n'est effectué. Le parent a exécuté le diagnostic dans
`disk-hygiene-54i1ct98/campaign-route-1792347061215089-0/continuous.log`.
La première victoire détruit les indices7,4,11,9, dont le canon11. À la défaite,
il reste5 soldats et aucun canon : potentiel0. L'ennemi3 à58,16 a une force102,
donc une marge−1. L'épitaphe105 est présente et aucun événement moteur n'est actif.
Un seul canon neuf aurait donné une marge0, également perdante.

Le pilote révisé finance les armes par les offres de `private-data/commerce.json`.
Il achète20 unités de sel à Amsterdam pour5 chacune et les vend à Granada pour13
sur le retour déjà prévu. À Granada, il achète la fourrure restante jusqu'au refus
réel de stock, capacité ou argent. À Amsterdam, il vend seulement la quantité
autorisée par le tender et conserve le reliquat dans le wagon. Après les achats
de travaux et Urga, il rejoint Gdansk pour acheter le wagon d'espion et au moins
deux canons pour450 chacun. Cet ordre est celui de
`game/tests/test_campaign_route.gd:100-116`. Si la vente du reliquat de fourrure
dépasserait encore la place disponible, il achète une arme supplémentaire avant
de retourner à Amsterdam vendre ce reliquat. Chaque commande conserve les gardes
du modèle ; un refus de paiement fait échouer le test. Le combat automatique est
activé à cet armement, après Urga comme dans la référence.

Au retour d'Urga, puis avant de quitter Copenhague pour Kiev, le pilote vérifie
ses armes intactes. Il rejoint réellement Gdansk lorsque leur nombre est inférieur
à deux. Le passage Gdansk après Turin complète aussi cet armement. À Leeds, les
armes surnuméraires sont retirées par les commandes d'atelier pour conserver les
cinq wagons exigés par la préparation source. Un seul tender est conservé depuis
le départ : en acheter un autre ferait obstacle à ce plan, car la règle source
de retrait teste la quantité du tender contre3 (`management.cpp:32`).

Le premier essai de ce financement achetait les armes avant In Salah. Son reçu
est `disk-hygiene-54i1ct98/campaign-route-1792358162696852-0/continuous.log` ;
`campaign-armed-execution.log` confirme l'échec avec code1. Les ventes et les
trois achats réussissent, puis les onze wagons atteignent physiquement les
travaux25,24 alors que la position logique est19,24. Le pilote n'a encore acheté
ni prison ni esclaves ni rails et échoue sur la pénurie au cycle3861.
`core/journey_contacts.cpp::advance_train` et `core/train_pose.cpp` font dépendre
le contact arrière de tous les wagons. Le pilote rétablit donc l'achat des trois
wagons après Urga, au point prévu par la référence, et transporte les11 fourrures
invendues jusque-là. Il n'efface pas la frontière et n'injecte aucune ressource.
Le reçu suivant, `disk-hygiene-54i1ct98/campaign-route-1792360488815620-0/continuous.log`,
confirme le passage d'In Salah et les achats d'esclaves et de rails. La première
crevasse25,24 est réparée ; le planner ne trouve ensuite plus de route vers
Helsinki depuis5,15, au cycle4972.

Les deux crevasses du trajet sont25,24 (CARTE67) et6,9 (CARTE69). Selon
`game/scripts/track_works.gd::WORKS` et `core/track_works.cpp::accept`, chacune
exige10 rails et consomme20 moins un tirage dans0..4. L'achat fixe de29 peut donc
laisser9 rails après la première réparation. Le reçu ne conservait pas les
quantités restantes ; cette pénurie était l'explication indiquée par les règles.
Le reçu final confirme la consommation20 puis10, avec0 rail restant après les
deux chantiers. L'achat est maintenant calculé depuis
les règles de production : maximum consommé au premier chantier plus minimum
requis au second, soit30. Les gardes de transaction restent actifs. Le journal
consigne désormais la consommation des travaux et les rails restants ; un refus
du planner affiche aussi les ressources disponibles.

Le reçu `disk-hygiene-54i1ct98/campaign-route-1792429620925364-0/continuous.log`
confirme que Turin refuse le trentième incrément avec code1, `StockLimit` dans
`economy/trade.hpp`. Le train possède4167 lignite et60 places disponibles ;
`economy/trade.cpp::increment_refusal` identifie donc le stock comme contrainte.
`private-data/commerce.json` donne aussi une offre de rails à Marrakesh41, à4 par
unité avec un stock initial20 plus un tirage0..19, comme à Turin35.
Le pilote visite désormais Marrakesh après l'achat des esclaves et y achète jusqu'au
besoin calculé30 ou au premier refus réel. À Turin, il achète le solde manquant
d'après sa cargaison actuelle. Les deux visites et tous les paiements passent
par les contrôleurs de production. Cette nouvelle visite précède le passage à
Marrakesh déjà prévu après Helsinki ; elle ne remplace pas cette étape de la référence.

Le reçu `disk-hygiene-54i1ct98/campaign-route-1792430434713282-0/continuous.log`
confirme les travaux, Urga et le mausolée avec ce ravitaillement. Après le combat,
le convoi compte15 wagons, dont deux captures, et ne possède plus qu'un canon
intact. Le trajet vers Copenhague répète plus de50 fois `REVERSE29,17` avant
l'épitaphe101 et le message moteur `No coal remaining`, au cycle14445.
Le planner logique ignore le chemin retenu sous tout le convoi et peut donc
rechoisir la même manoeuvre après une déviation physique.

Le pilote mémorise maintenant les inversions tentées par cellule, cap et phase
pendant chaque étape. Les replannings cherchent une route sans rejouer ces mêmes
inversions ; le registre est vidé à la prochaine étape. Cette restriction porte
sur les commandes du pilote, comme `allow_midtrack_reverse` dans le planner de
référence. Elle ne modifie pas la possibilité de reculer dans le jeu ni les règles
d'aiguillage. Si aucune route ne reste, le test échoue avec les ressources réelles.
Ce planner ne constitue toujours pas un solveur complet des contacts physiques.

Le reçu `disk-hygiene-54i1ct98/campaign-route-1792431361212127-0/continuous.log`
confirme que les inversions ne bouclent plus sur cette étape. À Copenhague, après
le remplacement réel du canon à Gdansk, le train possède433 lignite. L'achat de50
rails à3 laisse283. Le trentième lot de viande prévu coûte300 et l'incrément29
est déjà refusé avec `NoMoney`50. Acheter les28 unités abordables laisserait3
lignite pour voyager. Le pilote reporte donc l'achat des rails après la vente
de viande à Kiev. Il achète au plus les30 unités de la référence, en respectant
chaque garde, puis vend la quantité réellement achetée. Il retourne physiquement
à Copenhague acheter les50 rails, puis reprend le trajet par Kiev vers Baku.
Avec le solde observé, cet ordre conserve133 lignite avant le premier trajet à
Kiev. Le reçu final `campaign-route-1792432727886147-0` confirme que ce trajet,
le retour payé aux rails et la suite jusqu'au Soleil réussissent dans les deux runs.

La révision finale a réussi sur la graine1. Elle ne garantit pas la survie sur
d'autres parcours : les ennemis restent actifs et une victoire peut détruire les armes.
La graine reste1 ; aucun résultat de combat ni drapeau de quête n'est forcé.
Un wagon détruit ne peut pas être réparé (`management.cpp:21`). Le combat manuel
reste une commande du jeu, mais ce pilote n'en simule pas les actions tactiques.

Chaque cycle passe par `GameSession::advance` et conserve les populations actives.
Le train utilise les contacts physiques actuels, y compris en marche arrière.
Une divergence de route ou une frontière sans traitement fait échouer le test avec
sa dernière position. Le pilote ne répare pas le modèle pour poursuivre.

Le premier parcours est continu. Le deuxième reproduit le même départ et compare
son état gagné au mausolée, écrit une archive complète puis réinitialise les modèles
avant de la charger. Toutes les sections sont comparées après restauration et à
la fin ; les nombres de cycles et de cellules entrées doivent également correspondre.
La réussite exige les passages Gycode/pente observés, le Minotaure retiré après
combat et la transition finale aux options.

Limites du laboratoire : les commandes passent directement par les contrôleurs et
transactions, sans événements SDL. Le choix du combat automatique et la fermeture
du rapport reproduisent les affectations de `SessionUI`. Les pauses et leviers
sont commandés par le pilote. Le planner connaît les révélations documentées et le
pilote consulte les réponses privées ; ce n'est pas une mesure de difficulté joueur.
Les cues audio et pixels ne sont pas évalués ici. Les scènes réelles et leurs clics
doivent faire l'objet des vérifications complémentaires dans l'application.
