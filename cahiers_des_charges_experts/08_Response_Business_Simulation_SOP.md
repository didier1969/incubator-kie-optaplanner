# Cahier des Charges - Exigences Fonctionnelles : HexaRail - Jumeau Numérique Industriel (S&OP)

**De :** Expert Senior S&OP et Jumeaux Numériques
**Date :** 21 Mars 2026
**Projet :** HexaRail - Jumeau Numérique Industriel

---

## 1. Le Processus de Simulation Métier (What-If)

### 1.1 Scénarios Quotidiens de Crise et d'Opportunité
Un planificateur industriel évolue dans un environnement hautement volatile. Le système de simulation "What-If" doit permettre de tester à la volée, de manière isolée (Sandbox), les scénarios suivants sans impacter le plan de production en cours (Live) :

*   **Scénario A : Insertion d'une Commande Urgente (VIP/Premium)**
    *   *Question:* "Si j'accepte cette commande de 500 unités pour le client Top Tiers avec livraison dans 48h, quel est l'impact sur les autres commandes ?"
    *   *Action attendue:* Le système simule l'insertion en forçant la priorité.
    *   *Résultat attendu:* Identification des commandes "victimes" (qui seront retardées), calcul du surcoût lié aux heures supplémentaires potentielles, et faisabilité matérielle.
*   **Scénario B : Aléa Supply Chain (Retard Fournisseur)**
    *   *Question:* "Le composant critique X arrivera avec 3 jours de retard. Quelles lignes de production vont s'arrêter ?"
    *   *Action attendue:* Modification de la date de disponibilité du lot entrant.
    *   *Résultat attendu:* Reprogrammation automatique des Ordres de Fabrication (OF) impactés, identification des temps morts (idle time) générés sur les machines, et proposition de produits de substitution à fabriquer pendant ce temps mort.
*   **Scénario C : Panne Machine (Indisponibilité Ressource)**
    *   *Question:* "La machine principale Y tombe en panne pour 24h. Comment réallouer la charge ?"
    *   *Action attendue:* Rendre la ressource indisponible sur la période donnée.
    *   *Résultat attendu:* Décalage des OF ou réallocation vers des machines de débordement (moins performantes), avec calcul de la perte de rendement (OEE) et de l'impact sur le taux de service client (OTIF).

### 1.2 Comparaison Scénario de Base (Baseline) vs Scénario Simulé (What-If)
Le métier refuse les boîtes noires. La comparaison doit se faire via des tableaux de bord side-by-side et des vues de type "Delta" :

*   **Indicateurs Macro (Direction / S&OP) :**
    *   *Taux de Service Client (OTIF - On Time In Full) :* Variation globale du pourcentage de commandes livrées à temps.
    *   *Marge Opérationnelle brute :* Impact financier (Revenus supplémentaires de la commande VIP moins coûts de retard des autres commandes + heures sup).
    *   *Taux d'utilisation des ressources (OEE) :* Impact global sur la saturation de l'usine.
