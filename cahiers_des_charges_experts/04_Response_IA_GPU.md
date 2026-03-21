# Architecture : Sous-système Apprentissage par Renforcement (Neuro-Symbolique)

**À l'attention de :** Direction de l'Ingénierie, Équipe d'Optimisation de HexaPlanner  
**Auteur :** Architecte IA Principal, Expert RL & Accélération GPU  
**Date :** 21 Mars 2026  
**Référentiel Technologique :** État de l'art 2026 (RL Combinatoire, GNN Dynamiques, CUDA 12.8, JAX/Candle, Inférence par Lots Zero-Copy)

## 1. Vision Stratégique du Pont Neuro-Symbolique

L'intégration d'un guidage neuronal au sein d'un solveur symbolique de type Local Search ou Constraint Programming (CP) permet d'éliminer la myopie des approches purement heuristiques. En 2026, l'architecture optimale de ce pont repose sur l'hybridation : l'agent IA agit en tant qu'**oracle de recherche** et de **méta-heuristique dirigée**, sans jamais transgresser les contraintes dures garanties par le moteur de résolution symbolique (Rust). L'IA propose intelligemment les mouvements, et le solveur exact valide et propage les contraintes.

## 2. Modélisation de l'Agent RL (Reinforcement Learning)

### 2.1. Représentation d'État (State Representation) via GNN
Pour traiter les topologies variables du Job Shop Scheduling et des réseaux ferroviaires, l'état global du système $S_t$ sera encodé à l'aide d'un **Graph Neural Network (GNN)**, plus spécifiquement un *Heterogeneous Message Passing Neural Network (MPNN)*.
- **Nœuds (Nodes) :** Représentent les entités physiques et logiques (Machines, Trains, Tâches, Stations). Les attributs incluent le temps de préparation, la durée de la tâche, les dépendances temporelles, et l'état actuel (en panne, libre, en maintenance).
- **Arêtes (Edges) :** Représentent les relations de précédence (Graphe Disjonctif pour le Job Shop) et les connexions physiques (réseau ferroviaire).
- **Tensorisation :** Le graphe est converti en une structure CSR (Compressed Sparse Row) adaptée à l'accélération GPU, accompagnée de tenseurs de caractéristiques (*Feature Tensors*) fp16/bf16.

### 2.2. Espace d'Action (Action Space) Méta-Heuristique
L'agent n'assigne pas directement les tâches aux ressources (ce qui violerait potentiellement les contraintes dures). L'Action Space $A_t$ est une distribution de probabilités sur un espace de **méta-actions** :
- **Sélection d'opérateurs de destruction (LNS) :** Choix ciblé (ex: "Détruire la séquence autour de la machine $m_3$ avec un rayon de $k=5$ tâches").
- **Sélection d'heuristiques de réparation :** Choix de la stratégie de reconstruction (ex: "Earliest Due Date avec insertion gourmande pondérée").
- L'espace est hybride : discret (choix de la heuristique) et continu (paramétrisation du rayon de destruction).

