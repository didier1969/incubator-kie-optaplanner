# Cahier des Charges : Sous-système Extensibilité Sécurisée et Déploiement

**Date :** 21 Mars 2026
**Auteur :** Architecte Principal Cloud, WebAssembly (WASM) & Infrastructure-as-Code
**Projet :** HexaRail - Jumeau Numérique pour Job Shop Scheduling et Optimisation Ferroviaire

Ce document détaille l'architecture de la couche d'extensibilité, de configuration sécurisée et d'infrastructure de HexaRail, en s'appuyant sur l'état de l'art technologique de 2026.

---

## 1. Sandboxing et Plugins Client (WASM)

Pour permettre à nos clients industriels d'injecter des règles métiers ultra-spécifiques et complexes sans compromettre la sécurité et les performances du système global, nous adoptons une architecture de plugins basés sur WebAssembly (WASM).

### 1.1 Moteur d'exécution (Extism / Wasmtime)
- **Intégration :** Le moteur de scoring ultra-performant (implémenté en Rust avec SIMD) intégrera **Wasmtime** (via l'interface **Extism** pour faciliter l'interopérabilité polyglotte Rust/Java/Elixir).
- **Exécution in-loop :** L'évaluation de la contrainte personnalisée s'effectue directement dans la boucle de calcul du score. Wasmtime offre une compilation JIT (Just-In-Time) ou AOT (Ahead-Of-Time) ultra-rapide garantissant une surcharge d'appel (overhead) de l'ordre de la nanoseconde.

### 1.2 Sandbox, SecOps et Limites (Resource Constraints)
Le module client s'exécute dans une sandbox mathématiquement prouvée, isolant le code externe du système hôte :
- **Consommation CPU (Fuel Mechanism) :** Chaque appel de plugin `.wasm` se voit allouer une quantité stricte de "Fuel" (instructions WASM mesurées). Toute tentative de boucle infinie épuisera le fuel et interrompra instantanément le plugin, retournant une erreur au solveur sans impacter le thread principal.
- **Isolation Mémoire :** La mémoire linéaire de chaque instance WASM est bornée (ex: maximum 2 MB par instance d'évaluation). Le code client n'a physiquement aucun accès à la mémoire du solveur hôte.
- **Zéro I/O (Default-Deny) :** Les capacités WASI (WebAssembly System Interface) réseau et système de fichiers sont **totalement désactivées**. La fonction est pure : elle prend l'état en entrée et retourne une pénalité.

### 1.3 Interface et Workflow Client
- **Component Model (WIT) :** Les signatures des fonctions d'extension sont strictement définies via le *WebAssembly Component Model* (fichiers `.wit`).
  - Exemple de signature : `calculate_rule_penalty(state: borrow<planning-context>, entity: borrow<train-entity>) -> result<u32, error>`
- **Workflow :** Le client développe sa logique dans le langage de son choix (Rust, Go, Zig, AssemblyScript), compile en cible `wasm32-unknown-unknown`, et téléverse le fichier `.wasm` via notre API SaaS. Notre CI interne valide la conformité WIT avant d'autoriser l'injection.

---

## 2. DSL Déclaratif et Configuration Typée

Afin de remplacer l'historique de configuration fragile (XML/JSON), le paramétrage du solveur et des heuristiques (limites de temps, poids des contraintes, algorithmes de voisinage) est défini via un DSL (Domain-Specific Language) déclaratif et typé : **CUE (Configure Unify Execute)**.

### 2.1 Validation Mathématique Statique
- **Unification Types/Valeurs :** CUE permet de définir non seulement la structure attendue de la configuration, mais aussi de contraindre les valeurs (ex: `timeout: >= 1s & <= 3600s`, `weights: { [string]: uint }`).
- **Pré-évaluation :** Avant même le démarrage du nœud GraalVM ou Elixir, la configuration soumise par le client est évaluée par l'interpréteur CUE. Toute incohérence mathématique ou structurelle est rejetée à la soumission (Shift-Left validation), évitant tout crash en cours de résolution.

---

## 3. Infrastructure-as-Code et Reproductibilité absolue (Nix)

L'écosystème HexaRail étant nativement polyglotte (Java GraalVM, Rust FFI, Elixir OTP), les outils standards de conteneurisation (Docker) sont insuffisants pour garantir une reproductibilité stricte de la compilation de la toolchain combinée. Nous adoptons **Nix Flakes**.

### 3.1 Environnement de Compilation "Bit-for-Bit"
- **Fichier `flake.nix` :** L'intégralité des dépendances (Rust compiler, JDK GraalVM, Erlang/OTP, bibliothèques C natives pour Wasmtime) est déclarée dans un `flake.nix` à la racine du dépôt.
- **Verrouillage Cryptographique :** Le fichier `flake.lock` fige les hashes cryptographiques exacts de chaque composant de la toolchain. Un développeur rejoignant le projet exécute `nix develop` et obtient à l'octet près le même environnement que les serveurs CI/CD de production.

### 3.2 Pipeline CI/CD et Immutable Releases
- **Build unifié :** La compilation des bibliothèques dynamiques Rust (FFI), leur intégration dans le build Maven/Quarkus, puis la génération de l'image native GraalVM est orchestrée par une dérivation Nix unique (`derivation`).
- **Déploiement :** Le livrable généré par Nix est une archive ou un conteneur OCI déterministe, garantissant qu'aucune dérive système n'a pu corrompre l'artéfact entre l'étape de test et de mise en production.

---

## 4. Edge Computing : Stratégie WASM In-Browser

L'adoption de WASM ouvre une perspective stratégique majeure pour l'expérience utilisateur et l'optimisation des coûts cloud de HexaRail.

### 4.1 Exécution Client-Side (Navigateur)
- **Compilation Cœur Rust -> WASM :** Le moteur de scoring principal de HexaRail (écrit en Rust) est compilé en `.wasm` (cible `wasm32-wasip1` ou avec Wasm Threads/SIMD activés).
- **Cas d'usage "What-If" :** Lorsqu'un planificateur ferroviaire industriel effectue des manipulations manuelles interactives sur l'UI (ex: décaler un train de 5 minutes sur le diagramme de Gantt), l'évaluation du score partiel est calculée directement dans le navigateur du client via un Web Worker.
- **Bénéfices :**
  - **Latence Zéro :** Réponse instantanée (< 16ms) pour l'utilisateur, fluide jusqu'à 60 FPS, sans round-trip réseau vers nos serveurs.
  - **Coûts Serveur (FinOps) :** Déchargement massif des calculs d'exploration mineure vers les machines clientes (Edge computing), réservant la puissance de calcul du cluster cloud SaaS aux algorithmes de recherche globale lourds (Tabu Search, Simulated Annealing).