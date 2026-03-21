# Document d'Architecture : Control Plane et Orchestration HexaPlanner

**Auteur :** Architecte Principal(e) Elixir & Systèmes Distribués
**Date :** 21 Mars 2026
**Cible Technologique :** Elixir 1.18+, OTP 28, Rustler 0.35+

## 1. Vision et Principes Fondamentaux
En 2026, la plateforme HexaPlanner exploite pleinement les avancées d'Elixir 1.18 et OTP 28, notamment le système de typage graduel fort intégré au compilateur, l'optimisation extrême du JIT pour les messages inter-processus et les capacités natives de tracing distribué. Le système est modélisé comme un essaim d'acteurs indépendants, offrant une résilience absolue ("Let it crash") et une réactivité temps-réel exceptionnelle via Phoenix LiveView.

## 2. Architecture Multi-Processus et Arbre de Supervision (Actor Model)

Le cœur de l'orchestration repose sur des arbres de supervision dynamiques (`DynamicSupervisor`) combinés à des registres distribués (Horde ou :pg) pour router les messages vers les bons acteurs, quel que soit le nœud où ils résident.

```elixir
HexaPlanner.Application
├── HexaPlanner.PubSub (Phoenix.PubSub pour LiveView)
├── HexaPlanner.EventStore.Supervisor (Accès au log immuable)
├── HexaPlanner.ClusterSupervisor (Gestion de la topologie via libcluster)
└── HexaPlanner.Simulation.Supervisor
    ├── SimulationSession (GenServer - État global de la session utilisateur)
    │   ├── Scénario "Principal" (GenServer - Baseline)
    │   ├── Scénario "What-If A" (GenServer - Panne Machine 3)
    │   └── Scénario "What-If B" (GenServer - Commande Urgente)
```

**Isolation des Pannes et Robustesse :**
Chaque scénario ("What-If" ou principal) est encapsulé dans un `GenServer` dédié agissant comme proxy stateful. Si le solveur natif en Rust crashe (ex: erreur de segmentation, Out-Of-Memory, ou panic), seul l'acteur Elixir proxy est foudroyé. Le processus parent `SimulationSession` intercepte la sortie anormale (via `trap_exit` ou les moniteurs OTP) et notifie immédiatement l'interface LiveView de l'échec de la branche "What-If A", tout en gardant le reste du nœud et de l'application 100% opérationnels.

## 3. Event Sourcing, Time-Travel et State Forking

Fini l'état mutable écrasé dans une base CRUD. L'état du Job Shop ou du réseau ferroviaire est calculé par "pliage" (reduce) d'une séquence d'événements métier immuables.

**Schéma des Événements Métier :**
Les événements sont fortement typés et persistés dans le Commited Log.
```elixir
@type job_event ::
  %JobCreated{id: uuid(), priority: integer(), constraints: map()} |
  %MachineAllocated{job_id: uuid(), machine_id: uuid(), time_window: range()} |
  %DisruptionReported{type: :breakdown, machine_id: uuid(), duration: integer()}
```

**Time-Travel et Lazy State Cloning (Forking) :**
Pour "rembobiner" le temps, un scénario charge l'historique des événements depuis le store jusqu'à un instant `T`.
Lorsqu'un planificateur demande un fork ("What-If"), le `SimulationSession` clone l'état du scénario parent. En Elixir, grâce à l'immuabilité et au partage structurel de la mémoire de la BEAM, copier un état complexe de 2 Go vers un nouveau processus est quasi-instantané (O(1) pour la structure). À partir de ce point de divergence, le nouveau `GenServer` Scénario accumule ses propres événements (uncommitted) et lance son optimisation Rust sans jamais verrouiller ni muter le plan de production en cours d'exécution.

## 4. Intégration du Data Plane (Rust NIFs et Ports Distribués)

L'interfaçage avec les moteurs de calcul Rust doit garantir que les calculs massifs (CPU-bound) ne figent jamais la BEAM.

**Stratégie d'Invocation :**
- **Calculs Éclair (< 1ms) :** NIFs standard via `Rustler`.
- **Calculs Moyens / Heuristiques :** Utilisation des **Dirty NIFs** ou des "Yielding NIFs". Ces NIFs s'exécutent sur les "Dirty Schedulers" dédiés d'OTP 28, évitant la famine (starvation) des schedulers normaux et préservant la fluidité du Phoenix LiveView.
- **Solving Lourd et Dangereux :** Pour les heuristiques expérimentales ou les calculs prolongés intensifs en mémoire, le solveur Rust est démarré comme un processus OS séparé et communique avec Elixir via des **Ports** ou agit comme un **nœud Erlang distribué (C-Node/Rust Node)**. Si le solveur s'effondre (OOM Killer de l'OS), le descripteur de fichier du Port se ferme proprement, déclenchant le mécanisme d'isolation évoqué plus haut.

## 5. Clustering, Haute Disponibilité et Mitigation de Charge

Avec Elixir 1.18, le déploiement sur une architecture Cloud-Native distribuée est fluide.

**Distribution Horizontale (100+ Simulations) :**
Lors du lancement massif de scénarios :
1. **Routage :** Un routeur global (`Horde` ou algorithme consistant de hachage) reçoit la requête de "batch what-if".
2. **Dispatch :** L'orchestrateur évalue la télémétrie (`:os_mon`, métriques internes BEAM) et distribue dynamiquement l'instanciation des `GenServer` Scénarios vers les nœuds du cluster ayant le plus de CPU/RAM disponible via la distribution Erlang native.

**Protocoles de Communication :**
Tout transite via le bus natif Erlang Distribution Protocol (TCP/TLS) sérialisé en External Term Format (ETF), assurant une très faible latence et une haute compression.

**Mitigation de Charge (Backpressure & Circuit Breakers) :**
- **Backpressure via Broadway/GenStage :** L'ingestion des demandes d'optimisation est gérée par une pipeline demande-poussée (demand-driven). Si les solveurs Rust saturent, la demande remonte jusqu'à l'API ou l'UI, ralentissant naturellement l'acceptation de nouvelles requêtes sans noyer la mémoire du Control Plane.
- **Circuit Breakers :** Implémentation de coupe-circuits (ex: via des librairies comme `:fuse` ou `:regulator`) autour des appels RPC distribués. Si un nœud de solveur dégrade ses performances ou timeout de manière répétée, le circuit s'ouvre, le nœud est éjecté temporairement du pool de routage et des alertes OpenTelemetry sont levées pour déclencher l'auto-scaling du cluster de calcul.

## Conclusion
Le Control Plane en Elixir/OTP 28 sépare magistralement la résilience logicielle de l'exécution calculatoire (Rust). En embrassant l'Actor Model et l'Event Sourcing, le Jumeau Numérique permet une exploration simultanée massive des imprévus (What-If), propulsant les planifications industrielles et ferroviaires dans une nouvelle ère de réactivité continue et sécurisée.