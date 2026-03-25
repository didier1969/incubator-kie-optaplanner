# Spécifications Fonctionnelles Métier : Moteur d'Optimisation Ferroviaire (HexaRail)

**Auteur :** Expert Principal en Opérations Ferroviaires et Transit
**Date :** 21 Mars 2026
**Objet :** Exigences Fonctionnelles Cibles (Business Requirements) pour HexaRail

## Introduction
Ce document définit les exigences fonctionnelles fondamentales pour un système d'ordonnancement et de planification ferroviaire de classe mondiale. En tant qu'opérateur ferroviaire national (type SBB/CFF, SNCF, DB), notre objectif est d'optimiser l'utilisation du réseau et du matériel tout en garantissant un niveau de sécurité absolu et une résilience maximale face aux aléas d'exploitation. Le système doit gérer simultanément des **règles dures (Hard Constraints)**, qui sont non négociables (physique, sécurité, lois), et des **règles souples (Soft Constraints)**, qui définissent la qualité de service et les objectifs d'optimisation.

---

## 1. Topologie et Contraintes Physiques

La modélisation du réseau ne se limite pas à un graphe classique (noeuds et arêtes). Le domaine ferroviaire exige une granularité microscopique et macroscopique.

### 1.1 Modélisation de l'Infrastructure (Réseau et Signalisation)
*   **Voies Uniques et de Croisement :**
    *   *Règle Dure :* La circulation sur une voie unique est strictement alternée ou unidirectionnelle selon le sens de la marche attribué. Tout croisement doit obligatoirement s'effectuer dans une gare ou sur une voie d'évitement dont la longueur utile est strictement supérieure à la longueur totale du train le plus long.
*   **Cantons et Espacement (Headway) :**
    *   *Règle Dure :* Un canton (section de voie entre deux signaux) ne peut être occupé que par un seul train à la fois (principe du block-système). L'espacement temporel et spatial entre deux trains successifs doit respecter les courbes de freinage d'urgence, la vitesse de ligne et les systèmes de signalisation (ex: ETCS Niveau 2/3, KVB).
*   **Capacité des Gares et Nœuds :**
    *   *Règle Dure :* Un quai ou une voie de service a une longueur et une vocation spécifiques (fret, voyageurs). Un train ne peut y stationner que si ses caractéristiques physiques (longueur) et commerciales correspondent à la voie.
    *   *Règle Dure :* L'itinéraire d'entrée et de sortie d'une gare (gestion des bifurcations/cisaillements) bloque temporairement les itinéraires incompatibles (enclenchements).

### 1.2 Incompatibilité Matérielle
*   **Électrification et Alimentation :**
    *   *Règle Dure :* Un engin moteur électrique ne peut être routé que sur des sections de ligne équipées de la caténaire/troisième rail correspondante (ex: 25 kV AC, 1.5 kV DC, 15 kV AC). La présence de matériel bi-mode ou thermique permet de lever cette contrainte.
*   **Gabarit et Tonnage :**
    *   *Règle Dure :* Le gabarit du matériel (hauteur, largeur) doit être strictement inférieur ou égal au gabarit de la ligne (tunnels, ponts, quais).
    *   *Règle Dure :* La charge à l'essieu et le tonnage total remorqué ne doivent pas dépasser les limites admissibles par l'infrastructure (ponts, profil de la voie) et les capacités de traction/freinage de la locomotive.

---

## 2. Temps de Préparation et Dépendances en Cascade

La production ferroviaire est une chaîne industrielle continue où chaque maillon est critique.

### 2.1 Retournement et Temps de Préparation (Turnaround)
*   **Temps Minimum de Retournement :**
    *   *Règle Dure :* À l'arrivée au terminus, un train doit observer un temps minimum avant de repartir dans le sens inverse. Ce temps inclut :
        *   Le changement de cabine par le conducteur.
        *   Les essais de freins obligatoires.
        *   Les inspections de sécurité rapides.
    *   *Règle Souple (Optimisation) :* Le temps alloué pour le nettoyage, l'avitaillement (restauration, eau) et le vidage des sanitaires dépend du type de mission (TGV vs TER) et peut être comprimé en cas de retard, jusqu'à un seuil de dégradation acceptable.

