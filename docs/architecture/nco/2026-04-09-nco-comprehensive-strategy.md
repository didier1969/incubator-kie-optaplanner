# NCO (Neural Combinatorial Optimization) : Stratégie Globale & Architecture JSSP

**Statut :** Document de Synthèse Architecturale (State of the Art 2025-2026)
**Projet :** HexaCore / HexaFactory (Applicable aux problèmes NP-Difficiles de type Job-Shop Scheduling)
**Date :** 9 Avril 2026

Ce document consigne l'intégralité des réflexions, analyses et directives architecturales concernant l'intégration de la **Neural Combinatorial Optimization (NCO)** et de la recherche en **Espace Latent (Embeddings)** pour résoudre des problèmes d'ordonnancement industriels massifs.

---

## 1. Le Paradigme : Espace Discret vs Espace Latent Continu

La NCO représente un changement de paradigme fondamental par rapport aux métaheuristiques classiques (Algorithmes Génétiques - GA, Recuit Simulé - SA).

*   **L'Impasse Discrète (GA / SA / Heuristiques) :** Les algorithmes classiques explorent l'espace des solutions discrètes (permutations). Face à des contraintes complexes (Setup times dépendants de la séquence, Buffers limités, Compétences), ils souffrent de "myopie locale". Parcourir systématiquement les ordres sur 6 mois provoque un Effet Papillon : une optimisation locale détruit la capacité globale plus tard.
*   **La Révolution Latente (NCO) :** La NCO projette les contraintes du problème (le graphe de l'usine et les ordres) dans un **espace vectoriel continu (Latent Space)** grâce à des Graph Neural Networks (GNN).
*   **L'Avantage Mathématique :** Dans cet espace continu, l'algorithme peut utiliser la descente de gradient ou des marches aléatoires pour "glisser" vers l'optimum. Il identifie instantanément des "Galaxies Sémantiques" (ex: des groupes d'ordres partageant des affinités de setup, indépendamment de leur date de livraison) pour concevoir une macro-stratégie qui annule les pertes de capacité.

---

## 2. Application au JSSP (Job-Shop Scheduling) et HexaFactory

Dans le contexte d'HexaFactory, l'usine fait face à des pertes de capacité allant jusqu'à 40% dues aux temps de préparation (Setups).

### L'Architecture Hybride Cible (Neural-Heuristic)
On ne remplace pas le moteur Rust (Salsa) actuel, on l'augmente en créant un pipeline à deux étages :
1.  **Niveau Stratégique (NCO / Embeddings) :** Le modèle NCO prend le carnet de commandes de 6 mois. En quelques millisecondes, il regroupe, batch et séquence les grandes phases de production en se basant sur la topologie de l'espace latent. Il dicte la "Macro-Séquence" quasi-optimale.
2.  **Niveau Tactique (Solveur Rust / SA) :** Le moteur Rust reçoit cette macro-séquence. L'espace de recherche ayant été réduit de 99%, le Recuit Simulé (SA) n'a plus qu'à "polir" la solution (Recherche Locale) pour absorber les micro-contraintes physiques de dernière minute.

---

## 3. Gestion de l'Échelle (Scalabilité) : Comment gérer 100 000 opérations ?

L'explosion combinatoire est maîtrisée par trois avancées SOTA (2025-2026) :

1.  **Divide-and-Optimize :** Les problèmes massifs sont découpés géométriquement ou temporellement. La NCO résout des sous-problèmes (ex: 1000 opérations), puis un algorithme rapide les assemble.
2.  **Linear Complexity Transformers :** Les nouveaux mécanismes d'attention (Cross-Attention) ont une complexité linéaire $O(N)$, évitant l'explosion de la mémoire VRAM.
3.  **Zero-Shot Generalization (Transfert d'Échelle) :** Le modèle NCO **n'est jamais entraîné sur des usines géantes**. Il est entraîné sur des "Micro-Usines" (ex: 10 machines, 50 ordres). Dans l'espace latent, il apprend les "lois de la physique" (les goulots d'étranglement). En production, on lui injecte une usine de 200 machines, et il généralise instantanément sa logique mathématique à cette nouvelle échelle.

---

## 4. Stratégie d'Entraînement (Reinforcement Learning)

L'entraînement ne se fait **jamais** sur des logs historiques (qui contiennent les erreurs humaines), mais via **Apprentissage par Renforcement (RL)**.

### Le Mur du Disque (20 Téraoctets) et sa Solution
Générer 1 million de scénarios d'usines pour entraîner l'IA produirait des dizaines de téraoctets de données, saturant les disques et la bande passante.
*   **La Solution SOTA : Génération Procédurale en Mémoire (On-the-Fly).**
*   L'entraînement utilise l'architecture basée sur des "Seeds" déjà présente dans HexaFactory (`dataset.ex`).
*   Pendant l'entraînement, Elixir génère l'usine directement dans la RAM. Le GPU (Python/RL) consomme le graphe, met à jour ses poids mathématiques, et l'usine est détruite de la RAM. **Volume sur le disque : 0 Octet.**

---

## 5. Faisabilité Matérielle (Hardware Requirements)

La NCO sépare strictement le coût d'entraînement du coût d'inférence.

### A. L'Entraînement (Laptop Edge - RTX 4060 / 8 Go VRAM)
*   **Faisabilité :** 100% réalisable en local. Les modèles GNN sont petits (moins de 200 Mo). Les 8 Go de VRAM servent à stocker les "batchs" de micro-usines (64 à 128 par itération).
*   **Durée estimée :** Entre **12 et 48 heures** de calcul continu.
    *   *T+4h:* Compréhension des règles de base (buffers).
    *   *T+24h:* Maîtrise des stratégies de setup (Optimum local).
    *   *T+48h:* Robustesse (SOTA).
*   **Optimisations requises :** Précision mixte (FP16 / `torch.cuda.amp`) pour diviser la consommation VRAM par 2 et accélérer les calculs. Gestion thermique du laptop.

### B. L'Inférence (En Production / Temps Réel)
*   **Faisabilité :** Ultra-léger. Réalisable sur **CPU ou NPU**.
*   **Ressources :** 0 Go de VRAM requise. 8 à 16 Go de RAM système suffisent.
*   **Vitesse :** Résolution d'un nouveau planning en quelques millisecondes (Forward Pass).
*   **Le "Dynamic Rescheduling" :** En cas de panne d'une machine, le graphe est mis à jour et passé dans le modèle. Le nouveau planning optimal est calculé en **temps réel** (quelques millisecondes), rendant le système infiniment plus réactif qu'un algorithme génétique.

---

**Conclusion Exécutoire :** 
Le passage d'une optimisation "Search Space" (aveugle) à une optimisation "Latent Space" (guidée mathématiquement) est le levier principal de performance pour HexaCore. L'infrastructure actuelle de génération (Elixir) et de calcul de score (Rust) est parfaitement positionnée pour accueillir une surcouche GNN/RL, transformant le projet en un planificateur topologique d'échelle industrielle.