# ADR 004: Kinematic Penalties & Inertia Modeling in A* Routing (Phase 5)

## Context
Dans les phases précédentes, l'algorithme A* de HexaRail (implémenté en Rust) opérait sur la micro-topologie (Scénario D) en calculant le chemin le plus court basé exclusivement sur la distance (Edge Weight). Cette approche s'est révélée insuffisante pour une modélisation ferroviaire haute-fidélité : un train de marchandises lourd et un TGV léger ne réagissent pas de la même manière face à des aiguillages serrés qui requièrent un freinage d'approche et une lente ré-accélération. 

Sans cette modélisation physique (Inertie), le solveur (et par extension les métaheuristiques de type Tabu Search) allouait de manière irréaliste des trajectoires hachées à des trains lourds, causant de potentiels faux-positifs dans les horaires du jumeau numérique.

## Decision
Nous avons basculé d'un routage "Pure Distance" vers un routage "Time & Kinematics". 

1. **Injection des Profils (Elixir)** : Le Control Plane Elixir maintient la `FleetProfile` de chaque convoi (`mass_tonnes`, `acceleration_ms2`, `max_speed_kmh`) et l'injecte dans le dictionnaire `Fleet` de Rust via le NIF `load_fleet`.
2. **Altération de la Fonction de Coût A* (Rust)** : Le NIF `route_micro_path_with_kinematics` a été créé. La fonction de coût de la librairie `petgraph` a été surchargée :
   * La vitesse de base est calculée selon le profil.
   * Lorsqu'une arête est identifiée sémantiquement comme un aiguillage (tagué et pondéré en Phase 4), le moteur simule une "restriction de vitesse" à `40km/h` (`11.1 m/s`).
   * Le coût retourné par l'arête n'est plus la distance, mais le **temps en secondes** calculé via la formule cinématique : $t = d/v + \Delta v / a * 2$.
   
Cette décision garantit que l'algorithme privilégiera toujours une trajectoire droite pour un convoi à faible accélération (Fret), quitte à faire un léger détour kilométrique, tout en permettant à un convoi agile (RER S-Bahn) de serpenter efficacement dans les faisceaux de la gare de Zurich.

## Consequences
- Le solveur a désormais la capacité de déterminer si une perturbation d'horaire est physiquement rattrapable ou non en fonction du poids du train.
- Temps de calcul de l'algorithme : impacté négligeablement (calculs en $O(1)$ dans la boucle de l'A*).
- Validation TDD : Test `HexaRail.KinematicsTest` au vert, certifiant mathématiquement que le convoi de Fret met plus de temps que le TGV sur la même topologie d'aiguillages.
