# Politique de Sécurité Applicative et DevSecOps - HexaPlanner

**De :** Chief Information Security Officer (CISO) & Head of DevSecOps
**À :** Équipes d'Ingénierie, Architecture, et Produit HexaPlanner
**Date :** 21 Mars 2026
**Sujet :** Stratégie AppSec, Secure by Design & Threat Modeling pour l'Architecture Hybride

---

## 1. Introduction & Postulat de Base (Zero Trust)

Le système HexaPlanner traite des données relevant du secret industriel (plans de réseaux de transport, stratégies d'usines, données financières). Notre postulat de sécurité est clair : **l'environnement d'exécution est intrinsèquement hostile, les dépendances externes sont non fiables, et aucun acteur (humain ou machine) ne bénéficie d'une confiance par défaut.** Le paradigme "Secure by Design" n'est pas une option, c'est la condition *sine qua non* de la mise en production.

Ce document dicte les barrières de sécurité obligatoires (guardrails) couvrant le runtime, la chaîne d'approvisionnement (Supply Chain), le pipeline DevSecOps et la gestion des accès.

---

## 2. Modèle de Menace (Threat Model) : Architecture Hybride

Notre architecture combine Elixir (Orchestration),  (Moteur de base), Rust (Calcul intensif via C-FFI), et WASM (Exécution de plugins clients).

| Composant | Vecteurs d'Attaque Principaux (Menaces) | Impact Potentiel | Mitigations Architecturales |
| :--- | :--- | :--- | :--- |
| **Orchestrateur Elixir / Erlang VM** | Déni de Service (DoS) sur l'orchestration, empoisonnement des messages (Inter-Process Communication). | Arrêt complet du système, corruption de l'état global. | Isolation par Actor Model. Validation stricte du schéma des messages entrants. Rate-limiting au niveau réseau. |
| **Pont C-FFI ( <-> Rust)** | Dépassement de tampon (Buffer Overflow), fuite de mémoire (Memory Leak), corruption de pointeurs, injection de données malveillantes via FFI. | Exécution de code à distance (RCE), compromission totale du nœud hôte, exfiltration de mémoire. | Types stricts aux frontières. Rust `unsafe` confiné et audité. Passage par valeur ou copies sécurisées. Fuzzing ciblé des interfaces FFI. |
| **Moteur Rust / ** | Logique métier faussée (falsification des calculs), saturation CPU/RAM (ReDoS, bombes logiques). | Faux positifs dans les plannings (impact business majeur), DoS. | Timeouts d'exécution stricts (circuit breakers). Quotas de mémoire par job (cgroups). |
| **Environnement WASM (Plugins Clients)** | Évasion de la sandbox (Sandbox Escape), tentatives d'appels système (Syscalls), exfiltration de données via réseau. | Accès au système de fichiers hôte, vol de données d'autres locataires (Cross-Tenant). | Mode "WASI-restricted" absolu. `network=none`, `fs=none`. Temps d'exécution (Fuel) strictement limité. |

---

## 3. Sécurisation de l'Exécution (Runtime Security)

### 3.1. Frontières FFI (Foreign Function Interface)
- **Rust `unsafe` Minimal :** L'utilisation du bloc `unsafe` dans Rust est interdite sauf justification architecturale documentée et approbation par le CISO. Chaque bloc `unsafe` doit être isolé dans des modules spécifiques et soumis à une revue par des pairs obligatoire.
- **Validation des Entrées aux Frontières :** Toute donnée traversant la frontière /Rust ou Elixir/Rust doit être traitée comme *untrusted*. La désérialisation doit s'appuyer sur des bibliothèques éprouvées (ex: Serde avec limites de profondeur) pour éviter les attaques de type *Billion Laughs* ou de consommation de mémoire.

### 3.2. Durcissement WASM (WASM Hardening)
Les plugins fournis par les clients pour personnaliser les règles doivent s'exécuter dans un environnement WASM totalement hermétique :
- **Sandboxing Déterministe :** Utilisation d'un runtime WASM (ex: Wasmtime) configuré en mode d'isolation maximale.
- **Interdiction des Capacités (Capabilities Denied) :** Aucun accès réseau, aucun accès au système de fichiers, aucun accès aux variables d'environnement de l'hôte.
- **Limitation de Ressources (Metering/Fuel) :** Injection de compteurs d'instructions (fuel) pour prévenir les boucles infinies. Allocation mémoire maximale fixée (ex: max 64 MB par instance de plugin).

---

## 4. Secure Software Supply Chain (SSSC)

La compromission d'une dépendance est notre risque probabiliste le plus élevé.

### 4.1. Gestion des Dépendances (Rust, , Elixir)
- **Verrouillage et Hachage :** Les fichiers de lock (`Cargo.lock`, `mix.lock`, résolutions Maven) sont obligatoires. Toute modification d'une dépendance exige une revue humaine justifiant le changement de version.
- **Miroir Privé & Scan de Quarantaine :** Les artefacts (Crates, Hex, Maven) ne sont pas tirés directement d'Internet lors du build de production. Ils doivent passer par un registre interne (ex: Artifactory) qui effectue un scan antiviral et une analyse de vulnérabilité (SCA) avant de les marquer comme "approuvés".

### 4.2. Traçabilité (SBOM) et Signatures
- **Génération de SBOM :** Chaque build génère automatiquement un SBOM au format CycloneDX ou SPDX, listant exhaustivement les bibliothèques et leurs versions.
- **Signature Cryptographique des Artefacts :** Nous utilisons **Sigstore/Cosign**. Chaque image conteneur et chaque binaire produit par notre CI est signé de manière immuable. Les clusters Kubernetes de production (Admission Controllers) refuseront de démarrer toute image non signée par la clé CI/CD autorisée.

---

## 5. DevSecOps et Tests de Sécurité Continus (CI/CD Guardrails)

La sécurité "Shift-Left" impose que les vulnérabilités soient bloquées avant de fusionner le code.

### 5.1. Pipeline d'Analyse Statique (SAST) et Composition (SCA)
Les outils suivants sont intégrés dans les workflows de Pull Request et bloquent le merge en cas de criticité *High* ou *Critical* :
- **SAST Multi-langage :** Semgrep avec des règles personnalisées pour interdire les patterns dangereux en  et Elixir.
- **Rust-specific :** `cargo audit` (SCA), `cargo clippy` (qualité/sécurité), et `cargo deny` (pour la validation des licences et l'interdiction de crates spécifiques).
- **Elixir-specific :** `sobelow` pour l'analyse statique du code Elixir.

### 5.2. Fuzzing Continu du Moteur Mathématique
Pour garantir la résilience du moteur face à des entrées malformées :
- **AFL++ / libFuzzer :** Intégration de cibles de fuzzing (Fuzz Targets) sur les points d'entrée du parseur de données et des fonctions critiques d'optimisation en Rust.
- **Exécution Continue :** Le fuzzing s'exécute en continu sur une flotte de machines dédiées (Cluster Fuzzing ou OSS-Fuzz like workflow). Tout crash détecté génère un ticket d'incident critique P1.

### 5.3. DAST et Pen-Testing
- Des scans dynamiques (DAST) seront exécutés hebdomadairement sur les environnements de staging.
- Un test d'intrusion (Pen-Test) de type *Grey Box* par un cabinet externe indépendant sera réalisé bi-annuellement.

---

## 6. Gestion des Secrets et Conformité (Zero-Trust)

### 6.1. Identité et Accès (IAM)
- **Rotation Automatique :** Aucun secret statique n'est toléré dans la configuration. Nous utilisons un gestionnaire de secrets dynamique (HashiCorp Vault ou équivalent cloud-native). Les identifiants de base de données (PostgreSQL, etc.) sont générés à la volée avec une durée de vie courte (Time-To-Live de quelques heures).
- **Principe du Moindre Privilège :** Les rôles applicatifs sont granulaires. Le composant WASM n'a aucune identité. Le moteur d'optimisation Rust n'a d'accès qu'en lecture aux données d'entrée et en écriture vers une file de résultats isolée.

### 6.2. Chiffrement et Conformité
- **Data at Rest & In Transit :** Chiffrement systématique via AES-256-GCM au repos et mTLS strict entre tous les microservices et composants internes (Elixir <-> /Rust IPC si externalisé via réseau local).
- **Audit Logging :** Toute action administrative ou modification de sécurité est loguée dans un système immuable de type WORM (Write Once Read Many) pour l'analyse post-mortem (SIEM).

---

**Approbation requise avant application :**
*( ) CTO*
*( ) Lead Architect*

*La sécurité n'est pas un frein, c'est l'accélérateur qui nous permettra de vendre HexaPlanner aux industries les plus critiques au monde.*