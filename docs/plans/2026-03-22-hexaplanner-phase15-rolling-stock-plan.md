# Phase 15: Rolling Stock Digital Twin (Fidélité Matérielle)

## Objectif (Le Mandat de Maestria)
Le Jumeau Numérique STIG (Spatio-Temporal Interval Graph) gère actuellement l'espace (Rails) et le temps (Horaires) avec une précision absolue. La **Phase 15** introduit la troisième dimension de la réalité ferroviaire : le **Matériel (Rolling Stock)**. 

Les trains ne sont plus de simples "identifiants GTFS" flottants. Ils deviennent des compositions physiques (locomotives, voitures, rames automotrices) soumises aux lois de la maintenance, de la capacité d'emport, et de la continuité opérationnelle (Umlauf/Rostering).

## Contexte et Source de Données
*   **La Limite GTFS :** Le standard GTFS définit des trajets commerciaux (`trip_id`), mais ignore la structure matérielle (ce qu'il y a physiquement sur les rails). Le `block_id` GTFS permet de lier des trajets, mais ne donne ni la masse ni la longueur.
*   **La Source de Vérité (CFF/SBB) :** L'Open Data Platform Mobility Switzerland expose l'API REST **Train Formation (v2)** (`api.opentransportdata.swiss/formation/v2/`). Cette API fournit la composition exacte de chaque train commercial (ex: 2 rames Stadler FLIRT Evo couplées, ou 1 Re 460 + 8 voitures IC2000).

## Plan d'Architecture (Époque 4)

### 1. Ingestion du Registre des Véhicules (Vehicle Registry)
*   **Modélisation Ecto (Elixir) :** Création des schémas `Vehicle` (Rame ou Locomotive), `Composition` (Assemblage de véhicules) et `VehicleJourney` (Lien entre une Composition et un `trip_id`).
*   **Synchronisation API :** Un processus (Worker Oban) interrogera l'API SBB Train Formation en tâche de fond pour rapatrier les compositions des 1,19 million de Trips de la base.
*   **Paramètres Physiques :** Chaque `Vehicle` possédera une `masse` (tonnes), une `longueur` (mètres), et un `profil_de_freinage` (décélération $m/s^2$).

### 2. Continuité Nocturne et Rostering (L'Anti-Téléportation)
*   **Chaînage des Blocks (`block_id`) :** Dans Rust, les `Trips` partageant le même `block_id` seront liés temporellement. 
*   **Gares de Garage (Parking) :** L'intervalle de temps entre le dernier Trip d'un `block_id` le soir (ex: 23h45) et le premier Trip du lendemain (ex: 06h15) générera automatiquement un **EOS (Elementary Occupation Segment) Statique** sur une voie de garage de la gare d'arrivée. Le train ne "disparaît" plus : il occupe physiquement le quai toute la nuit.

### 3. Manœuvres Physiques : Couplage et Découplage
*   **Détection :** Si l'API indique qu'un Trip A (composé de 2 rames) arrive à Bienne, et se sépare en Trip B (1 rame) et Trip C (1 rame), le moteur doit modéliser la scission.
*   **Réservation de Quai :** L'action de couplage/découplage ajoutera une durée d'occupation spécifique sur le nœud du graphe (ex: +10 minutes d'immobilisation de la voie pour les agents de manœuvre) avant que les trains ne puissent repartir.

### 4. Injection dans le Moteur Balistique (Rust Data Plane)
*   Les paramètres physiques de la `Composition` (longueur totale, masse totale) seront injectés dans le constructeur de l'EOS dans `topology.rs`.
*   Le "Headway" (distance de freinage) et le "Tail Clearance" (longueur physique occupant les cantons précédents) ne seront plus des constantes (`120s` / `20s`) mais seront calculés dynamiquement par le moteur Newtonien (Phase 12H) en fonction de la rame exacte affectée au train.

## Conséquences pour le Solveur (Salsa)
Le moteur d'optimisation `salsa` ne se contentera plus de modifier l'heure de départ pour éviter une collision. S'il ne peut pas décaler un train, il aura la capacité (en Phase 16) d'**échanger le matériel roulant** (Swap), à condition que la rame de remplacement soit physiquement présente dans la gare et possède une capacité d'emport suffisante.

## Critères d'Acceptation de la Phase 15
- [ ] Le schéma de base de données modélise les rames (UIC) et les compositions.
- [ ] Le worker Elixir consomme l'API SBB Train Formation avec succès.
- [ ] Les trains liés par un `block_id` génèrent une occupation continue sur les quais pendant la nuit.
- [ ] La longueur de la rame dicte l'enveloppe de collision spatiale dans Rust.