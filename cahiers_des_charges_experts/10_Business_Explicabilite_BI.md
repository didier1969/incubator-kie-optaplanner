# Mandat d'Expertise Métier : Explicabilité (XAI) et Aide à la Décision

**À l'attention de :** Expert(e) Métier en Business Intelligence, Change Management et XAI (Explainable AI)  
**Date :** 21 Mars 2026  
**Projet :** HexaRail - Jumeau Numérique Industriel  
**Objectif :** Définition des exigences fonctionnelles cibles (Business Requirements), indépendamment de l'existant.

## Contexte
Le principal motif d'échec des projets d'optimisation dans l'industrie est le rejet par les utilisateurs finaux face à une "boîte noire" mathématique. Nous devons fournir un système totalement transparent et justifiable.

## Ce que nous attendons de votre Cahier des Charges

Veuillez lister et spécifier les exigences fonctionnelles suivantes :

1. **Explicabilité du Score (Explainability) :**
   - Si le moteur place la tâche A avant la tâche B en créant un "trou" de 2 heures, comment doit-il l'expliquer à l'opérateur en langage naturel ou visuel ?
   - Exigences sur la traçabilité des pénalités (ex: "Ce choix coûte 100€ de pénalité de retard, mais évite 500€ de changement de configuration").

2. **Délégation de Contrôle (Human-in-the-Loop) :**
   - Comment permettre à un utilisateur humain de "forcer" un placement manuellement (épingler une tâche) sur le diagramme de Gantt, et faire en sorte que l'IA optimise le reste autour de cette contrainte humaine non-négociable ?

3. **Tableaux de Bord (Dashboards) et KPIs Métier :**
   - Définition des écrans de contrôle pour les différents personas (Planificateur, Directeur d'usine, DRH). Quels sont les 5 indicateurs macroscopiques vitaux qui définissent la "santé" d'un planning produit ?

**Livrable attendu :** Un document spécifiant l'interface conceptuelle d'aide à la décision, les attentes en matière d'explicabilité de l'IA (Explainable AI) et les règles d'interaction Homme-Machine (Pinning, Forcing).