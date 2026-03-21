# Mandat d'Architecture : Sous-système Extensibilité Sécurisée et Déploiement

**À l'attention de :** Architecte Principal(e) Cloud, WebAssembly (WASM) & Infrastructure-as-Code  
**Date :** 21 Mars 2026  
**Référentiel Technologique :** État de l'art Février 2026 (WASM multi-cœurs, Extism/Wasmtime, Nix Flakes, Dhall)  
**Projet :** HexaPlanner - Jumeau Numérique pour Job Shop Scheduling et Optimisation Ferroviaire

## Contexte et Vision Stratégique
Notre produit SaaS sera utilisé par des ingénieurs industriels qui possèdent des règles métiers extrêmement pointues (ex: "Si le train transporte du matériel inflammable et que la température extérieure dépasse 30°C, ajouter un délai de sécurité de 5 min au setup"). 
Nous ne pouvons pas intégrer toutes ces règles "en dur" dans le moteur, ni laisser les clients injecter du code Python ou Java arbitraire sur nos clusters pour des raisons de sécurité évidentes.

La solution absolue en 2026 est **WebAssembly (WASM)** côté serveur.

De plus, l'architecture polyglotte du système (Java GraalVM + Rust + Elixir) impose une reproductibilité de build absolue, rendant Docker insuffisant seul.

## Ce que nous attendons de votre Cahier des Charges

Votre mission est de concevoir la couche d'extensibilité et d'infrastructure du projet. Votre document devra spécifier :

1. **Sandboxing et Plugins Client (WASM) :**
   - Conception du moteur d'exécution WASM intégré (via Wasmtime ou Extism) appelé directement par la boucle de score (Rust/Java).
   - Comment un client peut compiler sa fonction de pénalité douanière/ferroviaire en `.wasm` (depuis du Rust, Go ou AssemblyScript), la téléverser, et comment notre système l'exécute en quelques nanosecondes dans une sandbox strictement bornée (en mémoire et en temps CPU).

2. **DSL Declaratif et Configuration Typée :**
   - Remplacement de l'historique configuration XML/JSON d'OptaPlanner par un langage déclaratif évaluable (ex: Dhall, CUE, ou DSL Elixir). Le but est de garantir la validité mathématique de la configuration (vérification de type statique) avant même de lancer le solveur.

3. **Infrastructure-as-Code et Reproductibilité absolue (Nix) :**
   - Définition de l'environnement de compilation "Bit-for-Bit" utilisant **Nix Flakes**.
   - Spécification de la toolchain combinée capable de cross-compiler du Rust FFI, construire l'image native GraalVM, et packager l'application Elixir OTP dans une release immuable, le tout sans dérive d'environnement entre les développeurs et la production.

4. **Edge Computing (Optionnel mais stratégique) :**
   - Analyse de faisabilité pour compiler notre moteur Cœur (Rust) lui-même en WASM afin de l'exécuter directement dans le navigateur du planificateur industriel, soulageant ainsi nos serveurs cloud pour les simulations mineures.

**Livrable attendu :** Un cahier des charges DevOps/SecOps incluant les spécifications des limites de la sandbox WASM, les signatures des modules d'extension, les workflows de déploiement CI/CD sous Nix, et la définition du DSL de configuration.