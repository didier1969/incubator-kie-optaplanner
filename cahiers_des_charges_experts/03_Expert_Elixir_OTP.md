# Mandat d'Architecture : Sous-système Control Plane et Orchestration

**À l'attention de :** Architecte Principal(e) Elixir, Erlang/OTP et Systèmes Distribués  
**Date :** 21 Mars 2026  
**Référentiel Technologique :** État de l'art Février 2026 (Elixir 1.19.5, OTP 28, Actor Model, Event Sourcing)  
**Projet :** HexaRail - Jumeau Numérique pour Job Shop Scheduling et Optimisation Ferroviaire

## Contexte et Vision Stratégique
Le moteur industriel moderne n'est pas un script batch exécuté la nuit : c'est un Jumeau Numérique interactif. Les planificateurs (chemins de fer, usines lourdes) ont besoin de faire du "Continuous Planning" et de générer simultanément des dizaines de scénarios "What-If" (Pannes, retards, commandes urgentes) sans compromettre la stabilité du système principal.

Le modèle monolithique n'est plus viable. Votre mission est de concevoir le "Control Plane" global de l'application en utilisant la machine virtuelle BEAM (Elixir/OTP), reconnue comme l'état de l'art absolu pour la tolérance aux pannes et la concurrence massive.

## Ce que nous attendons de votre Cahier des Charges

Nous vous demandons de produire le cahier des charges détaillé de la couche d'orchestration :

1. **Architecture Multi-Processus (Actor Model) :**
   - Spécification de l'arbre de supervision OTP. Chaque simulation "What-If" ou session utilisateur doit être encapsulée dans un processus léger isolé (GenServer). Un crash du solveur natif (Rust) ne doit faire crasher que la simulation concernée, jamais le nœud Elixir.

2. **Event Sourcing et Time-Travel :**
   - Remplacement de la base de données CRUD classique par un modèle orienté événements (Event Sourcing).
   - Conception d'un mécanisme permettant de "rembobiner" l'état du Job Shop à n'importe quel moment du passé et de "forker" le planning pour explorer une branche alternative (mécanisme de clonage d'état paresseux).

3. **Intégration du Data Plane (Rust NIFs) :**
   - Stratégie d'invocation asynchrone des moteurs de calcul Rust. Utilisation de `Rustler` et des *Dirty NIFs* ou de ports/nœuds distribués pour garantir que le calcul lourd ne fige jamais la réactivité temps-réel de l'UI (Phoenix LiveView).

4. **Clustering et Haute Disponibilité :**
   - Conception de la distribution du travail. Si 100 simulations sont demandées, comment l'orchestrateur Elixir répartit-il dynamiquement ces charges sur un cluster cloud de multiples nœuds de calcul (Distribution Erlang).

**Livrable attendu :** Un document d'architecture détaillant la hiérarchie de supervision (Supervision Trees), le schéma des événements métier, les protocoles de communication inter-nœuds, et les stratégies de mitigation de charge (Backpressure / Circuit Breakers).