# Réponse de l'Expert Métier : Explicabilité (XAI) et Aide à la Décision

**De :** Expert(e) Senior en XAI, Business Intelligence & Change Management  
**À l'attention de :** Équipe Projet HexaPlanner  
**Date :** 21 Mars 2026  
**Sujet :** Exigences fonctionnelles cibles pour la transparence, l'interaction Homme-Machine et le pilotage de la performance

En tant qu'expert XAI et Change Management, mon constat est clair : un système d'optimisation sans confiance est un système non utilisé. L'adoption par les utilisateurs métier (planificateurs, opérateurs) dépend intégralement de la capacité de l'IA à justifier ses choix de manière pragmatique, compréhensible et actionnable. L'approche n'est pas de remplacer l'humain, mais de lui fournir un "exosquelette cognitif".

Voici le cahier des charges des exigences fonctionnelles cibles.

---

## 1. Explicabilité du Score (Explainability)

L'IA doit quitter le paradigme de la "boîte noire" pour devenir une "boîte de verre" (Glass-box AI). Chaque décision contre-intuitive de l'optimiseur doit être immédiatement justifiable en langage métier.

### 1.1 Traduction du score en langage naturel (NLG)
- **Exigence :** Le système doit générer des infobulles (tooltips) ou des panneaux latéraux en langage naturel lorsqu'un utilisateur interagit avec un bloc sur le diagramme de Gantt.
- **Exemple de scénario (Trou de 2 heures) :** Lorsqu'un planificateur clique sur un espace vide ou un séquencement atypique (ex: Tâche A avant Tâche B avec un trou de 2h), le système affiche :
  > *"Ce délai de 2h a été inséré volontairement. Placer la Tâche B immédiatement aurait nécessité un changement d'outil coûtant 500€ et 3h de setup. Ce temps d'attente génère une pénalité de 100€, mais fait économiser au global 400€ et 1h de capacité machine."*
- **Justification des arbitrages (Trade-offs) :** Le système doit toujours mettre en évidence le "pourquoi" par la comparaison avec la deuxième meilleure alternative (Counterfactual explanation). *"Si nous n'avions pas fait cela, la conséquence aurait été..."*

### 1.2 Traçabilité visuelle des pénalités
- **Exigence :** Le Gantt interactif doit utiliser une surbrillance colorimétrique (heatmap) pour illustrer la concentration des pénalités (Hard & Soft constraints).
- **Décomposition du score :** Un panneau latéral "Analyse de la tâche" doit décomposer l'impact financier/temps de chaque affectation sous forme de "Waterfall chart" (Graphique en cascade) :
  - Coût de base de la tâche
  - + Pénalité de retard (livraison client)
  - - Bonus d'alignement de configuration
  - = Score net de l'affectation.

---

## 2. Délégation de Contrôle (Human-in-the-Loop)

Le planificateur doit rester le maître absolu du jeu. Le système est un copilote qui propose, mais l'humain dispose toujours du droit de veto.

### 2.1 Le mécanisme de "Pinning" (Épinglage interactif)
- **Exigence :** L'interface Gantt doit posséder une fonctionnalité de verrouillage visuel (icône de cadenas ou "pin").
- **Fonctionnement :** L'utilisateur peut faire un glisser-déposer (drag & drop) d'une tâche à un instant T sur une machine M, puis cliquer sur "Épingler".
- **Comportement de l'IA :** Cette action transforme instantanément la position de cette tâche en *Hard Constraint* (Contrainte stricte) inaltérable. Lors de la ré-optimisation ("Re-plan around me"), le moteur gèle cette tâche et recalcule en temps réel l'ensemble du planning autour d'elle pour minimiser l'effet domino.

### 2.2 Mode Simulation (What-If Scenarios)
- **Exigence :** Le planificateur ne doit pas "casser" la production réelle en testant des hypothèses.
- **Fonctionnement :** Création d'un mode "Sandbox" (Bac à sable) ou "Brouillon". L'utilisateur peut forcer des placements (overrides), voir instantanément l'impact sur le score global (ex: "Attention, forcer cette commande urgente entraîne 3 retards critiques ailleurs"), et comparer ce scénario alternatif avec le plan initial avant de valider et de "publier" le planning.

---

## 3. Tableaux de Bord (Dashboards) et KPIs Métier

La "santé" d'un planning se mesure différemment selon le persona. L'interface doit proposer des vues macroscopiques basées sur des KPIs vitaux.

### 3.1 Profils et Vues Spécifiques
- **Planificateur (Vue Tactique/Opérationnelle) :** Focus sur la faisabilité, les goulots d'étranglement et la résolution d'exceptions.
- **Directeur d'Usine (Vue Stratégique/Rentabilité) :** Focus sur le TRS (Taux de Rendement Synthétique), les coûts opérationnels et les marges.
- **DRH / Responsable d'Équipe (Vue Humaine/Sociale) :** Focus sur l'équité, la charge cognitive et le respect des contraintes légales/RSE.

### 3.2 Les 5 Indicateurs Macroscopiques Vitaux (Le "Health Check" du Planning)
Pour définir la robustesse et la qualité d'un planning produit, le tableau de bord global doit exposer ces 5 KPIs :

1. **OTIF (On-Time In-Full) Projeté :** Le pourcentage de commandes qui seront livrées à l'heure et complètes selon ce planning. C'est le juge de paix de la satisfaction client.
2. **Taux de Saturation des Goulets d'Étranglement :** L'utilisation réelle des ressources critiques (machines ou compétences rares). Un taux de 100% sur un goulet est excellent, mais un taux de 100% partout indique une absence de marge de manœuvre (risque systémique élevé).
3. **Coût d'Inefficacité (Waste Cost) :** La monétisation globale des temps morts (idle time), des temps de changement de série (setup times) et des pénalités de retard. Ce KPI traduit mathématiquement l'impact du désoptimisé.
4. **Indice de Résilience (Robustness Score) :** Une mesure de la sensibilité du planning aux aléas. "Combien de retard une machine peut-elle prendre avant d'impacter le chemin critique ?" Plus le planning est serré, plus sa résilience est faible.
5. **Indicateur de Charge Humaine (Human Burnout Risk) :** Mesure des heures supplémentaires prévues, du respect strict des repos légaux, et de l'équité de répartition des tâches pénibles entre les opérateurs.

---

## Conclusion & Change Management

L'intégration de la XAI dans HexaPlanner doit s'accompagner d'un plan de conduite du changement :
- **Formation par le jeu :** Utiliser le mode "What-If" en formation pour que les planificateurs essaient de "battre l'IA", réalisant ainsi par eux-mêmes l'équilibre subtil trouvé par le moteur.
- **Feedback Loop :** Intégrer un bouton "Signaler une aberration" (Pouce rouge) sur les choix de l'IA, permettant aux experts métier d'enrichir la base de règles (capture des contraintes tacites non modélisées).

Un système explicable, interactif et centré sur l'humain garantira non seulement l'adoption, mais transformera HexaPlanner en un véritable avantage concurrentiel durable.
