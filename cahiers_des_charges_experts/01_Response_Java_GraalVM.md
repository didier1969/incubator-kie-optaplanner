# Document d'Architecture Technique (DAT) : HexaPlanner Score Data Plane

## 1. Introduction
Ce document détaille l'architecture du "Data Plane de Score" pour HexaPlanner, basé sur le cœur incrémental d'OptaPlanner (Constraint Streams) décapité de sa logique de recherche heuristique. Le système est conçu pour une exécution ultra-rapide (AOT via GraalVM) et une interopérabilité Zero-Copy avec un solveur externe (Rust/Elixir) en exploitant les fonctionnalités de pointe de Java 25 (Project Panama).

## 2. Extraction et Isolation du Cœur (Constraint Streams)

### 2.1. Décapitation du Monolithe
Pour isoler le moteur de règles des algorithmes de recherche locale et heuristiques de construction, nous créerons un sous-module "nexusplanner-core-bavet". Ce module n'inclura que :
- L'API Constraint Streams.
- L'implémentation de calcul incrémental Bavet (optimisée pour la compilation AOT par rapport à Drools).
- Les interfaces de définition du `ScoreDirector`.

Les packages liés à `LocalSearch`, `ConstructionHeuristic`, et l'orchestration globale (`SolverManager`) seront complètement purgés du binaire final.

### 2.2. Modèle de Données Immuable et Event Sourcing
Le modèle de données ne sera plus muté directement par des "moves" Java. Nous adopterons une approche de type "Event Sourcing" où l'état initial est chargé une seule fois. Les modifications de la solution (assignments) seront représentées par un flux d'événements (`AssignmentChangedEvent`) provenant du solveur externe (Rust). L'état interne du graphe Bavet se mettra à jour en fonction de ces événements discrets.

## 3. Interopérabilité Native (Zero-Copy) avec Project Panama (Java 25)

### 3.1. Architecture FFI (Foreign Function & Memory API)
L'interaction entre l'orchestrateur Rust et le moteur de calcul de score Java se fera via mémoire partagée (off-heap) en utilisant l'API `java.lang.foreign` (Project Panama, finalisé en Java 25). Aucune sérialisation JSON ou Protobuf ne sera utilisée.

### 3.2. Mapping de la Mémoire Hors-Tas
Le solveur Rust allouera un segment de mémoire contigu (ex: `MemorySegment` mappé via `mmap`) représentant le tableau des affectations courantes (ex: `[TaskID] -> [ResourceID, StartTime]`).
Le moteur Java accédera à ce segment en lecture seule à travers un `Arena` partagé, configuré avec un layout binaire strict (ex: `ValueLayout.JAVA_INT`).

### 3.3. API C-FFI Exposée par Java
Le module Java exposera les fonctions suivantes au solveur externe (compilées en points d'entrée C via l'annotation `@CEntryPoint` de GraalVM) :

```java
import org.graalvm.nativeimage.c.function.CEntryPoint;
import java.lang.foreign.MemorySegment;

public class ScoreFFI {
    
    // Initialisation du réseau Bavet et attachement au segment mémoire partagé
    @CEntryPoint(name = "init_score_director")
    public static long initScoreDirector(long sharedMemoryAddress, long size) { /* ... */ return 0; }

    // Notification d'un delta (un "Move" appliqué par Rust)
    @CEntryPoint(name = "apply_delta")
    public static void applyDelta(int taskId, int newResourceId, int newStartTime) { /* ... */ }

    // Récupération du score actuel calculé incrémentalement
    @CEntryPoint(name = "get_current_score")
    public static long getCurrentScore() { /* ... */ return 0; }
}
```

## 4. Compilation Ahead-of-Time (AOT) avec GraalVM Native Image (2026)

### 4.1. Stratégie GraalVM
Le moteur sera compilé en tant que librairie dynamique (`.so` / `.dll`) ou statique (`.a`) appelable depuis Rust en utilisant GraalVM Native Image 2026. L'objectif est d'éliminer le coût de démarrage de la JVM (Warm-up) et le JIT (Just-in-Time compilation).

### 4.2. Configuration de Build (Scripts Février 2026)
Le processus de build utilisera les optimisations PGO (Profile-Guided Optimizations) pour maximiser le débit du calcul incrémental Bavet, ainsi que le garbage collector "Serial" ou "Epsilon" (si le taux d'allocation est suffisamment maîtrisé via le off-heap) pour minimiser l'empreinte mémoire.

```bash
# Script de build GraalVM 2026
native-image --shared \
  -H:Name=libnexusscore \
  -O3 \
  --pgo=score-evaluation.iprof \
  --gc=epsilon \
  -R:MaxHeapSize=64m \
  -H:+ReportExceptionStackTraces \
  -H:IncludeResources=".*constraint-streams.*" \
  -cp target/nexusplanner-score-core-1.0.0.jar
```
*Objectif visé :* Démarrage en < 10ms, consommation RAM < 30 Mo.

## 5. Modélisation du Just-In-Time et Setup Times

### 5.1. Gestion des Variables "Shadow"
Dans le contexte "Just-In-Time", les dates de début (`startTime`) et de fin (`endTime`) des tâches, ainsi que les pénalités d'avance/retard, dépendent directement de la séquence d'exécution sur une ressource.
Nous utiliserons des Variables Shadow (Mise à jour automatique par Listener) optimisées pour ne pas traverser le JNI. Le solveur Rust ne modifiera que les variables de planification (la séquence). Le moteur Java recalculera les variables Shadow (dates de début, temps de setup) en interne de manière incrémentale à chaque `applyDelta`.

### 5.2. Flux de Contraintes (Sequence-dependent setup times)
Le calcul des temps de préparation dépendants de la séquence sera modélisé via des Constraint Streams exploitant la jointure consécutive des tâches sur une même ressource :

```java
public Constraint setupTimePenalty(ConstraintFactory factory) {
    return factory.forEach(TaskAssignment.class)
        .join(TaskAssignment.class,
            Joiners.equal(TaskAssignment::getResource),
            Joiners.lessThan(TaskAssignment::getEndTime, TaskAssignment::getStartTime))
        // Filtrage pour ne garder que les tâches adjacentes
        .filter((task1, task2) -> isConsecutive(task1, task2))
        .penalize("Sequence Dependent Setup Time",
            HardSoftScore.ONE_SOFT,
            (task1, task2) -> calculateSetupTime(task1.getTaskType(), task2.getTaskType()));
}
```
L'utilisation de structures d'indexation persistantes dans Bavet garantira que seules les paires de tâches affectées par le delta (modification de l'ordre) seront réévaluées, maintenant une complexité de calcul O(1) par événement.
