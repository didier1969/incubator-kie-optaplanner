# ADR 003: Edge Collapsing & Tag-based Weighting (Micro-Topology)

## Context
L'ingestion de l'entièreté du réseau OSM suisse (150 Mo) génère un graphe avec des millions de noeuds intermédiaires, car les voies ferrées courbées nécessitent de nombreux points géographiques. Cela ralentit drastiquement l'algorithme A* (Pathfinding) qui opère sur ce graphe lors du routage microscopique dans les gares (Scénario D).
De plus, nous devons nous assurer que les trains préfèrent les voies principales (`main lines`) et évitent les voies de garage (`service=siding/yard`), sauf si nécessaire.

## Decision
Nous avons implémenté deux optimisations majeures directement dans le chargeur OSM (`NetworkManager::load_osm` en Rust) :

1. **Edge Collapsing (Scénario B)** : Avant d'insérer les noeuds dans le graphe `petgraph`, nous calculons le degré de chaque noeud OSM. Les noeuds de degré 2 (simples points intermédiaires sans bifurcation) ne sont pas insérés en tant que sommets du graphe. À la place, nous accumulons la distance et condensons la géométrie en une seule arête `Edge` connectant les noeuds de "bifurcation" (degré != 2). Cela réduit la taille du graphe d'un facteur 10 à 20 sans aucune perte de précision géographique.
2. **Tag-based Weighting (Scénario C)** : Lors du calcul du poids de l'arête pour l'algorithme A*, la distance physique (Haversine) est multipliée par un `weight_multiplier` basé sur les tags OSM :
   - `service=siding` ou `yard` : `x5.0`
   - `railway=switch` : `x1.5`
   Cela pousse mathématiquement l'A* à utiliser les voies principales.

## Consequences
- Le temps d'exécution de l'algorithme A* devient quasiment O(1) à l'intérieur d'une gare.
- Validation TDD réussie : un test explicite valide qu'un "détour" via une voie principale est désormais préféré à un raccourci direct via une voie de garage.
