# Mandat d'Architecture : Sous-système Apprentissage par Renforcement (Neuro-Symbolique)

**À l'attention de :** Chercheur/Chercheuse Principal(e) en IA, Reinforcement Learning & Accélération GPU  
**Date :** 21 Mars 2026  
**Référentiel Technologique :** État de l'art Février 2026 (RL pour l'Optimisation Combinatoire, JAX/PyTorch, CUDA 12+, GNN)  
**Projet :** HexaRail - Jumeau Numérique pour Job Shop Scheduling et Optimisation Ferroviaire

## Contexte et Vision Stratégique
Les solveurs traditionnels (Local Search, ALNS) perdent un temps précieux à explorer des voisinages sans issue ou à appliquer des heuristiques aléatoires de "destruction". L'état de l'art en 2026 exige un pont Neuro-Symbolique : utiliser des réseaux de neurones (ex: Graph Neural Networks - GNN) pour "intuiter" la topologie du problème et guider la recherche symbolique exacte.

Le système doit apprendre de l'historique de l'usine ou du réseau ferroviaire pour savoir, par exemple, quelle stratégie appliquer lorsqu'une machine spécifique tombe en panne.

## Ce que nous attendons de votre Cahier des Charges

Vous devez concevoir l'intégration du Machine Learning au sein de notre boucle de résolution hybride (Rust/Java) de manière extrêmement contrainte sur la performance. Votre cahier des charges devra spécifier :

1. **Modélisation de l'Agent RL (Reinforcement Learning) :**
   - Conception de la représentation d'état (State Representation). Comment encoder le réseau ferroviaire ou le Job Shop sous forme de Graphe (GNN) ou de tenseurs pour le réseau de neurones.
   - Spécification des Actions (Action Space) : L'agent ne doit pas directement placer les tâches, mais plutôt choisir la "méta-action" (ex: "Détruire la séquence autour de la machine 3" ou "Appliquer la heuristique de réparation de type B").
   - Conception de la fonction de récompense (Reward Function) basée sur l'Earliness/Tardiness et la diminution des temps de configuration.

2. **Architecture d'Inférence Basse Latence (GPU vs CPU) :**
   - La boucle d'optimisation demande des millions d'inférences par seconde. Spécifier comment éviter le goulot d'étranglement du bus PCIe.
   - Stratégies de traitement par lots (Batched Inference) : Comment le système Rust peut accumuler des centaines d'états d'arbres de recherche avant d'appeler le GPU de manière asynchrone (via Candle/Tract ou JAX).

3. **Pipeline d'Entraînement Hors Ligne (Offline Training) :**
   - Protocole d'apprentissage. Comment utiliser les solutions optimales trouvées par le solveur CP (Constraint Programming) la nuit pour entraîner le modèle RL par imitation (Imitation Learning) ou par algorithmes PPO/A2C.

**Livrable attendu :** Un papier d'architecture détaillant la topologie du réseau neuronal (GNN/Transformers), l'architecture d'inférence (Tensor layout), les boucles d'entraînement, et le protocole FFI d'appel GPU depuis le moteur logiciel Rust.