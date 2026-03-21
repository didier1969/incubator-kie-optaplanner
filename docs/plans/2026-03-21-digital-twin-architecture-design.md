# Design Document: Jumeau Numérique Industriel (HexaPlanner)

**Date:** 2026-03-21
**Auteur:** Nexus Lead Architect
**Sujet:** Architecture Pure Elixir/Rust pour Planification Ferroviaire et JIT Manufacturing

## 1. Architecture Globale et Composants

L'architecture est structurée en deux plans distincts afin d'isoler l'orchestration asynchrone des calculs d'optimisation intensifs :

*   **Le "Control Plane" (Elixir / BEAM) :** Gère les connexions temps réel (WebSockets via Phoenix LiveView), ingère les flux d'événements IoT, la logique de distribution (Clustering/Horde) et gère l'état de chaque entité via le modèle d'Acteurs immutables.
*   **Le "Data Plane" (Rust Pur) :** Moteur d'optimisation *bare-metal* intégral. Gère à la fois le "Incremental Score Calculation" (Constraint Streams compilés) et les métaheuristiques de recherche (Local Search, Algorithmes Génétiques) de manière autonome. Zéro machine virtuelle externe, zéro Garbage Collector.
*   **Le Pont d'Intégration (Rustler NIFs) :** Connecte la VM BEAM aux bibliothèques Rust en mémoire partagée. Utilise l'Erlang Term Format (ETF) pour les commandes courantes, et **FlatBuffers** (Zero-Copy) pour le chargement initial des matrices topologiques massives.

## 2. Flux de Données (Data Flow)

Le système supporte à la fois le *Continuous Planning* et l'exécution asynchrone de scénarios *What-If* :

*   **Continuous Planning :** Elixir ingère les événements IoT. En cas d'écart (ex: retard ferroviaire), un ordre de re-planification prioritaire est envoyé à Rust via Rustler. Le nouveau plan est calculé et rediffusé instantanément par Elixir aux opérateurs (LiveView).
*   **Simulations What-If :** L'utilisateur demande une simulation ("Qu'est-ce qui se passe si..."). Elixir crée une copie (Fork) de l'état actuel en O(1) grâce à l'immutabilité Erlang, et instancie un nouvel Acteur dédié. Ce processus contacte son propre NIF Rust sur un cœur CPU séparé, garantissant que la simulation lourde ne bloque jamais la gestion de la production réelle.

## 3. Gestion des Erreurs et Résilience

Le principe de "Let it Crash" d'Erlang est appliqué de manière stricte :

*   **Isolement par Acteur :** Une erreur de logique métier dans une simulation #X entraîne la mort du processus #X uniquement. Le Superviseur enregistre l'erreur, le reste du système (et de l'usine) continue de fonctionner.
*   **Quarantaine FFI (Rust) :** Le code Rust doit être 100% "Safe Rust". Les paniques Rust éventuelles sont interceptées par `catch_unwind` via Rustler et transformées en exceptions Erlang, empêchant formellement un crash complet de la VM (Segfault mitigation).
*   **Backpressure IoT :** Elixir applique des coupe-circuits et du délestage (Load Shedding) en cas d'inondation de messages IoT pour protéger la bande passante du solveur.

## 4. Stratégie de Test et Validation (TDD Strict)

Une pyramide de tests hiérarchique est obligatoire avant toute écriture de code :

1.  **Tests Unitaires Bas Niveau (Data Plane) :** `cargo test` (Rust) pour vérifier la stricte exactitude mathématique du solveur (calcul de scores, algorithmes de recherche) de manière isolée.
2.  **Tests d'Intégration du Pont (Bridge) :** Validation via `ExUnit` de la sérialisation ETF/FlatBuffers entre Elixir et Rust. Traque des erreurs de typage et des fuites de mémoire potentielles au niveau du FFI.
3.  **Tests End-to-End (Control Plane) :** Clusters de tests `ExUnit` exécutant des dizaines de simulations concurrentes. Injection de pannes (Chaos Monkey) pour valider l'isolation et la survie de la VM BEAM globale face à la destruction d'acteurs individuels.

## 5. Modélisation et Contraintes (Le DSL)

La définition des règles métiers (Constraint Streams) utilise une approche de **Métaprogrammation Elixir vers Rust** :

*   **Le DSL "Fluide" (Elixir) :** Les experts métiers et développeurs Elixir utilisent des macros (ex: `defconstraint`, `match`, `penalize`) fortement inspirées du Pattern Matching relationnel pour déclarer les règles de manière lisible.
*   **La Transpilation vers Rust (AOT) :** Avant l'exécution, ces macros transforment le DSL Elixir en un arbre syntaxique (AST) représentant des "Flux Fonctionnels Purs" (filtres, itérateurs, map-reduce). Ce flux est compilé en code Rust natif.

## 6. Interface Utilisateur (UI) du Jumeau Numérique

Le rendu graphique utilise une **Architecture Hybride "Isomorphique"** (LiveView + WebComponents/Canvas) :

