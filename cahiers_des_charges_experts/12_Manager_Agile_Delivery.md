# Mandat d'Expertise : Stratégie de Delivery et Méthodologie (Agile à l'Échelle)

**À l'attention de :** Lead Delivery Manager / Expert(e) Agile (SAFe / LeSS)  
**Date :** 21 Mars 2026  
**Projet :** HexaRail - Jumeau Numérique Industriel  
**Objectif :** Définir le framework de livraison, la cadence et l'organisation du flux de valeur (Value Stream).

## Contexte
L'ingénierie va regrouper des chercheurs en IA, des développeurs bas-niveau Rust, des experts JVM et des spécialistes web Elixir. Ces profils n'ont pas les mêmes cycles de maturation (la recherche IA prend des semaines, l'UI prend des jours).

## Ce que nous attendons de votre Guideline

Veuillez définir la stratégie de livraison continue :

1. **Synchronisation des Cycles Disparates :**
   - Comment faire travailler ensemble en sprint une équipe de chercheurs (qui entraîne des modèles RL sur GPU) et une équipe produit (qui intègre ces modèles dans un dashboard web) sans que l'un bloque l'autre ?

2. **Gestion des Dépendances Inter-équipes :**
   - L'équipe Rust aura besoin du moteur de Score  pour tester son arbre de recherche. L'équipe Elixir aura besoin du Rust. 
   - Comment organiser la mise à disposition de "Bouchons" (Stubs/Mocks) ou d'interfaces contractuelles (API-First / Contract-Driven Development) ?

3. **Indicateurs de Vélocité (DORA Metrics) :**
   - Quels KPIs d'ingénierie suivre pour s'assurer que le projet ne s'enlise pas dans la complexité technique au détriment de la valeur métier ?

**Livrable attendu :** Un manuel opératoire Agile définissant les rituels de synchronisation inter-domaines, la gestion des dépendances techniques et la stratégie de livraison continue.