# Réponse à la Demande d'Expertise Métier : Manufacturing & Job Shop Scheduling (JIT)

**De :** Directeur/Directrice des Opérations Industrielles et Supply Chain
**Date :** 22 Mars 2026
**À :** Équipe Projet HexaPlanner
**Sujet :** Spécifications des Exigences Fonctionnelles Cibles pour le Jumeau Numérique Industriel

---

## 1. Le "Just-In-Time" (JIT) et les Pénalités (Earliness / Tardiness)

L'optimisation ne réside plus dans l'occupation maximale des machines, mais dans la synchronisation parfaite des flux. Le système doit minimiser un coût global qui est la somme non linéaire des coûts d'avance et de retard.

**A. Coûts liés à l'avance (Earliness) :**
*   **Coût d'immobilisation financière (WACC) :** Chaque composant produit en avance immobilise du fonds de roulement. La valeur des matières et de la main d'œuvre injectée a un coût du capital (généralement calculé par jour d'avance).
*   **Coût de stockage physique :** Encombrement des en-cours (WIP - Work in Progress) dans l'atelier, nécessitant des surfaces au sol, des racks de stockage temporaires, voire des transferts inter-sites.
*   **Risque d'obsolescence et de dégradation :** Pièces en attente risquant de s'oxyder, de subir des dommages lors des manutentions inutiles ou des modifications d'ingénierie de dernière minute.
*   *Modélisation attendue :* Pénalité unitaire $P_E$ par unité de temps d'avance, qui peut croître de manière exponentielle si la capacité de stockage tampon (buffer) locale est dépassée.

**B. Coûts liés au retard (Tardiness) :**
*   **Pénalités contractuelles clients (SLA) :** Facturation directe par le client pour chaque jour/heure de retard par rapport à la date de livraison confirmée (OTIF - On Time In Full).
*   **Blocage aval (Effet domino) :** Un sous-ensemble en retard paralyse la chaîne d'assemblage finale (idle time), entraînant des coûts de chômage technique ou le recours à des heures supplémentaires majorées pour rattraper le retard.
*   **Fret express :** Obligation d'affréter des transports spéciaux (taxi-colis, fret aérien au lieu de maritime) pour compenser le retard de production.
*   *Modélisation attendue :* Pénalité unitaire $P_T$ par unité de temps de retard, très fortement non linéaire et souvent largement supérieure à $P_E$ ($P_T \gg P_E$).

## 2. Temps de Réglage Dépendant de la Séquence (Sequence-Dependent Setup Times)

Les temps de changement de série (SMED) sont des pertes de capacité sèche. Ils ne sont pas constants mais dépendent de l'état initial (opération $i$) et de l'état final (opération $j$).

**A. Modélisation de la réalité de l'atelier :**
*   Le planificateur doit intégrer une matrice asymétrique de temps de transition $S_{ij}$.
*   Exemples typiques : Température (chauffer prend du temps, refroidir en prend plus ou moins), Couleur (clair vers foncé = rapide ; foncé vers clair = rinçage long), Outillage (changement de matrice d'emboutissage).

**B. Règles de regroupement par lots (Batching) :**
*   **Familles technologiques :** Regrouper les ordres de fabrication (OF) partageant des caractéristiques similaires pour "diluer" le temps de réglage.
*   **Trade-off Batching vs JIT :** Un batch trop grand réduit les temps de setup (efficacité machine) mais génère de l'Earliness pour les premières pièces du lot (qui attendent les dernières) et risque de générer de la Tardiness pour d'autres commandes repoussées.
*   *Modélisation attendue :* Le système doit dynamiquement scinder ou regrouper les OF (Lot Sizing dynamique) en calculant le point d'équilibre entre l'économie de setup et les pénalités JIT.

## 3. Contraintes de Ressources Multiples (Co-dépendance)

Une machine seule ne produit rien. Le goulot d'étranglement (théorie des contraintes) n'est pas toujours la machine principale.

**Spécification de la co-dépendance :**
Pour démarrer, une opération $O_k$ exige simultanément (Logical AND) :
1.  **Machine principale :** ex: Presse à injecter de 500 tonnes.
2.  **Outillage / Gabarit :** ex: Le moule spécifique de la pièce A (qui peut n'exister qu'en un seul exemplaire pour toute l'usine).
3.  **Ressource Humaine Qualifiée :** ex: Un régleur certifié niveau 3 pour la mise en course. L'opérateur peut ensuite surveiller plusieurs machines (ratio homme/machine < 1).
4.  **Matière Première / Composants :** Disponibilité physique de la nomenclature (BOM) à l'instant $t$. Le système doit être synchronisé avec l'ERP/MRP pour connaître l'ETA des approvisionnements.

*Modélisation attendue :* Allocation multi-ressources stricte. Le temps de début au plus tôt d'une opération est le maximum des temps de disponibilité de *toutes* ces ressources requises.

## 4. Maintenance Prédictive et Usure

L'outil de production n'est pas infaillible et sa performance n'est pas statique.

**A. Fenêtres de maintenance préventive :**
*   **Intervalles fixes vs flexibles :** Certaines maintenances (ex: graissage toutes les 1000h de vol) ont une tolérance. Le planificateur doit avoir la liberté de glisser une fenêtre de maintenance de $\pm 10\%$ pour profiter d'un "creux" de charge naturelle (trou dans le planning).
*   **Maintenance opportuniste :** Si une machine tombe en panne, le système doit réévaluer s'il est pertinent d'avancer une maintenance préventive prévue peu après.

**B. Dégradation de la performance (Wear & Tear) :**
*   La vitesse de production (Run Rate) peut baisser à mesure que l'outil s'use (ex: usure d'un outil de coupe réduisant la vitesse d'avance).
*   Le taux de rebut (Scrap Rate) augmente à l'approche de la fin de vie de l'outil.
*   *Modélisation attendue :* Le temps d'exécution d'une tâche n'est pas une constante, mais une fonction qui s'allonge selon la position de la tâche depuis le dernier réglage/maintenance.

---

## LIVRABLE ATTENDU : Fonction d'Objectif Industriel et Contraintes

### Fonction d'Objectif (KPIs à minimiser)

La fonction d'objectif $Z$ (Score à minimiser) est une combinaison pondérée des éléments suivants :

$$ Minimize(Z) = \sum (W_E \cdot Cost_{Earliness}) + \sum (W_T \cdot Cost_{Tardiness}) + \sum (W_S \cdot Time_{Setup}) + \sum (W_M \cdot Cost_{Makespan}) $$

Où :
*   $W_E, W_T, W_S, W_M$ sont des poids de criticité ajustables par la direction selon la stratégie du moment (ex: focus cash-flow ou focus taux de service).
*   La priorité absolue (Hard Constraint déguisée en Soft avec un poids énorme) reste le respect des délais clients critiques ($W_T \gg W_E$).

### Définition Précise des Contraintes Complexes d'Atelier

**Contraintes Fortes (Hard Constraints) - Inviolables :**
1.  **Non-chevauchement multi-ressources :** Deux tâches nécessitant la même instance de n'importe quelle ressource de l'ensemble (Machine, Moule, Opérateur spécifique) ne peuvent se chevaucher dans le temps.
2.  **Précédence stricte (Routing) :** L'opération $B$ ne peut démarrer avant que l'opération $A$ ne soit totalement terminée (et transportée, si temps de transit non nul).
3.  **Disponibilité Matière :** La tâche ne peut débuter avant la date de libération (Release Date) dictée par la réception des composants.

**Contraintes Souples (Soft Constraints) - À optimiser :**
1.  **Minimisation des pénalités JIT (Earliness/Tardiness) :** Aligner la fin de la dernière opération sur la date d'expédition (Due Date).
2.  **Minimisation des temps de changement (Sequence-Dependent Setups) :** Trouver les meilleures séquences pour éviter les nettoyages lourds, tout en respectant les Due Dates.
3.  **Lissage de la charge de travail humaine :** Éviter les pics d'activité nécessitant de l'intérim massif suivi de périodes creuses pour le personnel.
4.  **Glissement intelligent de la maintenance :** Positionner les maintenances dans les temps morts naturels induits par la synchronisation JIT.

*Conclusion : Le planificateur parfait pour l'industrie moderne n'est pas un algorithme d'occupation maximale (Tetris dense), mais un orchestrateur de flux tendant (Tetris aéré et ciblé sur la ligne d'arrivée).*