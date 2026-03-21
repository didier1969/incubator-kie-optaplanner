# ADR-001: Macro-Plan Jumeau Numérique CFF (SBB)

**Statut :** Accepté
**Date :** 2026-03-21
**Contexte :** 
L'objectif ultime de HexaPlanner est défini : modéliser, simuler et optimiser l'intégralité du réseau ferroviaire suisse (CFF/SBB) en temps réel. Le système doit afficher le réseau sur une carte interactive (Deck.gl/Mapbox), simuler le trafic avec une horloge variable (Play/Pause/x100), et permettre l'injection de perturbations (panne de voie, retard) déclenchant le solveur Rust pour recalculer les plannings. Aucune simplification du réseau n'est tolérée (inclusion totale des S-Bahn, contraintes de voies uniques, tunnels, croisements).

**Décision :** 
Nous établissons un macro-plan orienté données (Open Data GTFS & topologie physique) divisé en grandes époques. Ce plan remplace l'approche bottom-up par une approche Top-Down ("North Star" CFF).

## Macro-Plan Stratégique

### Époque 1 : Fondations Polyglottes (Validé)
- [x] Phase 1-6 : Scaffold Elixir OTP, Pont Rustler FFI, Pipeline Nix.
- [x] Phase 7 : Moteur de Score Incrémental (Rust `salsa`).

### Époque 2 : Ingestion de la Réalité Physique (Topologie & GTFS)
Le réseau complet ne tolère aucune approximation.
- **Phase 8 (Pipeline Open Data) :** Intégration des flux GTFS CFF (Horaires, Lignes, Arrêts) via un worker Oban quotidien. Insertion dans PostgreSQL/PostGIS.
- **Phase 9 (Graphe Topologique Exact) :** Modélisation des contraintes d'infrastructure dans Rust. Création du graphe de voies (cantons, aiguillages, capacités des gares, signalisation de sécurité) pour empêcher deux trains de se superposer. Chargement de ce graphe énorme via Zero-Copy (FlatBuffers) en RAM.

### Époque 3 : Jumeau Numérique Temporel & Visuel
- **Phase 10 (Tick Engine Distribué) :** Implémentation d'une "Horloge Monde" en Elixir (`GenServer`). Chaque train devient un processus ou une entité mémoire qui interpole sa position physique selon l'heure simulée.
- **Phase 11 (Frontend WebGL) :** Intégration de Deck.gl dans Phoenix LiveView via les Hooks JS. Affichage fluide de plusieurs milliers de trains simultanés sur la carte topographique de la Suisse. Ajout de la "Time Machine" (Contrôleurs temporels).

### Époque 4 : Chaos Engineering et Résolution (Rust)
- **Phase 12 (Interface de Perturbation) :** UX permettant à l'opérateur de sectionner une voie, de fermer un tunnel (ex: Gothard), ou de bloquer une gare.
- **Phase 13 (Réaction du Solveur) :** Dès la perturbation, l'état est forké (What-If). Le moteur Rust (ALNS / Local Search) calcule la cascade de retards, recherche les voies de contournement possibles (Ruin & Recreate) et met à jour le graphe incrémental `salsa` pour maximiser la ponctualité globale (Score).

**Conséquences :**
- **Techniques :** Nécessite l'intégration de PostGIS pour Elixir (Ecto) et de bibliothèques de graphes pointues (ex: `petgraph`) côté Rust pour la topologie.
- **Visuelles :** Interdiction d'utiliser des libs DOM (Leaflet de base) pour l'affichage, passage obligatoire à WebGL (Deck.gl/Mapbox).
- **Standards :** Maintien absolu de la norme "0 warning, 100% tests", car la complexité des graphes CFF fera s'effondrer toute base de code fragile.