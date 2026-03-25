# Mapping OptaPlanner vers HexaRail (Elixir + Rust)

Ce document établit la correspondance stricte et exhaustive entre les fonctionnalités historiques du framework Java OptaPlanner (Timefold) et notre nouvelle architecture "HexaRail" basée sur Elixir et Rust. 

L'objectif est de démontrer comment chaque concept est non seulement remplacé, mais amélioré en termes de performance (zéro Garbage Collector, SIMD) et d'élasticité (modèle d'acteurs).

---

## 1. Modélisation du Domaine (Domain Modeling)

| Concept OptaPlanner (Java) | Équivalent HexaRail (Rust/Elixir) | Bibliothèques / Techniques |
| :--- | :--- | :--- |
| `@PlanningEntity` & `@PlanningVariable` | Structures de données en **Rust** (Data-Oriented Design) | Utilisation de `Structs` Rust avec des index au lieu de pointeurs. Gestion via des allocateurs d'arène (ex: crate `bumpalo` ou `typed-arena`) pour éviter toute pause de Garbage Collection. |
| `@ProblemFact` | État immuable en Rust | Les faits du problème sont chargés une fois via le pont FFI (Rustler) et stockés en lecture seule dans la mémoire Rust. |
| **Shadow Variables** (Custom, Inverse Relation, Anchor) | Graphe de dépendances réactif | En Rust, au lieu de listeners Java lourds, les variables d'ombre sont mises à jour soit manuellement via des *Move* dédiés, soit automatiquement recalculées via des requêtes mémorisées (crates `salsa` ou `qbice`). |
| **ValueRangeProvider** | Générateurs de domaines (Rust) | Fonctions itératrices (`Iterator`) en Rust générant les valeurs possibles à la volée. |

---

## 2. Calcul du Score (Score Calculation)

C'est ici qu'OptaPlanner tirait historiquement sa force (Drools, Bavet). L'architecture "Zero-Erasure" de Rust permet de faire mieux grâce à la monomorphisation (dispatch statique).

| Concept OptaPlanner (Java) | Équivalent HexaRail (Rust/Elixir) | Bibliothèques / Techniques |
| :--- | :--- | :--- |
| **Constraint Streams API** | **DSL Fluide Elixir** (Macros) | Création de macros Elixir (`defconstraint`, `penalize`) qui offrent la même lisibilité métier que l'API Java pour les experts. |
| **Bavet / Drools (Incremental Score)** | **Incremental Computation Engine (Rust)** | L'AST généré par Elixir est transpilé en flux d'itérateurs Rust. Pour le calcul du *Delta* (ne recalculer que ce qui change), nous utilisons les principes de la crate **`salsa`** (pull-based queries) ou **`qbice`** / **`incremental`**. Les calculs complexes (jointures, groupements) sont parallélisés via **`rayon`**. |
| **Easy/Simple Score Calculator** | Fonction Rust pure | Une simple fonction `fn evaluate(state: &State) -> Score` en Rust. Infiniment plus rapide qu'en Java car exécutable sans overhead et potentiellement vectorisée (SIMD via `std::simd`). |
| **Score Levels** (Hard/Soft/Medium) | Triples ou N-uplets Rust | Types personnalisés (ex: `struct Score(i32, i32, i32)`) implémentant le trait `Ord` pour la comparaison lexicographique. (Supporté nativement par `RapidSolve`). |

---

## 3. Algorithmes d'Optimisation (Optimization Algorithms)

L'écosystème Rust possède des crates de recherche opérationnelle de classe mondiale, souvent plus performantes que celles de la JVM grâce au contrôle de la mémoire.

| Concept OptaPlanner (Java) | Équivalent HexaRail (Rust/Elixir) | Bibliothèques / Techniques |
| :--- | :--- | :--- |
| **Local Search** (Hill Climbing, Tabu Search, Simulated Annealing, Late Acceptance) | Métaheuristiques Rust | La crate **`localsearch`** (hautement parallélisée) ou **`RapidSolve`**. Pour les problèmes de routage (VRP), les crates **`vrp-core`** et **`u-routing`** offrent l'état de l'art (ALNS - Adaptive Large Neighborhood Search). |
| **Construction Heuristics** (First Fit Decreasing, etc.) | Implémentations natives Rust | Heuristiques gloutonnes (Greedy) implémentées directement en Rust. |
| **Exhaustive Search / Branch & Bound** | Solvers Linéaires / CP (FFI) | Pour les sous-problèmes exacts, utilisation de **`good_lp`** (qui interface **HiGHS**, le meilleur solveur MILP open source) ou de la crate **`rust-constraint`** / **`cspsolver`**. |
| **Partitioned Search** | Clustering Elixir / OTP | Le découpage du problème n'est plus fait par des threads locaux, mais distribué via l'orchestrateur **Elixir (Horde/Oban)** sur plusieurs machines ou processus OS distincts. |

---

## 4. Fonctionnalités Avancées (Advanced Features)

| Concept OptaPlanner (Java) | Équivalent HexaRail (Rust/Elixir) | Bibliothèques / Techniques |
| :--- | :--- | :--- |
| **Continuous Planning / Windowing** | NIF Mutable (Rustler) | Maintien de l'état Rust en mémoire ("Dirty NIF" ou processus OS lié). Elixir envoie un message pour "glisser la fenêtre" (décaler le temps), le moteur Rust libère la mémoire ancienne et continue. |
| **Real-time Planning** (Problem Fact Changes) | Actor Model Message Passing | Le `GenServer` Elixir reçoit un événement temps-réel (ex: "Machine en panne"). Il suspend le NIF Rust via un `AtomicBool` partagé, injecte le delta, et relance la recherche. Beaucoup plus robuste que les `ProblemFactChange` de Java. |
| **Overconstrained Planning** | Nullable Variables / Penalties | Variables définies comme `Option<Resource>` en Rust. Si `None`, application d'une pénalité via le moteur de score. |
| **Benchmarker** | **LiveView + Ecto (Elixir)** | Le module statique de rapports HTML/XML d'OptaPlanner est remplacé par un tableau de bord interactif en **Phoenix LiveView** qui trace les courbes de convergence en temps réel, stockant l'historique dans PostgreSQL via **Ecto**. |

---

## 5. Architecture d'Entreprise et Orchestration

La transition de Java (Spring/Quarkus) vers Elixir (OTP) est le changement de paradigme le plus massif, offrant une résilience (Let it crash) introuvable sur la JVM.

| Concept OptaPlanner (Java) | Équivalent HexaRail (Rust/Elixir) | Bibliothèques / Techniques |
| :--- | :--- | :--- |
| **SolverManager** (Thread Pool) | **Oban + GenServer** | Au lieu d'un pool de threads en RAM (qui se perd si le serveur crashe), **Oban** gère les files d'attente d'optimisation persistées dans Postgres. Chaque résolution est un **`GenServer`** (processus léger) : l'échec de l'un n'impacte pas les autres. |
| **Quarkus / Spring Boot Integration** | **Phoenix Framework** | API REST/GraphQL et WebSockets gérés par **Phoenix**. Temps de réponse sous la milliseconde. |
| **Clustering distibué** | **Horde / Erlang Distribution** | Sans avoir besoin de Kafka, ZooKeeper ou Redis, la VM Erlang connecte les nœuds nativement. **Horde** assure qu'un problème n'est résolu que par un seul serveur dans le cluster mondial. |
| **JSON / XML Serialization** | **Zero-Copy / JSON NIFs** | La sérialisation Jackson/XStream est supprimée du hot path. Le dialogue Rust <-> Elixir se fait via `Rustler` (Termes BEAM). Pour les API Web, utilisation de la crate **`jason`** (Elixir) ou **`serde_json`** (Rust). |

---

## Conclusion
Le duo **Elixir + Rust** ne se contente pas de couvrir le spectre complet d'OptaPlanner ; il en élimine structurellement les plus gros défauts (pauses GC, complexité du multithreading, orchestration fragile). La mort de Java/GraalVM dans notre architecture est pleinement justifiée par la maturité des bibliothèques d'optimisation et de calcul incrémental de l'écosystème Rust en 2026.