# Manuel Opératoire Agile & Stratégie de Delivery : HexaPlanner

**De :** Senior Agile Delivery Manager / Expert(e) Agile
**Date :** 21 Mars 2026
**Projet :** HexaPlanner - Jumeau Numérique Industriel

Ce manuel opératoire définit le framework de livraison à l'échelle pour le projet HexaPlanner. Il adresse spécifiquement la complexité liée à la diversité des cycles d'ingénierie (IA, Rust, , Elixir) en s'appuyant sur des principes pragmatiques de flux de valeur, de gestion des dépendances par contrats, et de pilotage par la donnée.

---

## 1. Synchronisation des Cycles Disparates (Dual-Track Agile & Asynchronisme)

Faire cohabiter la recherche IA (cycles longs, forte incertitude) et le développement Produit/Web (cycles courts, itératifs) nécessite de briser la synchronisation temporelle stricte au profit d'une **synchronisation par la valeur et les interfaces**.

### 1.1. Le modèle Dual-Track étendu
Nous appliquons un modèle où les flux de découverte/recherche et de livraison/intégration sont désynchronisés mais alignés sur des objectifs communs (PI Planning ou OKRs trimestriels).

*   **Track IA/Recherche (Spikes & Modèles) :** Fonctionne en Kanban ou en sprints à durée variable. L'objectif n'est pas de livrer une feature "Done" toutes les deux semaines, mais de valider des hypothèses, d'entraîner des modèles et de fournir des artefacts versionnés (modèles RL, heuristiques).
*   **Track Ingénierie/Produit (Rust, , Elixir) :** Fonctionne en Scrum ou Kanban avec une cadence stricte (ex: sprints de 2 semaines) axée sur l'intégration continue et la livraison de valeur métier aux utilisateurs.

### 1.2. Mécanisme de découplage : L'approche "Shadowing" et Versioning
*   L'équipe Produit n'attend jamais l'équipe IA. Elle intègre systématiquement la **dernière version stable et packagée** d'un modèle IA.
*   Lorsque l'équipe IA travaille sur la version N+1 du modèle RL, l'équipe Produit développe le dashboard et les intégrations autour de la version N.
*   Une fois la version N+1 validée expérimentalement (Track IA), elle est versée dans le backlog du Track Produit pour être intégrée lors d'un sprint ultérieur (Shadowing : on teste d'abord les performances du nouveau modèle en parallèle avant de basculer en production).

### 1.3. Rituel d'alignement inter-domaines : Le "Sync & Demo"
*   **Cadence :** Hebdomadaire (max 45 min).
*   **Participants :** Tech Leads (IA, Rust, , Elixir), Product Manager, Delivery Manager.
*   **Objectif :** Non pas faire un daily de l'avancement détaillé, mais démontrer la valeur (même partielle), partager les découvertes IA de la semaine, et ajuster les priorités d'intégration de la semaine suivante.

---

## 2. Gestion des Dépendances Inter-équipes (Contract-Driven Development)

La chaîne de dépendance stricte (Elixir -> Rust -> ) est le pire ennemi de l'agilité. Elle crée des goulots d'étranglement ("bottlenecks"). La stratégie repose sur l'**API-First** et le **Contract-Driven Development (CDD)**.

### 2.1. Définition et gel des contrats (Interfaces)
Avant même d'écrire la moindre ligne de code métier ou d'algorithme, les équipes doivent se mettre d'accord sur les contrats d'interface.
*   **Interface Elixir <-> Rust :** Définie via des schémas stricts (ex: Protobuf, GraphQL ou OpenAPI si HTTP, FFI/NIF si intégré).
*   **Interface Rust <->  (Score) :** Contrat défini via des schémas d'échange de données (mémoire partagée, /FFI, ou IPC via gRPC/Arrow).

