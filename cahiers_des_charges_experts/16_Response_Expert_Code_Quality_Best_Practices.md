# Manuel des Standards de Code et Bonnes Pratiques : Projet HexaPlanner

**Auteur :** Staff Engineer / Expert(e) en Qualité Logicielle
**Date :** 21 Mars 2026
**Projet :** HexaPlanner - Jumeau Numérique Industriel

## 1. Philosophie Générale (Clean Architecture & Maintenabilité)

Dans le cadre de HexaPlanner, la fiabilité mathématique, la performance d'exécution et la résilience sont primordiales. La dette technique n'est pas tolérée. Ce manuel définit nos standards impitoyables. 

**La règle d'or :** Aucun code ne rejoint la branche principale (`main`) s'il contrevient à ces principes, s'il déclenche le moindre avertissement lors de l'analyse statique, ou s'il introduit une régression dans la couverture de tests.

Nous appliquons les principes de la **Clean Architecture**. L'infrastructure dépend du domaine (moteur de calcul), et non l'inverse. Les frontières entre Rust,  et Elixir doivent être explicites et interagir via des contrats stricts.

---

## 2. Standards Spécifiques par Langage

### 2.1.  25 (Orchestration & Domaine Historique)

Le code  doit être idiomatique, moderne et robuste. Les pratiques héritées des vieilles versions d'OptaPlanner sont interdites.

*   **Immutabilité par Défaut :** Toutes les classes représentant des données, des configurations ou des messages doivent être des `record`. L'usage des POJOs mutables avec des setters est **strictement interdit** dans les nouveaux développements.
*   **Variables Locales :** Utilisez `var` lorsque le type est évident. Toute variable locale doit être implicitement finale (ne réassignez jamais une variable locale).
*   **Collections :** Utilisez exclusivement `List.copyOf()`, `Set.copyOf()`, et `Map.copyOf()` ou les méthodes factory (`List.of()`, etc.) pour retourner et stocker des collections. N'exposez jamais de collections mutables.
*   **Null Safety :** `null` n'a pas sa place dans le code moderne. Utilisez `Optional<T>` pour les valeurs de retour pouvant être absentes. Ne passez jamais de `null` ou `Optional` en paramètre de méthode. Les annotations `@NonNull` et `@Nullable` (JSpecify) doivent être appliquées aux frontières d'API historiques.
*   **Anti-patterns Proscrits :** 
    *   `TODO`/`FIXME` sans ticket Jira associé (ex: `// TODO(NXP-1234): ...`).
    *   Injection de dépendances par champs (`@Autowired` sur un champ) : utilisez l'injection par constructeur exclusivement.

### 2.2. Rust 2024 (Moteur de Calcul Intensif & SIMD)

Rust est notre garantie de performance (SIMD) et de sécurité mémoire. 

