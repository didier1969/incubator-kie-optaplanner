# ADR 002: Micro-Topology Routing (Scénario D)

## Context
Nous avons besoin de modéliser le routage intra-gare au niveau microscopique (quais, aiguillages, voies de garage) pour éviter les collisions à l'intérieur des hubs (Zurich HB). L'extraction de données OpenStreetMap a été étendue pour capturer la totalité du réseau suisse (150 Mo), incluant `service=siding` et `railway=switch`.

## Decision
Nous avons implémenté le "Scénario D" validé par l'architecte principal :
1. Elixir gère le téléchargement via l'API Overpass et l'injection via les structures explicites `OsmNode` et `OsmWay`.
2. Le moteur Rust (Data Plane) assemble le graphe de la micro-topologie dans le `NetworkManager` via `petgraph::algo::astar`.
3. Une fonction `route_micro_path` exposée en NIF permet un pathfinding hyper-rapide au sein des aiguillages, sans franchir les entités non-routables.

## Consequences
- Le chargement initial des 150 Mo est plus lourd mais est externalisé en tâche de fond (Mix Task).
- L'utilisation de Rust garantit que l'algorithme A* reste performant même avec des millions de noeuds (Scénario D).
- TDD Validé : test unitaire strict (mock Zurich HB) au vert sur le passage via aiguillage.