*   **L'Orchestration (Phoenix LiveView) :** L'ensemble de l'application (menus, gestion de l'état, formulaires, authentification) est rendu côté serveur (SSR). L'état est 100% synchronisé avec les Acteurs BEAM.
*   **Les Composants Haute-Densité (Canvas via SwarmEx-viz) :** Pour les visualisations extrêmes (diagrammes de Gantt massifs, cartes ferroviaires), l'interface utilise des Custom Elements (WebComponents) en JavaScript/Canvas intégrés dans le sous-projet **SwarmEx-viz**. 

## 7. Distribution et Scalabilité (Le Modèle "Trust / Supply Chain")

L'architecture contourne la limite physique du CPU (ex: maximum 16 calculs lourds continus sur 16 cœurs) via le clustering natif d'Erlang :

*   **Cluster Peer-to-Peer :** Plusieurs instances (nœuds) du Control Plane Elixir sont reliées pour former un réseau maillé unique.
*   **Gouvernance Décentralisée (Horde/Swarm) :** Il n'y a pas de "Leader" central. Les processus métiers sont distribués dynamiquement via du hachage constant. 
*   **Files d'Attente Globales (Oban) :** Si les demandes d'optimisation dépassent les cœurs Rust disponibles, Elixir place les calculs dans des files d'attente distribuées robustes (Oban).

## 8. Principe Fondamental : Réutilisation de l'Écosystème (DRY)

Conformément à la directive d'ingénierie, **aucune roue ne sera réinventée** :
*   **Écosystème Elixir :** Utilisation de `Horde`/`Swarm` (clustering), `Oban` (queues), `Broadway` (Kafka/RabbitMQ IoT).
*   **Écosystème Rust :** Utilisation de `rayon` (parallélisme), `crossbeam` (concurrence), et des bibliothèques d'optimisation de pointe pour éviter de réécrire les algorithmes bas niveau : `localsearch` (pour Tabu Search et Recuit Simulé ultra-performants via Rayon) et `metaheuristics-nature` (pour les Algorithmes Génétiques).

## 9. Expérience Développeur (DevEx) et Stratégie de Compilation

Pour garantir des cycles d'itération inférieurs à 3 secondes :
1.  **Environnement Reproductible (Nix) :** L'outillage est strictement géré via `nix develop`.
2.  **Compilation Incrémentale Rust :** Le build Rust est géré par `Rustler` depuis Elixir. En mode `dev`, `cargo` n'effectue qu'une compilation incrémentale rapide (1-4s).
3.  **Hot-Reload Elixir :** Le travail quotidien (DSL métier, UI LiveView) bénéficie du hot-reload quasi-instantané (< 1s) de la VM BEAM.

## 10. Remplacement Stratégique d'OptaPlanner (La Migration de Valeur)

Le projet remplace intégralement l'écosystème Java/OptaPlanner en réimplémentant ses fonctionnalités clés de manière plus performante via le duo Elixir/Rust :

*   **Clonage de l'état en mémoire ("Planning Clone") :** Le clonage Java par réflexion, coûteux en CPU, est remplacé par l'**Immutabilité des structures de données Erlang/Elixir**, permettant un clonage à coût nul (O(1) en temps et en mémoire via le partage structurel).
*   **Benchmarker et Statistiques :** Le générateur de rapports XML/HTML statiques est remplacé par un **Benchmarker Temps-Réel (Phoenix LiveView)**. Elixir orchestre plusieurs processus Rust isolés exécutant différents algorithmes simultanément, et diffuse les courbes de convergence en direct via WebSockets vers le client.
*   **Moteur de Recherche (Heuristiques) :** Les algorithmes de "Local Search" (Tabu Search, Simulated Annealing) sont basculés en pur Rust, bénéficiant d'une exécution "bare-metal" sans pause de Garbage Collector, via des `crates` d'optimisation communautaires éprouvées (`localsearch` pour le local search parallèle, `metaheuristics-nature` pour le génétique).
*   **Incremental Score Calculation (Calcul de Score Incrémental) :** La transpilation du DSL Elixir génère un graphe de dépendances en Rust (similaire à `salsa`) qui garantit que seuls les deltas ("ce qui a changé dans le réseau") sont recalculés, évitant la charge mémoire de l'ancien moteur Drools.

## 11. Optimisation Multi-Étapes (Multi-Stage) et Algorithmes Génétiques

Pour répondre aux problèmes de très grande échelle ("Supply Chain Trust"), le moteur Rust intègre l'état de l'art de l'optimisation :

*   **Approche Multi-Stage :** Le solveur est architecturé pour enchaîner des phases distinctes (Construction Heuristics $\rightarrow$ Local Search $\rightarrow$ Perturbation $\rightarrow$ Deep Optimization). La coordination entre ces étapes est orchestrée par Elixir qui peut suspendre, inspecter et rediriger l'état du solveur Rust à tout moment.
*   **Algorithmes Génétiques (GA) & Évolutionnistes :** Pour échapper aux minima locaux dans des topologies complexes, le "Data Plane" Rust implémente des approches de croisement génétique (Crossover/Mutation) sur des populations de solutions ("Island Model"). Elixir gère la migration des individus (les meilleures solutions partielles) entre les différents cœurs CPU et nœuds du cluster.