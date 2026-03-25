# HexaFactory: Domain Discovery & Constraint Mapping

*Ce document capture la compréhension initiale du modèle de domaine industriel pour le futur projet HexaFactory, extraite des directives de l'architecte.*

## 1. Topologie Réseau & Logistique (Multi-Site)
*   **Empreinte :** ~60 sites de production différents.
*   **Typologie des sites :** Variété allant de la petite série à la production de gros volumes.
*   **Logistique :** Présence de temps de transit non-négligeables entre les sites (le graphe spatial A* de `HexaCore` sera utilisé ici).
*   **Nœuds de Stockage :** Stocks tampons à chaque niveau de la BOM (Matières premières, Fournitures, T0, T1).

## 2. Nomenclature Hiérarchique (BOM - Bill of Materials)
La production est strictement découpée en niveaux de maturité (T-levels) :
*   **Fournitures :** Composants de base. Soit achetés, soit sous-traités, soit usinés en interne depuis la matière première.
*   **T0 (Micro-assemblages) :** Assemblage de 2 à 6 composants (fournitures). Opérations manuelles ou automatisées.
*   **T1 (Assemblage Final Local) :** Produit fini pour l'entité actuelle, composé d'environ 150 composants (T0 + Fournitures).
*   **T2/T3/T4 (Supply Chain Étendue - Clients Internes) :** 
    *   T2 : Assemblage de plusieurs T1 + autres composants.
    *   T3 : Intégration supérieure.
    *   T4 : Emballage et conditionnement final.

## 3. Routage de Production (Manufacturing Routing)
*   **Complexité :** La fabrication d'une fourniture nécessite entre 5 et 30 opérations distinctes (selon la complexité de la pièce).
*   **Variantes (Alternative Routings) :** Une pièce peut avoir plusieurs gammes de fabrication (versions) :
    *   Processus 100% interne.
    *   Processus avec sous-traitance partielle.
    *   Processus découpé sur deux usines différentes.
*   **Séquence Standard :** Prélèvement matière -> Opérations d'usinage -> Contrôles intermédiaires -> Contrôle final -> Emballage.

## 4. Ressources & Capacités (Machines & Work Centers)
*   **Work Center (WC) :** Une opération est assignée à un WC cible idéal. Un WC regroupe une ou plusieurs machines.
*   **Spécialisation des Machines (~10 types) :**
    *   Décolletage
    *   Taillage (ex: en paquets sur planches prédécoupées, avec ou sans trou de maintien. *Contrainte de sous-somption : les machines "avec trou" peuvent faire du "sans trou", mais pas l'inverse*).
    *   Roulage (Peut nécessiter 1 à 4 opérations selon le nombre de diamètres à rouler).
    *   Traitements de surface & Trempe.
*   **Secteurs & Parcs :** L'assignation d'une machine dépend de sa *capabilité* (type, équipements) mais aussi de sa localisation (Secteurs/Parcs spécialisés par type d'article, ex: "Arbres de balancier").

## 5. Contraintes de Temps & Setup (Sequence-Dependent Setup Times)
*   **Mise en train (Setup) :** Temps de configuration critique lors du changement d'article sur une machine.
    *   *Cas favorable :* ~1 heure (Changement de paramètres sur une macro existante).
    *   *Cas critique :* Jusqu'à 40 heures pour des articles complexes.
*   **Calendrier des Ressources (Shift Constraints) :**
    *   *Ressource Humaine (Spécialiste de réglage) :* Ne travaille que 8h/jour. (Un setup de 40h prend donc 5 jours calendaires réels).
    *   *Ressource Machine :* Si le setup est fait et la matière chargée, la machine peut tourner en `24/7` (y compris les week-ends).

## 6. Objectif d'Optimisation
*   **Priorité absolue :** Tenir les délais (Due Dates / Just-in-Time) plutôt que de chercher l'optimisation absolue/théorique de l'utilisation des machines.