*   **Indicateurs Micro (Plancher d'Usine / Ordonnanceur) :**
    *   *Nombre d'Ordres de Fabrication (OF) déplacés :* Quantifie la "nervosité" induite par le scénario.
    *   *Delta des temps de setup / changement de série :* Le scénario casse-t-il des campagnes de production optimisées (ex: on passe du blanc au noir, puis retour au blanc, augmentant les temps de nettoyage) ?
    *   *Ruptures de stocks composants projetées :* Visualisation sur timeline de l'impact sur les stocks tampons.

---

## 2. Planification Non-Destructive et Maîtrise de la Nervosité

Le pire ennemi de l'atelier est un planning qui change toutes les heures. L'IA doit respecter la physique et l'humain.

### 2.1 Gel de l'Horizon à Court Terme (Time Fences)
Le système doit supporter des "Time Fences" configurables :
*   **Zone Gelée (Frozen Zone) - [J à J+2] :**
    *   *Règle :* Aucune modification automatique de séquence ou de date n'est autorisée par le solveur. Les composants sont déjà en bord de ligne, les opérateurs sont briefés.
    *   *Exception :* Seul un "Force Override" manuel par le Directeur de Production peut modifier cette zone, nécessitant une justification tracée.
*   **Zone Liquide/Flexible (Slushy/Liquid Zone) - [J+3 à J+14] :**
    *   *Règle :* Le solveur peut réorganiser la séquence pour optimiser globalement, mais sous contrainte de pénalisation des mouvements.

### 2.2 Pénalités de Nervosité (Non-Disruptive Replanning)
Lors d'une replanification (Continuous Planning), l'algorithme doit intégrer des **pénalités de changement** (Change Penalties) par rapport au plan précédent :
*   *Pénalité de changement de machine :* Déplacer un OF d'une Ligne A vers une Ligne B coûte "X points" de pénalité. L'IA ne le fera que si le gain d'optimisation (retard évité) est largement supérieur à X.
*   *Pénalité de décalage temporel :* Avancer ou reculer un OF génère une pénalité proportionnelle au nombre d'heures de décalage.
*   *Sanctuarisation (Locking) :* Le planificateur peut faire un clic droit sur un OF critique et le marquer "Pinned" (Cloué). L'algorithme optimisera tout le reste *autour* de cet OF intouchable.

**KPI de Stabilité attendu :** *Schedule Adherence Index* (Pourcentage du plan exécuté tel qu'il était prévu 48h à l'avance).

---

## 3. Travail Collaboratif et Workflow S&OP

La planification est un consensus entre le Commerce (qui veut tout livrer tout de suite) et la Production (qui veut de la stabilité et du volume). Le Jumeau Numérique doit être la plateforme de ce consensus.

### 3.1 Workflow de validation inter-départementale (Use Case Collaboratif)

1.  **Création du Scénario (Initiateur : Sales Director) :**
    *   Le Directeur Commercial crée une branche (façon Git) "What-If: Intégration Promo Été".
    *   Il injecte 20% de volume supplémentaire sur une famille de produits.
    *   Le système calcule une proposition : l'OTIF commercial est excellent, mais l'usine s'affiche en rouge avec 30% d'heures supplémentaires nécessaires et des temps de maintenance sautés.
2.  **Ajustement et Contre-Proposition (Contributeur : Production Manager) :**
    *   Le Chef de Production ouvre la branche partagée. Il refuse de sauter la maintenance.
    *   Il épingle (Lock) les créneaux de maintenance. Il ré-exécute le solveur.
    *   Le solveur propose une nouvelle solution : on maintient les machines, mais 5% de la promo sera livrée en retard.
3.  **Comité S&OP (Consensus & Merge) :**
    *   Lors de la réunion hebdomadaire S&OP, les deux scénarios sont comparés sur un seul écran (Baseline vs Branch).
    *   Le comité valide le compromis du Chef de Production.
    *   Le planificateur clique sur **"Promote to Live" / "Merge"**. Le scénario simulé devient le nouveau plan de référence poussé vers l'ERP et les terminaux d'atelier (MES).

### 3.2 Gestion des Conflits de Scénarios
*   Si plusieurs planificateurs font des What-If en même temps, le système gère les conflits. Si une ressource est saturée par le Scénario A et le Scénario B, l'intégration des deux nécessitera un "Rebase" (re-calcul complet intégrant les deux hypothèses) pour valider la faisabilité croisée avant de pousser en production.

---
**Conclusion :**
Le Jumeau Numérique HexaRail ne doit pas être un simple optimiseur mathématique abstrait. Il doit agir comme un environnement "Sandbox" d'aide à la décision, hautement collaboratif, qui comprend et respecte la dure réalité du plancher de production (inertie, coûts de changement, limites humaines). L'IA est ici un copilote, le management humain reste le pilote.