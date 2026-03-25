# HexaFactory: Domain Ontology (SAP PP/MM Terminology)

*This document captures the manufacturing domain model for HexaFactory, translated into standard SAP Production Planning (PP) and Materials Management (MM) terminology to ensure enterprise-grade interoperability and communication.*

## 1. Enterprise Structure & Supply Chain (Multi-Plant)
*   **Plant (Werke) :** Le réseau comprend ~60 *Plants* distincts (allant de la petite série, c'est-à-dire *Discrete Manufacturing*, jusqu'aux gros volumes, *Repetitive Manufacturing*).
*   **Storage Location (Lagerort) :** Nœuds de stockage (stocks tampons) définis au sein des *Plants* pour les matières premières (*ROH*), les en-cours (*HALB*), et les produits finis (*FERT*).
*   **Transit Time / Lead Time :** Temps de transfert logistique modélisés entre différents *Plants* (nécessite l'A* de `HexaCore` pour évaluer les *Inter-Plant Transfers*).

## 2. Bill of Materials (BOM) & Material Types (T-Levels)
La structure hiérarchique de production (T-levels) se projette sur les **Material Types (MTART)** et la **BOM (Stückliste)** :
*   **Raw Materials (ROH) :** Matières premières de base.
*   **Procured/Subcontracted Components (F Material / Subcontracting) :** Fournitures achetées à l'extérieur ou partiellement sous-traitées.
*   **Semi-Finished Products (HALB) :** 
    *   *T0 (Sub-assemblies) :* Micro-assemblages de 2 à 6 composants (opérations manuelles ou automatisées).
    *   *Fournitures internes :* Composants usinés en interne depuis des *ROH*.
*   **Finished Products (FERT) :** 
    *   *T1 :* Produit fini pour l'entité locale (assemblage final local d'environ 150 composants).
*   **Extended BOM (T2 / T3 / T4) :** Intégration par des clients internes (autres *Plants* de la même *Company Code*).
    *   *T2 / T3 :* Niveaux supérieurs d'assemblage (*Higher-level HALB* ou *FERT*).
    *   *T4 :* Étape de *Packaging/Conditioning*.

## 3. Production Routing (Arbeitsplan)
Le cheminement de fabrication d'une fourniture (5 à 30 opérations) est défini par le **Routing** :
*   **Operations (Vorgänge) :** Les étapes spécifiques (prélèvement, usinage, contrôles QM - *Quality Management*, emballage).
*   **Alternative Routings (Alternativarbeitspläne) :** Une même pièce peut posséder plusieurs versions de routage :
    *   Gamme 100% interne (In-house production).
    *   Gamme avec opération sous-traitée (*External Processing Operation / Subcontracting*).
    *   Gamme distribuée sur deux *Plants* (Cross-plant routing).

## 4. Work Centers & Capacities (Arbeitsplatz & Kapazität)
L'assignation des opérations se fait sur des ressources capacitaires :
*   **Work Center (Arbeitsplatz) :** L'entité logique cible pour une opération. Peut représenter une machine unique, un groupe de machines identiques, ou une station manuelle.
*   **Machine Types / Equipment :** Regroupés par spécialisation (Décolletage, Taillage, Roulage, Traitement de surface, Trempe).
*   **Capacity Category (Kapazitätsart) :** 
    *   *Machine Capacity* (ex: peut tourner en `24/7` si la matière est chargée).
    *   *Labor/Personnel Capacity* (ex: Spécialiste de réglage limité à des *Shifts* de 8h/jour).
*   **Location/Plant Layout :** Les machines sont regroupées géographiquement ou logiquement en Secteurs/Parcs selon la spécificité de l'article (ex: Parc "Arbres de balancier").

## 5. Setup & Production Times (Vorgabewerte)
Les temps alloués aux opérations sont cruciaux pour l'ordonnancement (Scheduling) :
*   **Setup Time (Rüstzeit) :** Temps de mise en train critique.
    *   Fortement variable : de 1h (Macro paramétrable) à 40h (Articles complexes).
    *   *Sequence-Dependent Setup Times (Setup Matrix) :* Le temps de *Setup* dépend de l'article produit précédemment sur la machine (Sous-somption : une machine de taillage "avec trou" peut absorber un *Routing* pour pièce "sans trou").
*   **Processing Time (Bearbeitungszeit) :** Le temps d'usinage / roulage propre à l'opération.
*   **Shift Sequence / Factory Calendar (Fabrikkalender) :** Décalage entre le temps "Calendaire" et le temps "Ouvré" : un *Setup* de 40h requiert l'intervention humaine (Personnel Capacity) et prendra 5 jours calendaires (5 shifts de 8h), bloquant la *Machine Capacity* pendant cette durée.

## 6. Optimization Objective
*   **Objective Function :** Minimiser le retard par rapport aux **Due Dates (Liefertermine)** ou **Basic Finish Dates**. Le *Just-in-Time* (JIT) prime sur le *Capacity Utilization* absolu (Taux de charge machine ou *OEE* théorique).
