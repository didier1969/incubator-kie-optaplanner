# ADR 005: Extraction of the Agnostic Core (Framework vs Vertical)

## Context
Initialement conçu comme un "Jumeau Numérique SBB" (HexaPlanner), le système a fini par coupler fortement la mécanique d'optimisation mathématique (A*, Salsa Incremental, Metaheuristiques) avec les règles du domaine ferroviaire (GTFS, Rolling Stock, OSM).
Cette adhérence empêche l'utilisation du moteur pour d'autres verticaux (Logistique routière, Planification de personnel, Supply Chain industrielle). Conformément à la directive d'architecture, la codebase entre dans une phase de stabilisation et de scission (Separation of Concerns).

## Decision
Nous séparons la base de code en deux couches logiques et physiques :

1. **`HexaCore` (The Agnostic Engine) :**
   - **Elixir :** Orchestration générique (`dsl`, `transpiler`, `solver_nif`).
   - **Rust (`hexa_solver`) :** 
      - Le graphe `petgraph` devient générique (Noeuds = `Entity`, Edges = `Relation`).
      - Le moteur incrémental `salsa` évalue des `Constraints` abstraites, sans connaître la notion de "train" ou de "gare".
      - Les métaheuristiques (`localsearch`, `metaheuristics-nature`) opèrent sur un espace de recherche abstrait (`Problem` et `Job`).

2. **`HexaPlanner` (The Railway Vertical) :**
   - **Elixir :** Ingestion métier (`gtfs`, `rolling_stock`, `data/osm`), et Interface utilisateur (`HexaPlannerWeb`).
   - **Rust (Extensions) :** Le vertical ferroviaire implémente les Traits du `HexaCore`. La `NetworkManager` devient `RailwayManager`, injectant ses fonctions de coûts cinématiques spécifiques (Phase 5) en tant que *plug-ins* dans l'A* de `HexaCore`.

## Consequences
- Le NIF `SolverNif` deviendra une API générique : au lieu de faire `SolverNif.load_trips()`, on fera `SolverNif.load_entities(:trip, trips)`.
- La compilation de Rust sera plus rapide et modulaire.
- Permettra de créer à l'avenir un `AeroPlanner` ou un `LogisticsPlanner` en réutilisant 100% de `HexaCore` et 0% du métier CFF.
- Cette refonte nécessitera de casser temporairement les tests pour migrer les espaces de noms. L'exit criterion de la phase sera un rétablissement de la suite de test à 100% de succès.
