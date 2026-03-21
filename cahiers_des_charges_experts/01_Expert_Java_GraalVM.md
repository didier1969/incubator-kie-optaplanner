# Mandat d'Architecture : Sous-système Moteur de Règles (Constraint Streams)

**À l'attention de :** Expert(e) Principal(e) Java, GraalVM & Recherche Opérationnelle  
**Date :** 21 Mars 2026  
**Référentiel Technologique :** État de l'art Février 2026 (Java 25 LTS, Project Panama, GraalVM Native Image)  
**Projet :** HexaPlanner - Jumeau Numérique pour Job Shop Scheduling et Optimisation Ferroviaire

## Contexte et Vision Stratégique
Nous reprenons la base open-source du moteur OptaPlanner (Constraint Streams) pour construire l'ultime système d'optimisation industrielle orienté "Just-In-Time" (pénalités d'avance/retard) et non plus simplement "Makespan". Le système monolithique Java actuel est inadapté à nos ambitions de simulation massivement parallèle dans le cloud.

Votre mission est de "décapiter" OptaPlanner : nous ne conserverons **que** sa capacité exceptionnelle à modéliser et calculer des scores de manière incrémentale (Constraint Streams). L'orchestration et la recherche heuristique seront déportées sur d'autres langages (Rust, Elixir).

## Ce que nous attendons de votre Cahier des Charges

Nous vous demandons de rédiger les spécifications techniques complètes pour la réalisation de ce "Data Plane de Score". Votre document devra impérativement traiter les points suivants :

1. **Extraction et Isolation du Cœur :** 
   - Comment isoler le composant `Constraint Streams` (et l'intégration Drools/Bavet sous-jacente) de la boucle de recherche heuristique (Local Search, Construction Heuristics) qui sera obsolète ?
   - Conception d'un modèle de données immuable adapté à l'Event Sourcing.

2. **Compilation Ahead-of-Time (AOT) :**
   - Stratégie d'utilisation de GraalVM Native Image (standards Février 2026) pour compiler ce moteur de règles en un binaire statique lourdement optimisé.
   - Objectif : Temps de démarrage sous les 20ms, empreinte RAM divisée par 10 par rapport à la JVM classique.

3. **Interopérabilité Native (Zero-Copy) :**
   - Conception de l'interface FFI (Foreign Function Interface) utilisant le Project Panama (Foreign Function & Memory API) de Java 25.
   - Le moteur Java doit pouvoir recevoir un état mémoire modifié par le solveur Rust en un minimum de cycles d'horloge (zéro sérialisation JSON/Protobuf, utilisation de mémoire partagée hors-tas / off-heap).

4. **Modélisation du Just-In-Time et Setup Times :**
   - Comment structurer les variables "Shadow" et les flux de contraintes pour gérer efficacement les temps de mise en route dépendant de la séquence (Sequence-dependent setup times) sans saturer l'arbre d'évaluation.

**Livrable attendu :** Un document d'architecture technique (DAT) détaillant les structures de données, l'API C-FFI exposée, les scripts de build GraalVM et les stratégies d'optimisation de la mémoire.