### 2.2. Bouchonnage systématique (Stubs & Mocks intelligibles)
Dès que le contrat est validé, chaque équipe reçoit (ou génère) un **Stub** (bouchon) de la dépendance.
*   **Pour l'équipe Elixir :** Un service Mock du moteur Rust qui renvoie des réponses statiques ou générées aléatoirement (mais valides selon le contrat) en quelques millisecondes. Cela permet de développer toute l'UI et les tests end-to-end sans le vrai moteur.
*   **Pour l'équipe Rust :** Un Mock du moteur de calcul de score , capable de renvoyer des scores déterministes basés sur des inputs prédéfinis, permettant à Rust de valider son arbre de recherche indépendamment.

### 2.3. Consumer-Driven Contracts (CDC)
Pour garantir que les contrats évoluent de manière sécurisée sans casser la chaîne :
*   Les équipes consommatrices (Elixir, Rust) écrivent des tests d'intégration automatisés définissant leurs attentes vis-à-vis des fournisseurs (Rust, ).
*   Ces tests (ex: via *Pact*) sont exécutés dans la CI/CD des équipes fournisseuses. Si l'équipe  modifie son moteur de score et casse le test fourni par l'équipe Rust, le build  échoue immédiatement (Shift-Left testing).

---

## 3. Pilotage de la Performance et Indicateurs (DORA Metrics & Flux)

Pour éviter que le projet ne s'enlise dans la "tour d'ivoire" technique (sur-optimisation Rust, recherche IA infinie) au détriment de la valeur métier, nous piloterons le delivery par la donnée.

### 3.1. DORA Metrics (L'excellence opérationnelle)
Ces métriques standards de l'industrie mesurent la capacité de l'ingénierie à livrer vite et de manière fiable :
1.  **Deployment Frequency (Fréquence de déploiement) :** Combien de fois le code est-il déployé en production (ou dans un environnement de staging intégré) ? *Cible : Plusieurs fois par jour/semaine.* Cela force des petits lots de travail (Small Batches) transversaux.
2.  **Lead Time for Changes (Délai de mise en œuvre) :** Temps entre le commit d'une ligne de code (Rust, , Elixir) et son déploiement effectif. *Cible : < 24 heures.* Cela mesure l'efficacité de la CI/CD et des tests automatisés.
3.  **Time to Restore Service (Temps moyen de restauration) :** Temps nécessaire pour corriger une anomalie en production.
4.  **Change Failure Rate (Taux d'échec des changements) :** Pourcentage de déploiements provoquant une régression (bugs, plantages).

### 3.2. Flow Metrics (Prévisibilité et Valeur)
Au-delà de la CI/CD, nous devons mesurer l'écoulement de la valeur à travers les différentes strates (IA -> Core -> UI).
*   **Flow Time (Lead Time Métier) :** Temps total entre l'acceptation d'une fonctionnalité métier (ex: "Optimiser les plannings de la ligne TGV A") et sa disponibilité pour l'utilisateur final. Intègre le temps de recherche IA, le dev Rust et l'intégration Web.
*   **Flow Efficiency (Efficience du flux) :** Ratio entre le temps de travail effectif et le temps d'attente (wait time). C'est le KPI clé pour détecter si l'équipe Elixir attend l'équipe Rust. *Action : Si l'efficience est < 40%, renforcer les mocks et l'asynchronisme.*

### 3.3. Garde-fous contre la complexité (Tech Debt & Refactoring)
*   **Règle d'allocation de capacité :** Chaque sprint/cycle garantit systématiquement **20% de la capacité** à la réduction de la dette technique, l'amélioration des pipelines de CI/CD et la mise à jour des contrats d'API.
*   **Critère d'arrêt de l'IA (Timeboxing) :** La recherche IA est encadrée par un budget temps. Si un modèle n'atteint pas le seuil de précision désiré dans le temps imparti, la version sous-optimale (ou une heuristique classique) est intégrée en production pour débloquer le produit, pendant que l'IA continue son itération suivante en tâche de fond.

---
**Conclusion :** La réussite de HexaPlanner ne résidera pas seulement dans l'excellence individuelle du code Rust ou IA, mais dans la fluidité de l'intégration continue entre ces domaines. L'utilisation stricte de contrats (API-First), le découplage des cycles (Dual-Track) et l'obsession de réduire la taille des lots de déploiement (DORA) sont les fondements de ce delivery.