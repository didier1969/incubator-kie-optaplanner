# ADR 008: Kinematic and Terrain Simplifications for Real-time Optimization

## Context
Dans le cadre de la Phase 19-C (Volumetric Era - Unification Martini/DEM), nous avons implémenté un moteur physique Newtonien capable de simuler 2 500 rames en temps réel à 60 FPS. Pour maintenir ce niveau de performance tout en permettant au moteur d'optimisation (Salsa) d'effectuer des calculs prédictifs instantanés (Time Travel), certains compromis d'ingénierie ont été nécessaires.

## Decision
Nous avons validé les quatre simplifications techniques suivantes :

1. **Accélération par Pente Moyenne (Mean Slope Gravity)** :
   * **Description** : L'accélération effective ($a_{eff}$) est calculée en utilisant la différence d'altitude entre le début et la fin d'un segment de trajet pour obtenir une pente moyenne.
   * **Rationale** : Évite le calcul d'une intégrale de pente locale à haute fréquence, préservant le budget CPU pour les algorithmes de recherche opérationnelle.

2. **Proxy Polynomial pour la Cinématique (Smoothstep vs Integration)** :
   * **Description** : Utilisation d'une fonction Smoothstep cubique déformée mathématiquement pour simuler les phases d'accélération, croisière et freinage.
   * **Rationale** : Garantit un calcul de position en $O(1)$ (Stateless), permettant au solveur Salsa d'interroger n'importe quel état futur du réseau sans simuler les étapes intermédiaires.

3. **Écrêtage de Vitesse Linéaire (Linear Speed Clamping)** :
   * **Description** : La vitesse est plafonnée de manière stricte au $V_{max}$ (inférieur de la voie et du matériel). La distance parcourue est tronquée linéairement si l'horaire théorique dépasse cette limite.
   * **Rationale** : Suffisant pour générer des retards organiques réalistes et détecter les horaires physiquement irréalisables sans complexité mathématique excessive.

4. **Résolution du Maillage de Terrain (Martini Error Threshold)** :
   * **Description** : Le paramètre `meshMaxError` de l'algorithme Martini est fixé à 4.0 pour la génération du relief 3D local.
   * **Rationale** : Point d'équilibre optimal entre la fidélité visuelle du relief suisse et la charge GPU, garantissant la fluidité sur des configurations matérielles variées.

## Consequences
- Le système maintient une fluidité de 60 FPS avec 2 500 agents actifs.
- Le moteur de score Salsa peut évaluer des scénarios futurs instantanément.
- Les retards générés par le système sont physiquement cohérents bien que mathématiquement simplifiés.
- Le Jumeau Numérique est prêt pour l'injection de scénarios de crise (Phase 21).
