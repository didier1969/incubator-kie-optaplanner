# Mandat d'Expertise Métier : Manufacturing & Job Shop Scheduling (JIT)

**À l'attention de :** Directeur/Directrice des Opérations Industrielles et Supply Chain (Manufacturing / Industrie Lourde)  
**Date :** 21 Mars 2026  
**Projet :** HexaPlanner - Jumeau Numérique Industriel  
**Objectif :** Définition des exigences fonctionnelles cibles (Business Requirements), indépendamment de l'existant.

## Contexte
L'industrie moderne ne cherche plus à produire "le plus vite possible" (Makespan) mais "juste à temps" (Just-In-Time) pour optimiser la trésorerie et la charge machine. Nous avons besoin de vos spécifications métier pour concevoir le planificateur d'usine parfait.

## Ce que nous attendons de votre Cahier des Charges

Veuillez lister et spécifier les exigences fonctionnelles suivantes :

1. **Le "Just-In-Time" et les Pénalités :**
   - Spécification métier des coûts liés à l'avance (Earliness) : coûts de stockage, encombrement de l'atelier, immobilisation du capital.
   - Spécification des coûts liés au retard (Tardiness) : pénalités contractuelles clients, perte de réputation, blocage de la chaîne aval.

2. **Temps de Réglage Dépendant de la Séquence (Setup Times) :**
   - Comment modéliser la réalité de l'atelier (ex: peindre en blanc après noir prend 2 heures de nettoyage, mais noir après blanc prend 10 minutes).
   - Règles sur le regroupement par lots (Batching) pour mutualiser les réglages sans sacrifier les dates de livraison.

3. **Contraintes de Ressources Multiples :**
   - Une opération ne nécessite pas qu'une machine, mais souvent un outillage spécifique (moule), un opérateur qualifié et de la matière première disponible simultanément. Comment spécifier cette co-dépendance ?

4. **Maintenance Prédictive et Usure :**
   - Comment le planning doit-il intégrer les fenêtres de maintenance préventive obligatoires et la dégradation de la performance des machines au fil du temps.

**Livrable attendu :** Un document détaillant la fonction d'objectif industriel (les KPIs à équilibrer) et la définition précise des contraintes d'atelier complexes.