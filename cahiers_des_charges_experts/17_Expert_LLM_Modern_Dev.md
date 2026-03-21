# Mandat d'Expertise : Ingénierie Augmentée par l'IA (AI-Assisted Development & LLMs)

**À l'attention de :** Directeur/Directrice de l'Ingénierie IA & Agentic Workflows  
**Date :** 21 Mars 2026  
**Projet :** HexaPlanner - Jumeau Numérique Industriel  
**Objectif :** Intégrer l'usage massif et systémique des modèles de langage (LLM) et des agents IA dans le cycle de vie du développement logiciel (SDLC).

## Contexte
En 2026, coder manuellement chaque ligne est un anti-pattern de productivité. Nous devons multiplier par 10 la vélocité de notre équipe d'ingénieurs en intégrant les LLMs au cœur même de la fabrication de HexaPlanner, depuis la rédaction de tests jusqu'au refactoring de l'héritage OptaPlanner.

## Ce que nous attendons de votre Guideline

1. **Agent-Assisted Development (Inner Loop) :**
   - Standardisation de l'utilisation d'assistants (comme GitHub Copilot, Cursor, ou Gemini CLI intégrés) dans les IDE des développeurs.
   - Définition de l'équilibre entre la génération de code par IA et la responsabilité de l'ingénieur (Zero-Trust AI Code).

2. **Pipelines de Refactoring et de Migration :**
   - Stratégie d'utilisation d'agents autonomes pour nettoyer automatiquement la dette technique d'OptaPlanner (les TODOs/FIXMEs) et traduire certains modules Java en Rust.

3. **Génération Automatique de Tests et de Documentation :**
   - Comment utiliser les LLMs pour générer exhaustivement les tests de cas limites (edge cases) et maintenir la documentation technique (Doc-as-Code) à jour lors de chaque Pull Request.

4. **Revues de Code par l'IA (LLM-as-a-Judge) :**
   - Mise en place d'agents dans la CI/CD pour faire une première passe de revue de code sémantique et détecter les failles logiques ou les non-respects d'architecture avant la revue humaine.

**Livrable attendu :** Un framework opérationnel dictant comment les LLMs doivent être utilisés, les outils recommandés (MCP, CLI agents), et les garde-fous pour garantir que l'IA augmente la qualité logicielle sans introduire de vulnérabilités.