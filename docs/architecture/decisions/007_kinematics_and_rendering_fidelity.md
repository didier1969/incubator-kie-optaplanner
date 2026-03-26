# ADR 007: Kinematics and Rendering Fidelity Limits

## Context
Dans le cadre de la Phase 19 (Volumetric Era), nous avons confronté le besoin de fidélité visuelle et physique du Jumeau Numérique (HexaRail) aux limites de performance de la simulation temps réel (60 FPS dans un navigateur web). Les discussions ont porté sur quatre axes de simplification présents dans la V2 initiale : l'élévation procédurale, la courbe de traction linéaire, le dévers théorique (Roll), et l'heuristique de pendulation (Tilting).

## Decision
L'Arbitrage d'Architecture ("Maestria") est le suivant :

1.  **Kinematics - 3-Phase Profile (Validé pour implémentation immédiate)** :
    *   **Décision** : Abandon du modèle de progression linéaire (`progress = t/duration`). Implémentation d'une véritable courbe de traction en 3 phases (Accélération, Croisière, Décélération).
    *   **Contrainte** : Le calcul cinématique (Newtonien) *doit* tenir compte du profil de pente (Pitch) et du poids de la rame pour l'accélération effective.
    *   **Résolution** : Le solveur Rust calculera la vitesse de croisière requise pour respecter le temps de parcours GTFS tout en appliquant les limites physiques de la rame.

2.  **Attitude - Track Cant / Roll (Simplification Acceptée)** :
    *   **Décision** : Le moteur continuera de calculer l'inclinaison latérale (Roll) du train de manière *théorique* basée sur la force centrifuge ($v^2/R$) calculée via la tangente de la courbe.
    *   **Justification** : Injecter le "Dévers" physique réel (l'inclinaison construite du ballast) nécessiterait des données d'infrastructure des CFF qui ne sont pas publiques ou trop lourdes à parser en temps réel. La fidélité visuelle du basculement théorique est jugée suffisante pour la détection de comportement.

3.  **Fleet - Tilting Trains Heuristic (Simplification Acceptée)** :
    *   **Décision** : L'identification des rames pendulaires se fera via une heuristique sur le nom du modèle (ex: contient `ICN`, `Giruno`) pour accorder un bonus de vitesse de 15-20% dans les courbes.
    *   **Justification** : Le dataset GTFS n'expose pas de flag booléen `is_tilting`. En l'absence de base de données de matériel roulant exhaustive interconnectée, cette approximation sémantique est le compromis optimal.

4.  **Geometry - "Serpent" Rendering (Validé et Implémenté)** :
    *   **Décision** : Le rendu par point unique (boîte 3D) est remplacé par un rendu curviligne surlignant la voie physique entre une coordonnée de tête et de queue (`PathLayer`).

## Consequences
- Le moteur Rust (HexaCore) devient un véritable simulateur physique (Solveur Newtonien) et non plus un simple interpolateur horaire.
- La charge de calcul (CPU) de Rust augmentera légèrement (intégration de courbes) mais restera dans le budget des 16ms par frame (60 FPS) grâce au Rust.
- La fidélité visuelle du "Serpent" garantit que la représentation spatiale du train épouse parfaitement le domaine physique de la voie.