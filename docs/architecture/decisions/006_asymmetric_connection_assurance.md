# ADR 006: Asymmetric Connection Assurance (Anschlusssicherung) & Chaos Propagation

## Context
Dans le cadre de la Phase 19 (Simulation Haute-Fidélité), nous devions définir le comportement du système lors de retards affectant les correspondances (Transfers). 
Si l'on simule les 40 000 objets GTFS (Trains, Bus, Trams), le système devient un bruit blanc dénué de sens opérationnel. De plus, la règle "Un train en retard met en retard tous les autres véhicules" est fausse. La Suisse applique une politique d'*Anschlusssicherung* stricte mais asymétrique (basée sur la "Chaîne de Responsabilité").

## Decision
Nous avons établi un **Modèle de Cohérence Hybride** et un système d'attente asymétrique :

1. **Filtrage du Domaine (Scope)** :
   *   **Inclus (Simulation Physique 3D)** : Rail pur (InterCity, Régio, S-Bahn, Cargo). ~2 500 agents simultanés.
   *   **Inclus (Simulation Logique)** : Dépendances mobiles (Bus régionaux, CarPostal). Modélisés uniquement comme des points de départ liés à une gare pour évaluer la casse des correspondances.
   *   **Exclus** : Trams urbains et bus de ville à haute fréquence.

2. **Tolérance d'Attente Asymétrique (Waiting Tolerance)** :
   Le standard GTFS (`transfers.txt`) indique les correspondances garanties (`transfer_type = 2`) mais n'inclut pas les temps d'attente maximum (tolerance). Nous les injectons dynamiquement lors de l'import via Ecto/PostgreSQL :
   *   **Train vers Train** : Tolérance de **2 minutes** (120s). Les trains ont des sillons stricts à respecter.
   *   **Train vers Bus/CarPostal** : Tolérance de **5 minutes** (300s). Le bus agit comme distributeur final.
   *   *(Future évolution)* : La "Dernière correspondance de la journée" recevra une tolérance de 15 minutes.

3. **Propagation du Chaos (Score Engine)** :
   Dans le moteur Rust `HexaCore` (Salsa) :
   *   Si Retard Train A $\le$ Tolérance Véhicule B $\rightarrow$ Le Véhicule B attend. Le retard se propage physiquement au Véhicule B.
   *   Si Retard Train A $>$ Tolérance Véhicule B $\rightarrow$ Le Véhicule B part à l'heure. La correspondance est brisée. Le retard ne se propage pas, mais une **Pénalité Majeure de Score** est appliquée au jumeau numérique.
   *   **Visualisation** : Un bris de correspondance génère une impulsion lumineuse rouge (*Flare*) sur la gare dans le frontend MapLibre/Deck.gl.

## Consequences
- Le nombre d'agents simulés visuellement (GPU) passe d'un irréaliste 40 000 à environ 2 500, permettant l'activation des "Serpents" curvilignes 3D en 60 FPS.
- Le moteur de score incrémental gagne une dimension d'évaluation cruciale pour la "Service Quality".
- Cette architecture asymétrique sera réutilisée dans *HexaFactory* (où un camion n'attendra pas plus de X minutes une palette en retard).