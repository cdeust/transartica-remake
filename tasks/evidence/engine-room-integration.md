# Chaufferie interactive

Le propriétaire autorise une chaufferie jouable à partir de la direction illustrée.
Les règles de combustible, chauffe, réserve, vitesse et frein restent celles de
locomotive-rules.md, avec la composition initiale fixe de six wagons.

Cadence : engine-cadence.md prouve trois minutes de jeu par mise à jour de chauffe,
mais pas leur durée réelle. La préversion utilise une seconde réelle par mise à
jour comme calibration de présentation, explicitement non certifiée Amiga. La
cadence est injectée dans EngineSession et testée à 15 et 60 images par seconde.
Le rendu ne commande jamais le nombre de mises à jour. Pause, événements non
portés et perte de focus arrêtent la simulation sans accumuler de retard.

Choix artistiques : composition logique 1600x1000, recadrage proportionnel,
interpolation nearest, positions de personnages et zones interactives relevées
sur background.png. Les durées des poses, transparences, éclats, couleurs,
aiguilles et particules servent la présentation ; elles ne sont pas des règles
physiques. Les tableaux de sprites sont découpés en régions mesurées, avec pivots
aux pieds pour éviter de déplacer le personnage avec les marges de chaque pose.

Commandes : cliquer le chauffeur ou le compteur de son combustible fait tourner
son taux 0/1/2; le poste de commande supérieur règle le régulateur; le levier du
bandeau applique le frein. L/A chargent, flèches gauche/droite ajustent la cible,
B freine, Espace pause, F5 sauvegarde la session, F6 la restaure, R recommence.
Les panneaux Carte et Journal sont secondaires et réversibles. Les événements
non portés arrêtent la conduite à une limite explicitement indiquée.

Le décor, les huit poses et les quatre images de feu proviennent de l'outil
image_gen intégré. Ils sont distincts des compteurs réels et des zones actives.
Leurs prompts et références sont conservés dans output/imagegen/ ; cette
intégration n'établit pas de licence MIT sur les références historiques.

Performance : budget de présentation choisi à 60 images/s (la cadence de
simulation reste indépendante), cache du rendu figé et mode faible consommation
Godot, qui ne redessine que si nécessaire. Référence API :
https://docs.godotengine.org/en/4.5/classes/class_projectsettings.html#class-projectsettings-property-application-run-low-processor-mode
La mesure native reproductible se trouve dans tasks/validation/bench_engine_room.gd.
Les valeurs de présentation sont des choix de préversion, pas des constantes historiques.

Écran instruments : `engine_instruments.gd` gère E (régulateur) et F (retour),
`instrument_art.gd` rend la nouvelle illustration `instruments.png`, des aiguilles
et les valeurs vivantes. La simulation continue dans cet écran. Le rendu utilise
la disposition fonctionnelle A–F du manuel, pas une reproduction des pixels
originaux. Les positions ont été relevées sur l'illustration générée.
La valeur numérique de réserve est divisée par 200 comme TRAIN 0x8cf–0xab6.
Les associations sémantiques A/D sont inférées, voir boiler-instruments.md.
