# Manuel de Developer Experience (DevEx) & Culture d'Ingénierie

**Auteur :** Staff Engineer / Developer Experience (DevEx) Director
**Projet :** HexaPlanner - Jumeau Numérique Industriel
**Date :** 21 Mars 2026

---

## 1. Philosophie et Culture d'Ingénierie

La complexité accidentelle est notre principal ennemi. Sur un projet mêlant Java GraalVM, Rust (SIMD), Elixir (OTP), et du C-FFI, notre objectif DevEx est de **masquer la complexité globale** derrière des interfaces de développement simples, pour que chaque ingénieur puisse se concentrer exclusivement sur sa zone d'expertise. Le principe fondateur est : **"Zero Friction, High Cohesion, Loose Coupling"**.

---

## 2. L'Environnement de Développement Local (Inner Loop)

Pour garantir un temps de configuration (Time-to-First-Commit) inférieur à 3 minutes, nous adoptons une approche **Infrastructure as Code pour le poste de travail**. 

### 2.1. L'Outil Standard : Nix & Devenv (Couplé à DevContainers)
Nous utiliserons **Nix** via l'outil **Devenv.sh** (ou des DevContainers de fallback pour ceux préférant GitHub Codespaces/VSCode Remote).

**Le Workflow "One-Command" :**
1. `git clone git@github.com:nexusplanner/nexusplanner.git`
2. `cd nexusplanner`
3. `devenv up` (ou `docker compose up -d` pour l'approche DevContainer)

Cette commande va automatiquement :
- Télécharger et isoler les bonnes versions des toolchains (JDK 21, Rust `cargo`, Elixir, GCC/Clang pour le C-FFI).
- Démarrer les services dépendants (PostgreSQL, Kafka/RabbitMQ) via des conteneurs éphémères locaux (Testcontainers pour Java, ou services Docker gérés par Devenv).
- Configurer les variables d'environnement (`DATABASE_URL`, `RUST_LOG`, etc.).
- Lancer le mode "Hot Reload" (Quarkus Dev Mode, `cargo watch`, LiveView).

### 2.2. Le "Inner Loop" Parfait
Le développeur ne doit jamais compiler l'ensemble de la stack manuellement.
- **Backend Java/Quarkus** : Les développeurs Java lancent `mvn quarkus:dev` (intégré dans Devenv) qui gère le live-reload.
- **Solveur Rust** : Compilé en tant que librairie dynamique (`.so`/`.dll`) en local, avec un mock Java pour éviter de recompiler le solveur C-FFI à chaque changement métier.
- **Frontend/Orchestrateur Elixir** : `mix phx.server` avec rechargement à chaud.

---

## 3. Mitigation de la Charge Cognitive (Architecture Repo)

Pour éviter qu'un expert Web/Elixir ne se heurte aux erreurs de compilation du solveur Rust ou aux pointeurs C++, nous adoptons un modèle de **Monorepo Logique (Polyrepo Physique ou Monorepo Modulaire avec Bazel/Nx)**.

### 3.1. Structure du Référentiel
Nous utiliserons un **Monorepo géré par un build system performant (Bazel ou Gradle Enterprise)** avec un partitionnement strict :
- `/solver-core` (Rust + C-FFI)
- `/routing-engine` (Java/Quarkus)
- `/orchestration-ui` (Elixir/Phoenix)
- `/contracts` (Protobuf/gRPC, OpenAPI)

### 3.2. Isolation par les Contrats (API-First & gRPC)
- **Le secret de la DevEx ici est le répertoire `/contracts`.** Les équipes communiquent exclusivement via des schémas Protobuf ou OpenAPI.
- Un développeur Elixir n'a **pas besoin de compiler le code Rust**. L'environnement de développement télécharge automatiquement les **binaires pré-compilés (artifacts)** de la branche `main` du solveur Rust depuis notre registry interne, ou utilise un mock gRPC.
- Seuls les développeurs "Core" (Fullstack Cross-Language) ont besoin d'exécuter la stack complète.

---

## 4. Documentation As Code et Décisions Architecturales

La documentation n'est pas une réflexion après coup, c'est du code.

### 4.1. Architecture Decision Records (ADRs)
Toute décision impactant plus d'un composant ou un choix technologique majeur doit passer par un ADR.
- **Format :** Markdown simple, stocké dans `/docs/architecture/decisions/`.
- **Outil :** Utilisation de l'outil CLI `adr-tools`.
- **Structure de l'ADR :** Titre, Statut (Proposé, Accepté, Remplacé), Contexte, Décision, Conséquences (positives et négatives).
- **Processus :** Soumis en Pull Request, débattu de manière asynchrone, fusionné une fois le consensus atteint (ou tranché par le Staff Engineer).

### 4.2. Codebase Mapping & Navigation
- **Structurizr / C4 Model :** La cartographie de haut niveau du système est gérée sous forme de code (format DSL Structurizr) dans le dépôt. Cela génère automatiquement des diagrammes d'architecture (Contexte, Conteneurs, Composants) toujours à jour lors de l'intégration continue.
- **Génération de Docs API :** Swagger UI (pour REST) et Buf (pour Protobuf/gRPC) sont intégrés nativement à l'environnement local.
- **Onboarding Docs :** Le README racine agit comme un index. La documentation `/docs` utilise **MkDocs** (Material for MkDocs) ou **Antora** pour générer un site statique interne, consultable en local (`devenv docs`).

---

## 5. Plan d'Onboarding Standardisé

Un nouveau développeur doit être productif (faire un commit en production) **en moins de 5 jours**, et non 6 mois.

- **Jour 1 : "Hello World" Système.** Cloner le repo, lancer `devenv up`, vérifier que les tests d'intégration locaux passent. Accès aux outils (Jira, Slack, GitHub).
- **Jour 2 : Exploration guidée.** Lecture des 5 ADRs fondateurs. Consultation du modèle C4 (diagramme de conteneurs). Compréhension de l'architecture via le site MkDocs interne.
- **Jour 3 : Le Contrat d'Interface.** Comprendre le dossier `/contracts`. Faire une modification triviale sur un fichier `.proto` ou `.yaml` et voir comment les stubs sont générés.
- **Jour 4 : Pair Programming.** Travailler sur un ticket "Good First Issue" avec un développeur senior dans la stack d'expertise du nouvel arrivant (ex: un endpoint Java, ou une vue LiveView).
- **Jour 5 : Premier Déploiement.** Pousser la Pull Request, voir les GitHub Actions faire les vérifications de sécurité, le linting, et les tests automatisés, puis merger en production via GitOps.

### Conclusion
La complexité inhérente au métier (HexaPlanner) et à l'architecture polyglotte est assumée. Cependant, notre plateforme DevEx agit comme un bouclier. Si un développeur doit comprendre comment compiler du Rust pour changer un bouton en Elixir, le système a échoué. Notre obsession est la vélocité et le confort mental de l'ingénieur.