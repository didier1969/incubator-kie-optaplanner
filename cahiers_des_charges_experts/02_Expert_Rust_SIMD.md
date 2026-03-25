# Mandat d'Architecture : Sous-système Moteur de Recherche et Heuristiques

**À l'attention de :** Expert(e) Principal(e) Rust, Calcul Haute Performance (SIMD) et Programmation par Contraintes (CP)  
**Date :** 21 Mars 2026  
**Référentiel Technologique :** État de l'art Février 2026 (Rust Édition 2024, std::simd, C-FFI, CP-SAT)  
**Projet :** HexaRail - Jumeau Numérique pour Job Shop Scheduling et Optimisation Ferroviaire

## Contexte et Vision Stratégique
Le système de recherche locale natif d'OptaPlanner s'effondre face aux problèmes de type Job Shop Scheduling (JSSP) complexes, notamment ceux incluant des temps de préparation liés à la séquence (Setup times) et des dépendances strictes en cascade. Un simple mouvement aléatoire invalide l'ensemble du planning.

Votre mission est de concevoir le nouveau "cerveau algorithmique" du système. Il sera développé intégralement en Rust pour garantir des performances "bare-metal", une absence totale de Garbage Collection lors de la recherche, et une vectorisation extrême.

## Ce que nous attendons de votre Cahier des Charges

Nous vous demandons de rédiger un cahier des charges technique strict couvrant la conception de ce moteur hybride :

1. **Architecture Hybride (ALNS + CP) :**
   - Spécification d'un moteur de type Adaptive Large Neighborhood Search (Ruin & Recreate).
   - Intégration en C++ FFI (via `cxx` ou bindgen) d'un solveur SAT/CP (ex: Google OR-Tools CP-SAT) pour générer des sous-séquences topologiques valides instantanément lors de la phase de "Recreate".

2. **Accélération SIMD :**
   - Stratégie d'utilisation de `std::simd` (ou instructions AVX-512 / ARM NEON) pour vectoriser l'évaluation des graphes de dépendances temporelles. Le but est d'évaluer la validité de 32 ou 64 mouvements potentiels en un seul cycle CPU.

3. **Interopérabilité (Le Pont Java - Rust - Elixir) :**
   - **Vers Java :** Spécification de la communication via mémoire partagée avec le moteur de score Java/GraalVM (Project Panama).
   - **Vers Elixir :** Conception des NIFs (Native Implemented Functions) sécurisées via Rustler pour exposer le contrôle de la recherche à l'orchestrateur Erlang/OTP sans jamais bloquer les schedulers BEAM.

4. **Gestion de l'Arbre de Recherche :**
   - Structures de données en Rust optimisées pour le cache du processeur (Cache-locality, ECS - Entity Component System, ou Arènes de données) pour représenter les milliers de tâches et de machines.

**Livrable attendu :** Un design document incluant les diagrammes de flux d'exécution, la conception mémoire (Memory Layout), les signatures des traits Rust pour l'ALNS, et l'architecture d'intégration CP-SAT.