*   **Gestion des Erreurs (Result/Option) :** `panic!`, `unwrap()` et `expect()` sont **formellement interdits** dans le code métier (tolérés uniquement dans les tests s'ils sont justifiés). Utilisez systématiquement `Result<T, E>` ou `Option<T>` et propagez les erreurs via l'opérateur `?`. Créez des types d'erreurs spécifiques au domaine (utilisez `thiserror`).
*   **Sécurité et `unsafe` :** L'usage de blocs `unsafe` est **strictement proscrit** de la logique métier. La seule exception concerne les ponts FFI isolés (avec /Elixir). Ces blocs doivent être encapsulés dans des modules spécifiques, commentés avec précision sur les invariants garantis, et exposer une interface 100% *Safe Rust*.
*   **Gestion de la Mémoire (Sans GC) :** Privilégiez l'allocation sur la pile. Évitez le clonage défensif (`.clone()`) ; utilisez le système de *borrowing* (`&T` et `&mut T`) avec des lifetimes explicites. L'usage de `Rc` ou `Arc` doit être justifié par un besoin légitime de *shared ownership*.
*   **Concurrence :** Priorisez le passage de messages (channels) via `tokio` ou `crossbeam` plutôt que le partage de mémoire mutable (Mutex/RwLock).

### 2.3. Elixir & OTP (Orchestration Distribuée, Résilience & Temps Réel)

Elixir gère la résilience du système, l'orchestration distribuée et les API. Nous embrassons pleinement la philosophie OTP et les principes fonctionnels.

*   **Philosophie "Let it Crash" :** Ne tentez pas d'intercepter toutes les exceptions ou erreurs imprévues (pas de programmation défensive excessive avec des `try/rescue`). Laissez les processus échouer rapidement et confiez le redémarrage (dans un état propre) aux arbres de supervision (*Supervision Trees*).
*   **Pattern Matching & Clauses de Garde :** Remplacez les blocs `if/else` ou `cond` complexes par du *pattern matching* agressif dans la signature des fonctions (multiple function heads) couplé à des clauses de garde (`when`).
*   **Architecture Hexagonale (Contextes) :** Groupez le code par **Contextes Métier** clairs. Un contexte métier (Core) ne doit jamais dépendre de l'interface web (Phoenix LiveView) ou de l'infrastructure externe (Base de données, API externes). Définissez des contrats stricts entre les contextes.
*   **Pipelines et Fonctions Pures :** Favorisez l'opérateur pipe `|>` pour enchaîner les transformations de données immutables. Gardez vos fonctions pures et repoussez les effets de bord (I/O, appels FFI Rust) aux frontières de l'architecture.

---

## 3. Analyse Statique et Pipelines CI Impitoyables

La Continuous Integration (CI) est le gardien impartial du projet. Aucune Pull Request (PR) ne peut être *mergée* si l'analyse statique échoue. **La politique est le "Zero Warning".**

*   **Rust (Clippy & rustfmt) :**
    *   Exécution : `cargo fmt -- --check` et `cargo clippy -- -D warnings`.
    *   Règle : Tout avertissement Clippy est une erreur fatale. Les rares exceptions via `#[allow(clippy::...)]` (ex: pour du code généré ou FFI) doivent inclure un commentaire justifiant techniquement le besoin.
*   **Elixir (Credo, Dialyzer & mix format) :**
    *   Exécution : `mix format --check-formatted`, `mix credo --strict`, et `mix dialyzer`.
    *   Règle : `mix format` est obligatoire. Credo en mode strict ne doit remonter aucun avertissement de style ou de refactoring. Dialyzer doit valider tous les *typespecs* (`@spec` et `@type`) sans exception ; ceux-ci sont d'ailleurs obligatoires pour toute fonction ou module public.
*   ** (SonarQube, ErrorProne & Spotless) :**
    *   Exécution : Maven avec le plugin Spotless pour le formatage, ErrorProne branché sur le compilateur, et analyse SonarQube avec le profil "HexaPlanner Strict".
    *   Règle : Le pipeline échoue au moindre *warning* de compilation (ErrorProne). La Quality Gate SonarQube bloque la PR au premier *Code Smell*, Bug, ou Vulnérabilité.

---

## 4. Revues de Code et Critères d'Acceptation (Clean Architecture)

Le processus de revue de code (Pull Request) vise à garantir l'alignement architectural, l'idiomatisme et la clarté. La performance ne doit pas primer sur la lisibilité, sauf preuve chiffrée.

### Critères d'Acceptation (Definition of Done) des PRs :
1.  **Lisibilité et Idiomatisme :** Le code est expressif et respecte les conventions du langage cible. Pas de code  écrit avec des paradigmes C, pas de code Rust écrit comme du  orienté objet. Le code se lit comme une documentation exécutable.
2.  **Couplage Faible (Clean Architecture) :** Les changements respectent les frontières architecturales. Le domaine ne dépend pas de l'infrastructure. Aucune dépendance cyclique n'est introduite.
3.  **Tests & Couverture :** La PR inclut des tests unitaires (et d'intégration si nécessaire). La couverture de code de la portion ajoutée/modifiée doit être supérieure à 90%. Les tests doivent prouver le comportement, pas tester l'implémentation interne.
4.  **Micro-Optimisations Justifiées :** Toute optimisation rendant le code moins lisible (ex: contournement du *borrow checker* en Rust, *loop unrolling* manuel en ) doit être justifiée par des benchmarks chiffrés joints à la PR (Criterion pour Rust, JMH pour ).
5.  **Documentation & ADR :** Tout changement architectural structurant doit être acté par un *Architecture Decision Record* (ADR). Les modules publics et les frontières FFI doivent être rigoureusement documentés (doc, `///`, `@moduledoc`).