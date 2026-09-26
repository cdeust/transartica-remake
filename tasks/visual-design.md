# Direction visuelle du deuxième jalon

Le propriétaire demande une meilleure qualité de pixel art. Les dimensions,
couleurs et formes ci-dessous sont des choix graphiques nouveaux, pas des valeurs
prétendument extraites du jeu original.

- Scène principale de 300 pixels de haut dans la fenêtre de 900 pixels : un tiers
  de la hauteur donne assez de place à la locomotive et conserve la carte visible.
- Dessin natif sur une grille de 480 × 144 pixels, agrandi par facteur entier.
- Locomotive vapeur : chaudière à silhouette arrondie par marches, tuyaux,
  roues, bielles, tender, fenêtres et phare ambrés.
- Plans de montagnes, neige et conifères ; tons bleu ardoise et cyan froid,
  rehauts ivoire, rouille et laiton. L'animation illustre l'ambiance seulement.
- La carte conserve ses octets et ses coordonnées. Sa palette est diagnostique,
  avec des repères abstraits de localisation ; elle ne déduit pas des types de terrain.
- Le dessin de la carte est découpé à son panneau pour ne pas recouvrir la scène
  ou les commandes pendant le déplacement et le zoom.

Vérification : rendu Godot réel, tests existants, puis export macOS et Windows.
Le contrôle visuel doit porter sur la scène à sa taille réelle, pas seulement sur
le code ou une image agrandie hors contexte.

## Révision du fond glaciaire

Le propriétaire a retenu la locomotive détaillée et demandé un fond entièrement
glaciaire. Les étoiles et conifères disparaissent; deux couches de reliefs irréguliers
en marches, des strates d'icebergs, fissures, congères et fragments de neige balayés
occupent le paysage. La voie présente deux rails d'acier sombre, leurs attaches,
traverses et ballast bleuté sous une fine couche de neige. Ce sont des choix de dessin
neuf, sans localisation, terrain, raccord ou règle tirés du jeu d'origine.

La vignette expose `set_motion(speed_ratio)`, borné de 0 à 1. Elle reste immobile
par défaut; bielles, roues, neige et vapeur ne bougent que quand l'application
transmet une vitesse. Ces effets visuels n'affirment aucune règle de circulation.
