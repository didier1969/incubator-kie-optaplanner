# Mandat d'Expertise : Qualité du Code, Standards et Bonnes Pratiques Polyglottes

**À l'attention de :** Staff Engineer / Expert(e) en Qualité Logicielle (Clean Architecture)  
**Date :** 21 Mars 2026  
**Projet :** HexaPlanner - Jumeau Numérique Industriel  
**Objectif :** Définir les standards de codage impitoyables pour garantir la maintenabilité d'une architecture combinant Rust, Java et Elixir.

## Contexte
La dette technique est le pire ennemi d'un moteur de calcul mathématique. L'héritage d'OptaPlanner contient de nombreuses annotations TODO/FIXME et des pratiques Java vieillissantes. Avec l'introduction de Rust et Elixir, le risque de "code spaghetti" polyglotte est critique.

## Ce que nous attendons de votre Guideline

1. **Standards Spécifiques aux Langages :**
   - **Java 25 :** Règles strictes sur l'immutabilité, l'usage des Records, et l'interdiction de certaines pratiques héritées.
   - **Rust 2024 :** Stratégie de gestion des erreurs (Result/Option), interdiction stricte des blocs `unsafe` (sauf FFI isolés), et guidelines sur la gestion mémoire sans GC.
   - **Elixir (OTP) :** Règles sur le pattern matching, la let-it-crash philosophy, et la structuration des contextes (Hexagonal Architecture).

2. **Analyse Statique et Linting Impitoyable :**
   - Définition des pipelines de linting stricts pour interdire la fusion (Merge) si des warnings sont présents (Clippy pour Rust, Credo/Dialyzer pour Elixir, Sonar/SpotBugs pour Java).

3. **Revues de Code et Architecture (Clean Architecture) :**
   - Critères d'acceptation pour les Pull Requests, se concentrant sur la lisibilité, l'absence de couplage fort et l'idiomatisme du langage.

**Livrable attendu :** Un manuel de standards de code définissant les règles strictes, les anti-patterns à proscrire absolument, et la configuration des linters.