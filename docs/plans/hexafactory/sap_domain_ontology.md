# HexaFactory: Domain Ontology (SAP PP/MM Terminology)

*This document captures the manufacturing domain model for HexaFactory, translated into standard SAP Production Planning (PP) and Materials Management (MM) terminology to ensure enterprise-grade interoperability and communication.*

## 1. Enterprise Structure & Supply Chain (Multi-Plant)
*   **Plant (Werke) :** Le réseau comprend ~60 *Plants* distincts (allant de la petite série, c'est-à-dire *Discrete Manufacturing*, jusqu'aux gros volumes, *Repetitive Manufacturing*). Le plus petit Plant comporte ~200 machines, le plus grand ~800 machines.
*   **Company Codes :** La production peut traverser des frontières d'entreprises. Une société gère généralement Fournitures -> T0 -> T1. Les niveaux T2 à T4 appartiennent souvent à d'autres sociétés, bien que certaines maîtrisent la chaîne complète.
*   **Storage Location (Lagerort) :** Nœuds de stockage (stocks tampons) définis au sein des *Plants* pour les matières premières (*ROH*), les en-cours (*HALB*), et les produits finis (*FERT*).
*   **Transit Time / Lead Time (Transportzeit) :** Contrairement au ferroviaire, les temps de transit inter-plants sont des valeurs fixes et déterministes par article. L'assemblage T0/T1 est généralement colocalisé (même Plant). Les Fournitures peuvent provenir d'autres Plants, avec un Lead Time statique.

## 2. Bill of Materials (BOM) & Material Types (T-Levels)
La structure hiérarchique de production (T-levels) se projette sur les **Material Types (MTART)** et la **BOM (Stückliste)** :
*   **Raw Materials (ROH) :** Matières premières de base.
*   **Procured/Subcontracted Components (F Material / Subcontracting) :** Fournitures achetées à l'extérieur ou partiellement sous-traitées.
*   **Semi-Finished Products (HALB) :** 
    *   *Fournitures internes :* Composants usinés en interne depuis des *ROH*. Il y a un fort niveau de réutilisation d'une fourniture à travers plusieurs T1.
    *   *T0 (Sub-assemblies) :* Micro-assemblages de 2 à 6 composants (opérations manuelles ou automatisées).
*   **Finished Products (FERT) :** 
    *   *T1 :* Produit fini pour l'entité locale (assemblage final local d'environ 150 composants distincts).
*   **Extended BOM (T2 / T3 / T4) :** Intégration par des clients internes.
    *   *T2 / T3 :* Niveaux supérieurs d'assemblage.
    *   *T4 :* Étape de *Packaging/Conditioning*.

## 3. Production Routing (Arbeitsplan) & Operations
Le cheminement de fabrication d'une fourniture (5 à 30 opérations) est défini par le **Routing** :
*   **Operations (Vorgänge) :** Les étapes spécifiques (prélèvement, usinage, contrôles QM, emballage).
*   **Alternative Routings (Alternativarbeitspläne) :** Une même pièce peut posséder plusieurs versions de routage :
    *   Gamme 100% interne (In-house production).
    *   Gamme avec opération sous-traitée (*External Processing Operation / Subcontracting*).
    *   Gamme distribuée sur deux *Plants* (Cross-plant routing).
*   **Scrap & Yield (Ausschuss) :** Un facteur critique pour les Fournitures. Le taux de rebut (Scrap Rate) varie de 0% à 30% (moyenne 10%). Cet aléa implique que les ordres de fabrication (Production Orders) doivent souvent être re-planifiés en urgence (*Rush Orders*) pour compenser les pertes et ne pas affamer le niveau T0.

## 4. Work Centers & Capacities (Arbeitsplatz & Kapazität)
L'assignation des opérations se fait sur des ressources capacitaires :
*   **Work Center (Arbeitsplatz) :** L'entité logique cible pour une opération. Peut représenter une machine unique, un groupe de machines identiques, ou une station manuelle.
*   **Machine Types / Equipment :** Regroupés par spécialisation. Un grand Plant peut contenir par exemple : 200 machines de décolletage, 150 machines de taillage pignon, 100 machines de roulage, 100 machines de taillage par paquet.
*   **Machine Equivalence & Cost Rates (Kostenstelle) :** Des machines 100% compatibles peuvent exister dans plusieurs usines. Une machine plus avancée (capable de faire l'opération demandée ET d'autres) a un Taux Horaire (*Activity Rate*) plus élevé. Le solveur a ici un fort potentiel d'optimisation financière : allouer la tâche à la machine la moins coûteuse tout en respectant la *Due Date*.
*   **Capacity Category (Kapazitätsart) :** 
    *   *Machine Capacity* (ex: peut tourner en `24/7` si la matière est chargée).
    *   *Labor/Personnel Capacity* (ex: Spécialiste de réglage limité à des *Shifts* de 8h/jour).

## 5. Setup & Production Times (Vorgabewerte)
Les temps alloués aux opérations sont le cœur de l'optimisation :
*   **Setup Time (Rüstzeit) :** Temps de mise en train critique.
    *   Variable : de 1h (Macro paramétrable) à 40h (Articles complexes).
    *   *Sequence-Dependent Setup Times (Setup Matrix) :* Le solveur devra pré-calculer *proactivement* la matrice de Setup entre l'Article A et l'Article B. Ce calcul est déterministe et dépend du changement de matière (ex: changement de barre), du nettoyage, et du delta de changement d'outils.
*   **Processing Time (Bearbeitungszeit) :** Fortement typé selon l'opération :
    *   *Décolletage :* 20s à 120s par unité (Moyenne 50s). Durée de production typique d'un ordre : 1 semaine.
    *   *Taillage Pignon :* 12s à 20s (Moyenne 12s).
    *   *Roulage :* 5s à 7s (Moyenne 5.5s). Peut être répété 1 à 4 fois selon le nombre de diamètres. L'automate vs chargement manuel influe sur le temps.
    *   *Taillage par Paquet :* 20s à 40s (Moyenne 25s).
    *   *Opérations "Vagues" (Thermique, Polissage, Courtes décolletages) :* Temps unitaire non traçable. On modélise avec une durée fixe de lot (Batch Time) allant d'un demi-jour à 4 jours (Moyenne 1 jour).
*   **Shift Sequence / Factory Calendar (Fabrikkalender) :** Décalage entre le temps "Calendaire" et le temps "Ouvré" : un *Setup* de 40h requiert l'intervention humaine (Personnel Capacity) et prendra 5 jours calendaires (5 shifts de 8h), bloquant la *Machine Capacity* pendant cette durée.

## 6. Optimization Objective
1.  **Priorité 1 (Just-in-Time) :** Tenir les délais (Due Dates / Liefertermine). Le système subit des changements de prévisions client (T1) constants, ce qui force une réactivité extrême tout le long de la Supply Chain (Fournitures). La gestion des aléas (Rebuts) accentue cette urgence.
2.  **Priorité 2 (Cost & Setup Reduction) :** Si les délais sont tenus, le solveur doit minimiser le temps de Setup (optimisation de la séquence via la matrice A->B) et minimiser le coût d'usinage (en privilégiant la machine la moins chère ayant la *Capability* requise).
