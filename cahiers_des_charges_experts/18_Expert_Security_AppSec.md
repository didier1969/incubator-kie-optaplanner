# Mandat d'Expertise : Sécurité Applicative (AppSec) et DevSecOps

**À l'attention de :** Chief Information Security Officer (CISO) & Head of DevSecOps  
**Date :** 21 Mars 2026  
**Projet :** HexaRail - Jumeau Numérique Industriel  
**Objectif :** Garantir que le moteur, la chaîne d'approvisionnement logicielle et l'environnement d'exécution sont inattaquables par conception (Secure by Design).

## Contexte
Nous développons un logiciel qui va planifier des réseaux ferroviaires nationaux et des usines critiques. Les données ingérées (plans de production, plannings des employés, coûts) sont des secrets industriels majeurs. De plus, nous utilisons du C-FFI (Rust/Java) et évaluons potentiellement des plugins clients via WASM. La surface d'attaque est immense.

## Ce que nous attendons de votre Guideline

1. **Sécurisation de l'Exécution (Runtime Security) :**
   - Sécurisation stricte de la mémoire : isolation des processus Elixir, frontières sécurisées des FFI Java/Rust pour éviter les buffer overflows ou fuites de mémoire.
   - Durcissement (Hardening) de l'environnement WASM utilisé pour l'exécution du code client (Sandboxing absolu, interdiction des appels réseau).

2. **Secure Software Supply Chain (SSSC) :**
   - Prévention des attaques de type "Supply Chain" sur nos dépendances (Crates Rust, Hex packages, Maven artifacts).
   - Génération de SBOM (Software Bill of Materials) et signature cryptographique des binaires construits (via Sigstore/Cosign).

3. **DevSecOps et Tests de Sécurité Continus :**
   - Intégration d'outils SAST (Static Application Security Testing) et DAST (Dynamic Application Security Testing) dans le pipeline CI/CD (ex: Semgrep, Cargo Audit).
   - Méthodologie pour le Fuzzing continu de notre moteur de règles mathématiques pour s'assurer qu'aucune entrée malformée ne puisse faire crasher le système central.

4. **Gestion des Secrets et Conformité :**
   - Stratégie Zero-Trust pour la gestion des accès à la base de données et aux environnements de simulation.

**Livrable attendu :** La Politique de Sécurité Applicative de HexaRail, incluant la matrice des menaces (Threat Model) sur l'architecture hybride et les barrières DevSecOps obligatoires.