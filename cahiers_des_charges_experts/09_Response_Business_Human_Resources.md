# Cahier des Charges Fonctionnel : Optimisation des Ressources Humaines & Opérations

**De :** Direction des Ressources Humaines & Opérations Syndicales (DRH-OS)
**Pour :** Équipe Projet HexaRail
**Date :** 21 Mars 2026
**Objet :** Exigences fonctionnelles cibles pour la gestion RH complexe et le Shift Rostering

En tant que Directeur des Ressources Humaines pour les Opérations Industrielles, je vous soumets par la présente le cahier des charges détaillant nos exigences impératives pour le module RH du HexaRail. Notre objectif n'est pas seulement de "placer des noms dans des cases", mais de garantir la continuité opérationnelle tout en respectant scrupuleusement le cadre légal, la sécurité de nos collaborateurs et le climat social. Un algorithme d'optimisation qui ne prend pas en compte l'humain est voué à l'échec sur le terrain.

Voici les exigences fonctionnelles (Business Requirements) réparties en trois axes majeurs.

---

## 1. Législation, Droit du Travail et Conventions Collectives (Contraintes Dures)

Le système doit impérativement modéliser les règles légales comme des **contraintes strictes (Hard Constraints)**. Toute planification violant ces règles doit être bloquée ou déclencher une alerte de niveau critique (N1) avec nécessité de forçage manuel justifié et audité.

### 1.1 Règles Légales Fondamentales (Socle)
*   **Temps de Repos Quotidien :** Minimum légal de 11 heures consécutives entre deux shifts. (Paramétrable selon accords locaux).
*   **Durée Maximale de Travail :** Maximum de 10 heures par jour (extensible à 12h sous conditions strictes de dérogation) et 48 heures par semaine isolée (ou 44 heures en moyenne sur 12 semaines).
*   **Temps de Pause :** Au moins 20 minutes consécutives dès que le temps de travail quotidien atteint 6 heures. Le système doit intégrer ces pauses dans le capacitaire de la ligne.
*   **Jours de Repos Hebdomadaire :** Minimum de 24 heures consécutives additionnées aux 11 heures de repos quotidien (soit 35 heures consécutives de repos minimum par semaine). Au moins un dimanche par mois garanti selon notre accord d'entreprise.

### 1.2 Gestion des Dérogations et Conventions Collectives
*   **Règles de Branche :** Intégration des spécificités de notre convention collective de la métallurgie/industrie : majoration des heures de nuit (21h-6h), primes de panier, et repos compensateurs obligatoires (COR).
*   **Traçabilité des Exceptions :** Le système doit permettre à un manager RH de valider une exception (ex: urgence vitale de production nécessitant un dépassement horaire ponctuel) mais doit historiser la validation, le motif, et calculer automatiquement le repos compensateur équivalent (RCE) à planifier dans les 30 jours suivants.

---

## 2. Matrice de Compétences, Habilitations et Équité (Contraintes Mi-Dures et Souples)

La sécurité industrielle repose sur la validité des habilitations à l'instant T de l'opération. L'acceptabilité sociale du planning repose sur l'équité.

### 2.1 Habilitations Complexes et Expirations (Hard/Medium Constraints)
*   **Validité Temporelle Stricte :** Le système doit interdire l'affectation d'un collaborateur à un poste si son CACES, son habilitation électrique (ex: BR/BC), ou sa visite médicale du travail expire avant ou pendant le shift.
*   **Gestion Prédictive des Recyclages :** (Exemple du permis cariste) : Si une habilitation expire à M+1 et nécessite "X heures supervisées" pour son renouvellement, le système doit automatiquement *forcer* la co-planification de ce collaborateur avec un "Tuteur Habilité" sur un poste adéquat avant la date d'expiration.
*   **Dégradation des Compétences :** Une compétence non pratiquée depuis 6 mois doit nécessiter un "shift de réintégration/supervision" avant d'autoriser à nouveau une affectation en autonomie.

### 2.2 Équité de la Charge de Travail (Fairness - Soft Constraints)
La pénalisation des plannings inéquitables doit être sévère dans la fonction de coût de l'algorithme.
*   **Distribution des Shifts Pénibles :** Équilibrage des shifts de nuit, des week-ends et des jours fériés lissés sur une période glissante de 12 semaines. Un compteur d'équité doit être visible par le collaborateur et le manager.
*   **Tâches Pénibles / Ergonomie :** Un opérateur ne doit pas être affecté à un poste à forte pénibilité ergonomique (ex: port de charge lourde, vibrations) plus de 3 jours consécutifs. Rotation obligatoire (Job Rotation) au sein de la semaine.
*   **Affinités et Binômes :** Possibilité de déclarer des "affinités d'équipe" (binômes performants) ou des "incompatibilités" (conflits relationnels connus des RH) pour influencer (Soft Constraint) la composition des équipes, sans primer sur les règles légales.

---

## 3. Gestion de l'Absentéisme & "Day-of-Operations" (Flux d'Urgence)

C'est ici que le système prouvera sa valeur. La gestion des aléas (ex: appel maladie à 6h00 pour le shift de 7h00) doit suivre un workflow strict, rapide, et financièrement optimisé.

### 3.1 Workflow de Résolution d'Absence de Dernière Minute (H-1)
Le système doit instantanément recalculer le planning et proposer 3 scénarios de résolution au Chef de Quart, classés par pertinence (coût/impact social) :

1.  **Scénario A (Redéploiement Interne - Coût zéro) :**
    *   L'algorithme vérifie si un collaborateur *déjà planifié sur ce même shift* sur un poste non-critique possède l'habilitation pour remplacer l'absent sur le poste critique.
    *   Glissement des tâches : Le poste non-critique est temporairement suspendu ou confié à un opérateur moins qualifié.
2.  **Scénario B (Appel au Volontariat / Astreintes - Surcoût maîtrisé) :**
    *   Identification des collaborateurs *en repos*, possédant la compétence, et dont l'appel ne violera pas les règles de repos quotidien/hebdomadaire.
    *   Fonctionnalité de "Push SMS" intégrée : Envoi automatisé d'une proposition de vacation aux 3 meilleurs candidats (selon compteurs d'équité et temps de trajet). Règle du premier répondant (First-Come, First-Served).
    *   Sollicitation des personnels officiellement en "Astreinte" si le volontariat échoue dans les 15 minutes.
3.  **Scénario C (Intérim / Renfort externe - Coût maximum) :**
    *   Connexion directe à notre pool d'intérimaires qualifiés (API agence).
    *   Dernier recours si les scénarios A et B échouent à H-30 minutes.

### 3.2 Post-Mortem et Réajustement Automatique
*   Lorsqu'un remplacement de dernière minute a lieu (ex: rappel d'un collaborateur en repos), le système doit *immédiatement* recalculer les plannings des jours suivants pour ce collaborateur afin de s'assurer que sa nouvelle durée de travail ne crée pas une violation légale demain ou après-demain (effet domino).
*   En cas d'impact en chaîne inévitable, le système alerte le manager RH avec les propositions d'ajustement préventif.

---
**Conclusion :**
L'outil HexaRail ne doit pas être une "boîte noire". Le planificateur RH doit comprendre pourquoi le système a pris une décision. L'explicabilité des choix (notamment sur l'équité) est le seul moyen de garantir l'acceptation de l'outil par les partenaires sociaux et les syndicats. Je me tiens à votre disposition pour la phase de test des règles d'équité (UAT).