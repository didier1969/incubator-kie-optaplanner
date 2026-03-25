# Mandat d'Expertise Métier : Planification et Ordonnancement Ferroviaire (Rail Scheduling)

**À l'attention de :** Expert(e) Métier Principal(e) en Opérations Ferroviaires et Transit (ex: SBB/CFF, SNCF, DB)  
**Date :** 21 Mars 2026  
**Projet :** HexaRail - Jumeau Numérique Industriel  
**Objectif :** Définition des exigences fonctionnelles cibles (Business Requirements), indépendamment de l'existant.

## Contexte
Nous concevons un nouveau moteur d'optimisation de classe mondiale. Nous avons besoin de votre expertise terrain pour lister les contraintes et fonctionnalités "métier" absolues requises par un opérateur ferroviaire national pour planifier et réagir en temps réel.

## Ce que nous attendons de votre Cahier des Charges

Veuillez lister et spécifier les exigences fonctionnelles suivantes :

1. **Topologie et Contraintes Physiques :**
   - Comment modéliser fonctionnellement un réseau (voies uniques, voies de croisement, capacité des gares, signalisation et cantons) ?
   - Règles d'incompatibilité matérielle (gabarit, électrification, tonnage).

2. **Temps de Préparation et Dépendances en Cascade :**
   - Règles métiers entourant le retournement d'un train (nettoyage, changement d'équipe, inspections) et les temps de préparation dépendants de la séquence.
   - Comment un retard d'une minute sur le train A doit fonctionnellement impacter le train B sur une voie partagée.

3. **Gestion des Incidents (Disruption Management) :**
   - Exigences fonctionnelles lors d'une crise (ex: arbre sur la voie, panne caténaire). 
   - Que doit produire le système en urgence (ex: annulation partielle, bus de remplacement, reroutage) et quels sont les KPIs d'une "bonne" réparation (minimiser les correspondances manquées vs minimiser les retards globaux) ?

4. **Planification des Équipes (Crew Scheduling) croisée :**
   - Les règles de roulement du personnel roulant et comment elles s'entrelacent avec la disponibilité du matériel.

**Livrable attendu :** Un document d'exigences fonctionnelles détaillant les "règles dures" (interdictions physiques/légales) et les "règles souples" (objectifs de qualité de service) à optimiser dans un contexte ferroviaire.