### 2.2 Propagation des Retards et Conflits de Circulation
*   **Effet Domino sur Voies Partagées :**
    *   *Règle Dure :* Si le Train A (retardé) et le Train B (à l'heure) doivent converger sur une voie unique ou un point de cisaillement, le système doit appliquer une règle de priorité stricte.
    *   *Règle Souple :* Minimiser le report de retard. Le système doit anticiper le conflit de circulation à l'avance et évaluer plusieurs scénarios :
        *   Ralentir préventivement le Train B pour économiser l'énergie et éviter l'arrêt complet au signal.
        *   Décaler le croisement à une autre gare (re-routage dynamique).
        *   Modifier l'ordre de priorité en fonction du type de train (un train international de voyageurs prime souvent sur un train de fret local).

---

## 3. Gestion des Incidents (Disruption Management)

Lorsqu'un incident majeur survient, le plan nominal devient caduc. L'objectif passe de "l'optimisation commerciale globale" à la "résilience et retour à la normale au plus vite".

### 3.1 Prise en Compte de la Crise
*   *Règle Dure :* Lorsqu'une zone est déclarée impraticable (arbre sur la voie, rupture de caténaire), le système doit immédiatement geler tous les itinéraires traversant ce tronçon et déclencher des freinages d'urgence pour les trains en approche immédiate.

### 3.2 Stratégies de Remédiation (Disruption Recovery)
Le moteur d'optimisation doit proposer des scénarios de secours dans les 60 secondes.
*   **Reroutage (Re-routing) :** Trouver un itinéraire alternatif, sous réserve de la compatibilité matérielle et de la capacité résiduelle des autres lignes.
*   **Terminus Partiel (Short-turning) :** Arrêter un train avant son terminus prévu, le vider de ses voyageurs et le faire repartir en sens inverse pour maintenir le cadencement sur la portion non touchée du réseau.
*   **Annulation et Remplacement :** Annuler un train et générer automatiquement des besoins en transport de substitution (flotte de bus).

### 3.3 KPIs de Réparation (Objectifs d'Optimisation)
En situation perturbée, le solveur doit minimiser une fonction de coût pondérée :
1.  *Priorité 1 (Sécurité) :* Zéro violation d'espacement et de compatibilité.
2.  *Priorité 2 (Impact Voyageur) :* Minimiser les **correspondances critiques manquées**. Il est préférable d'avoir 3 trains en retard de 5 minutes plutôt qu'un seul train en retard de 60 minutes avec rupture de la chaîne de correspondances (hub and spoke).
3.  *Priorité 3 (Stabilité de la grille) :* Minimiser l'écart (déviations) avec le plan nominal pour éviter de propager le désordre aux autres régions.

---

## 4. Planification des Équipes (Crew Scheduling) croisée

Le matériel roulant ne fonctionne pas sans personnel qualifié. La planification des équipages (Crew Rostering) est le goulot d'étranglement de toute réorganisation.

### 4.1 Entrelacement Personnel / Matériel
*   **Qualifications et Connaissance de Ligne :**
    *   *Règle Dure :* Un conducteur ne peut conduire que le type exact de matériel pour lequel il est habilité (ex: TGV Duplex, BB 27000).
    *   *Règle Dure :* Un conducteur doit posséder la "connaissance de ligne" certifiée pour l'itinéraire emprunté, y compris les itinéraires de déviation (reroutage). S'il ne l'a pas, l'autorisation de rouler est nulle, ou nécessite l'ajout d'un agent d'accompagnement qualifié ("pilote").

### 4.2 Législation du Travail
*   *Règles Dures :*
    *   Temps de conduite continu maximum avant une pause obligatoire.
    *   Amplitude horaire journalière maximale.
    *   Temps de repos minimal entre deux vacations.
*   *Gestion en Temps Réel :* En cas de retard, si la fin de service estimée d'un conducteur dépasse son amplitude légale, le système doit immédiatement chercher un conducteur de remplacement à une gare intermédiaire de relève, ou, à défaut, annuler/retarder le train.

### 4.3 Logistique des Équipages
*   *Règle Souple :* Minimiser les "Haut-Le-Pied" (Deadheading). C'est-à-dire minimiser le temps de trajet des équipes qui se déplacent en tant que passagers (ou en taxi) pour aller prendre leur service ou rentrer à leur base d'attachement.

---
**Conclusion :** 
Le moteur HexaRail doit fondamentalement séparer le graphe de l'infrastructure physique du graphe des missions commerciales, et faire le lien via les ressources contraintes (trains, personnel, créneaux horaires/sillons). L'aptitude à réévaluer instantanément les correspondances et la législation des équipes lors d'un incident fera la différence entre un planificateur théorique et un véritable jumeau numérique opérationnel.