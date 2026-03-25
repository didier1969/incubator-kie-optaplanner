# Task Plan: HexaRail Phase 18 (Chaos Engineering & Metaheuristics)

## Goal
Transform HexaRail into a Benchmarking Optimization Framework by injecting "Chaos" (timetable perturbations) and resolving conflicts using various strategies (Baseline, Salsa Incremental, Local Search, Global GA).
## Current Status
- [x] Phase 17 (Zero-Copy & Vector Tiling) completed and validated.
- [x] Phase 18 - Phase 1 (Chaos UI) completed and validated.
- [x] Phase 18 - Phase 2 (Scenario A: Greedy Baseline) completed and validated.
- [x] Phase 18 - Phase 3 (Scenario C: Local Search) completed and validated.
- [x] Phase 18 - Phase 4 (Scenario D: Micro-Topology & Inference) in progress.

## Phases

### Phase 1-3: Infrastructure & Baselines
- [x] Chaos Injection UI & Infrastructure.
- [x] Scenario A: Salsa Greedy Baseline.
- [x] Scenario C: Local Search (Tabu/Simulated Annealing).

### Phase 4: Scenario D - Micro-Topology & Inference (The 2026 SBB Standard)
- [x] **Plan**: Design the hybrid OSM-GTFS inference engine.
- [x] **Research**: Study ARNIS repository for high-fidelity Rust OSM parsing techniques.
- [x] **TDD (Red)**: Add test case for a complex station (e.g., Zurich HB) where trains must take specific platform tracks.
- [x] **Implementation (Green)**: 
    - [x] Re-extract full Swiss OSM data (mainlines + yard + sidings).
    - [x] Implement Edge Collapsing (Scenario B) to reduce graph size.
    - [x] Implement Tag-based weighting (Scenario C) for A* routing.
    - [x] Match GTFS stop points to OSM platform polygons.
- [x] **Refactor**: Update `app.js` to render the 150MB micro-topology via PMTiles (Tippecanoe).
- [x] **Validate**: Verify snakes bend perfectly on switches.

## Notes
- Scenario D is the hybrid recommendation for absolute physical fidelity.
- Use `rkyv` or `bincode` to ensure this 150MB topology doesn't slow down the boot sequence.


## Notes
- Strict adherence to TDD: Failing test FIRST, then minimal implementation.
- Elixir remains Control Plane, Rust remains Data Plane.
