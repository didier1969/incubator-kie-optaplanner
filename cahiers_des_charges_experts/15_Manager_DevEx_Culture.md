# Mandat d'Expertise : Developer Experience (DevEx) et Culture d'Ingénierie

**À l'attention de :** Staff Engineer / Developer Experience (DevEx) Director  
**Date :** 21 Mars 2026  
**Projet :** HexaPlanner - Jumeau Numérique Industriel  
**Objectif :** Garantir que ce monstre technologique reste un plaisir à développer et maintenir pour les équipes.

## Contexte
La complexité de ce projet est effrayante : il faut connaître le C-FFI, gérer la mémoire Rust, comprendre l'OTP Erlang, et maîtriser les mathématiques des Constraint Streams. Si nous n'y prenons pas garde, l'intégration (Onboarding) d'un nouveau développeur prendra 6 mois et le turnover sera massif à cause de la friction cognitive.

## Ce que nous attendons de votre Guideline

Veuillez concevoir l'expérience de développement interne :

1. **L'Environnement de Développement Local (Inner Loop) :**
   - Spécification de l'environnement de travail du développeur (DevContainer, Nix shell, ou Codespaces). Un développeur doit pouvoir faire "git clone" puis taper une seule commande pour que tout le système (Rust, Java AOT, Elixir, Postgres) tourne en local sur sa machine en moins de 3 minutes.

2. **Documentation As Code et ADRs :**
   - Méthodologie stricte de documentation. Comment tracer les choix architecturaux majeurs (Architecture Decision Records) ?
   - Outils de navigation et de cartographie du code (Codebase Mapping) permettant de comprendre les frontières entre les langages.

3. **Mitigation de la Charge Cognitive :**
   - Comment structurer les monorepos vs polyrepos pour que chaque ingénieur (ex: expert Web) puisse travailler dans sa zone de confort sans être écrasé par la complexité des autres systèmes (ex: les pointeurs C++ du solveur) ?

**Livrable attendu :** Un manuel de Developer Experience (DevEx) détaillant l'Inner Loop de développement, le plan d'onboarding, et les standards de code et de documentation.