### 2.3. Fonction de Récompense (Reward Function)
La Reward Function $R(s, a, s')$ est conçue pour maximiser l'efficacité globale (Makespan) tout en respectant les délais :
- **Composante principale :** $\Delta$ Earliness/Tardiness. Si la méta-action réduit le retard global pénalisé des jobs, $R > 0$.
- **Réduction des temps de configuration (Setup Times) :** Prime pour le regroupement de tâches de même nature.
- **Shaping :** Pénalité de calcul (Compute Penalty) pour décourager les explorations inutiles dans des voisinages denses sans amélioration de la fonction objectif.

## 3. Architecture d'Inférence Basse Latence (GPU vs CPU)

L'évaluation de l'agent RL au sein d'une boucle de recherche locale exige des millions d'inférences par seconde. L'inférence naïve transactionnelle sur GPU introduit une latence inacceptable due aux transferts sur le bus PCIe.

### 3.1. Surmonter le Goulot d'Étranglement PCIe
- **CUDA 12.x Graphs & Cuda Streams :** Pré-enregistrement des graphes d'exécution pour minimiser le surcoût de lancement des kernels GPU depuis le CPU.
- **Transfert Zero-Copy / Pinned Memory :** Le moteur Rust alloue la mémoire d'état dans une plage de mémoire paginée partagée (Pinned RAM), accessible en DMA (Direct Memory Access) par le GPU.

### 3.2. Stratégies d'Inférence par Lots (Batched Inference)
L'inférence n'est jamais exécutée sur un état unique.
1. Le solveur de recherche Rust génère et évalue simultanément $N$ voisinages ou branches de recherche indépendantes (où $N$ correspond à la taille optimale du batch, typiquement $N=256$ ou $N=1024$).
2. Les caractéristiques de ces $N$ états sont vectorisées en un seul batch tensoriel en mémoire hôte (Host Memory).
3. Le batch est envoyé de manière asynchrone au GPU. Pendant l'inférence, le thread Rust effectue le rollback ou la propagation des contraintes sur d'autres nœuds de l'arbre.
4. Le modèle (basé sur JAX via XLA, ou Candle nativement en Rust) retourne un tenseur de distribution d'actions pour l'ensemble du batch.

## 4. Pipeline d'Entraînement Hors Ligne et En Ligne (Offline/Online Training)

### 4.1. Imitation Learning (Offline)
- **Génération de données :** Durant la nuit ou sur des clusters dédiés, le solveur exact (CP ou MIP) trouve des solutions quasi-optimales sur des instances historiques. L'historique de recherche, filtré pour ne conserver que le "chemin optimal" de résolutions et de décisions de branchement, constitue un dataset de trajectoires expertes.
- **Behavioral Cloning :** Le modèle GNN est d'abord pré-entraîné en apprentissage supervisé (Loss Cross-Entropy) pour imiter les décisions des solveurs exacts. Cela amorce les poids du réseau et évite le problème du "Cold Start".

### 4.2. Proximal Policy Optimization (PPO) (Online / Fine-tuning)
- Une fois pré-entraîné, l'agent évolue dans un environnement simulé (le Jumeau Numérique / Job Shop Simulator).
- Utilisation de l'algorithme **PPO (Proximal Policy Optimization)** ou **A2C** pour affiner la politique $\pi_\theta(a|s)$. Le GNN apprend ainsi à s'adapter aux dynamiques stochastiques (pannes de machines, retards ferroviaires) et découvre des stratégies de résolution que le solveur exact n'aurait pas pu explorer en temps polynomial.

## 5. Protocole FFI et Intégration Rust-GPU

L'intégration évite l'utilisation de Python en production pour des raisons de GIL et de latence. L'inférence est déployée *in-process*.

- **Moteur d'Inférence :** Utilisation de `Candle` (le framework ML de HuggingFace en Rust pur) ou `Tract`. Cela permet d'éliminer la barrière C-FFI et de charger des modèles au format safetensors.
- **Layout Tensoriel :** Les tenseurs utilisent la disposition *Contiguous NCHW* (Batch, Channel, Height, Width ou Node-Feature) avec une précision réduite `bfloat16` pour doubler le débit des Tensor Cores des architectures GPU récentes (Hopper/Blackwell).
- **FFI Contract :** Si un runtime JAX/XLA C++ est utilisé, l'interface FFI exporte une fonction `extern "C"` asynchrone prenant en entrée des pointeurs bruts vers la Pinned Memory et retournant une promesse (Future Rust) résolue lors de la complétion du stream CUDA.

```rust
// Exemple conceptuel de l'interface FFI / Inférence Rust
pub async fn infer_meta_actions_batch(
    state_graphs: &BatchGnnState,
    inference_ctx: &CudaContext
) -> Result<Tensor, InferenceError> {
    // 1. Zero-copy DMA transfer to GPU
    let d_state = inference_ctx.dma_transfer(state_graphs);
    // 2. Execute pre-compiled CUDA Graph (Candle/XLA)
    let d_logits = inference_ctx.execute_graph_async(d_state).await?;
    // 3. Return action distribution tensor to the symbolic solver
    Ok(d_logits.to_host()?)
}
```

Ce paradigme assure au solveur HexaPlanner une réactivité sub-milliseconde tout en bénéficiant de l'intuition topologique des réseaux de neurones profonds de 2026.