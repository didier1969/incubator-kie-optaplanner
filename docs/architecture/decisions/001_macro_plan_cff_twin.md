# ADR-001: Macro-Plan Vertical Ferroviaire (CFF/SBB)

**Statut :** Accepté
**Date :** 2026-03-21
**Contexte :** 
Pour valider la puissance et le passage à l'échelle du framework HexaPlanner, nous définissons un premier "Vertical de Référence" : modéliser, simuler et optimiser l'intégralité du réseau ferroviaire suisse (CFF/SBB) en temps réel. Ce cas d'usage sert de stress-test pour le moteur universel. Le système doit afficher le réseau sur une carte interactive (Deck.gl/Mapbox), simuler le trafic avec une horloge variable, et permettre l'injection de perturbations. Aucune simplification du réseau n'est tolérée pour garantir la validité du framework face à la complexité réelle.

**Décision :** 
Nous établissons un macro-plan spécifique à ce vertical, orienté données (Open Data GTFS & topologie physique). Ce plan valide les capacités d'ingestion massive et de calcul de graphes du moteur HexaPlanner.

## Macro-Plan Stratégique

### Époque 1 : Fondations Polyglottes (Validé)
- [x] Phase 1-6 : Scaffold Elixir OTP, Pont Rustler FFI, Pipeline Nix.
- [x] Phase 7 : Moteur de Score Incrémental (Rust `salsa`).

### Époque 2 : Ingestion de la Réalité Physique (Validé)
Le réseau complet ne tolère aucune approximation.
- [x] **Phase 8 (Pipeline Open Data) :** Intégration des flux GTFS CFF (Horaires, Lignes, Arrêts). Insertion massive via PostgreSQL unlogged tables.
- [x] **Phase 9 (Graphe Topologique Exact) :** Téléchargement automatisé des données GeoJSON (Liniennetz). Parsing des courbes géométriques complètes (zéro simplification rectiligne).
- [x] **Phase 10 (Ingestion Big Data) :** Mise en œuvre du pipeline `mix data.import`. Ingestion de 19,1 millions de temps d'arrêt, 1,19 million de trains et 215k transferts en moins de 10 minutes via résolution SQL-side (zéro consommation RAM Elixir).

### Époque 3 : Jumeau Numérique Temporel & Visuel (En Cours)
- [x] **Phase 11 (Visualisation & Dashboard) :** Création du Dashboard `TwinLive` supportant l'affichage en streaming (Phoenix Streams) de 1,19 million d'entités sans réduction de données.
- **Phase 12 (Assemblage du Graphe Rust) :** Fusion de la topologie physique (Rails) et temporelle (GTFS) dans `petgraph` via le pont Rustler.
- **Phase 13 (Tick Engine Distribué) :** Implémentation de l'horloge système (`GenServer`) interpolant les positions des trains en temps réel.

### Époque 4 : Chaos Engineering et Résolution (Rust)
- **Phase 14 (Interface de Perturbation & Deck.gl) :** UX permettant à l'opérateur de visualiser le flux et de sectionner une voie ou bloquer une gare.
- **Phase 15 (Rolling Stock Digital Twin) :** Intégration de l'API REST "SBB Train Formation". Liaison des `block_id` et `trip_id` pour modéliser les compositions de rames physiques (longueur, masse, couplage/découplage) et assurer la continuité nocturne des véhicules.
- **Phase 16 (Réaction du Solveur) :** Ruin & Recreate sur le graphe `salsa` pour maximiser la ponctualité globale et ré-assigner le matériel roulant.

**Conséquences :**
- **Techniques :** Nécessite l'intégration de PostGIS pour Elixir (Ecto) et de bibliothèques de graphes pointues (ex: `petgraph`) côté Rust pour la topologie.
- **Visuelles :** Interdiction d'utiliser des libs DOM (Leaflet de base) pour l'affichage, passage obligatoire à WebGL (Deck.gl/Mapbox).
- **Standards :** Maintien absolu de la norme "0 warning, 100% tests", car la complexité des graphes CFF fera s'effondrer toute base de code fragile.