# HexaFactory: Advanced Domain Ontology & Constraint Mapping

*Ce document consolide l'expertise métier fournie par l'architecte pour le vertical HexaFactory. Il définit les contraintes de "Newtonian Reality" pour l'ordonnancement industriel.*

## 1. Ressources Humaines & Compétences (Skills Management)
*   **Matrice de Compétences :** Les opérateurs sont typés par expertise (Décolleteur, Emballeur, Spécialiste Traitement de Surface). 
*   **Contrainte Économique :** Interdiction (ou forte pénalité) d'affecter une ressource à haute valeur ajoutée sur une tâche simple (ex: Décolleteur sur de l'emballage).
*   **Ratio de Surveillance :** En phase de production (hors setup), un opérateur gère un **Parc de 4 à 8 machines**. L'unité de planification humaine est donc le "Parc".
*   **Setup vs Control :** Le personnel de mise en train (Régleur) et le personnel de contrôle final sont des spécialisations distinctes.

## 2. Calendriers & Shifts (Temporal Constraints)
*   **Fermetures Obligatoires :** Intégration des contraintes légales (fermetures cantonales, week-ends en général chômés).
*   **Système d'Équipes (Shifts) :** Certains secteurs critiques tournent en 3x8h (relais de personnel).
*   **Asymétrie Machine/Homme :** Une machine peut tourner 24/7 (week-end inclus) à condition d'avoir été réglée et chargée en matière durant les heures ouvrées du personnel.

## 3. Gestion des Aléas & Maintenance (Chaos Engineering)
*   **Maintenance Mixte :** 
    *   *Préventive :* Arrêts planifiés.
    *   *Curative (Pannes) :* Injection d'aléas de quelques heures à plusieurs semaines.
*   **Mobilité des Actifs :** Possibilité de transférer une machine physiquement d'un site à un autre (avec ou sans ses articles dédiés) pour équilibrer la charge globale du groupe.
*   **Qualité & Réactivité :** Détection précoce des problèmes dimensionnels pour éviter la propagation dans la chaîne. Profondeur de contrôle variable selon les résultats historiques.

## 4. Logistique de Production (Batching & Splitting)
*   **Fractionnement (Splitting) :** Un lot important peut être divisé pour passer sur deux machines en parallèle ou en série.
*   **Batching Complexe (Polissage) :**
    *   Machine à 24 "bouteilles" (postes).
    *   Possibilité de mixer des articles différents mais avec le **même traitement**.
    *   Contraintes de quantités Min/Max strictes par bouteille.
*   **Séquençage (Routing) :** Strictement linéaire et irréversible. Les "Semis" (en-cours complexes type rondelles dorées) retournent au stock avant d'être re-découpés en plus petits batchs pour les opérations finales.

## 5. Algorithmique de Setup (Setup Matrices)
*   **Décolletage :** Basé sur le temps et l'effort humain.
*   **Trempe (Thermique) :** Optimisation par "Montée en Température". Il est physiquement plus rapide de chauffer que de refroidir un four à bande. Le solveur doit donc privilégier les séquences allant du froid vers le chaud pour minimiser les temps d'attente.

## 6. Métriques de Cycle (Processing Times)
*   **Décolletage :** ~50s (20s-120s).
*   **Taillage Pignon :** ~12s (12s-20s).
*   **Roulage :** ~5.5s (5s-7s).
*   **Taillage Paquet :** ~25s (20s-40s).
*   **Opérations Batch (Thermique/Polissage) :** 0.5j à 4j (Moyenne 1j).
