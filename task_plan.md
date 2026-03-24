# Task Plan: HexaPlanner Phase 18 (Chaos Engineering & Metaheuristics)

## Goal
Transform HexaPlanner into a Benchmarking Optimization Framework by injecting "Chaos" (timetable perturbations) and resolving conflicts using various strategies (Baseline, Salsa Incremental, Local Search, Global GA).

## Current Status
- [x] Phase 17 (Zero-Copy & Vector Tiling) completed and validated.
- [x] Phase 18 - Phase 1 (Chaos UI) completed and validated.
- [x] Phase 18 - Phase 2 (Scenario A: Greedy Baseline) completed and validated.
- [ ] Phase 18 - Phase 3 (Scenario C: Local Search) in progress.

## Phases

### Phase 1: Chaos Injection UI & Infrastructure (The Judge)
- [x] Define the "Strategy Pattern" for Conflict Resolvers.
- [x] Build the UI panel in LiveView to trigger a "Breakdown" event.
- [x] Build the UI panel to select the resolution strategy.
- [x] Build the UI dashboard to display resolution metrics.
- [x] **TDD**: Write Elixir tests verifying the UI components.

### Phase 2: Scenario A - The "Greedy" Baseline (Rust)
- [x] **TDD (Red)**: Write Rust/Elixir test simulating a conflict and expecting resolution.
- [x] **Implementation (Green)**: Create a `resolve_conflict_greedy` function in Rust.
- [x] Algorithm logic: Find overlapping `CompactEOS` in the STIG. Delay the second train by the overlap duration.
- [x] Connect the NIF to `handle_event("resolve_chaos", ...)` in LiveView.

### Phase 3: Scenario C - Local Search (The 2026 SBB Standard)
- [x] **Plan**: Define `OptModel` for `localsearch` crate.
- [x] **TDD (Red)**: Add `resolve_conflict_local_search` test comparing it favorably to Greedy.
- [x] **Implementation (Green)**: Implement Tabu Search. Find "Blast Zone" trips, create neighborhood moves, evaluate fitness.
- [x] Connect NIF to UI.
- [x] **TDD**: Write tests proving it finds a better solution than Greedy.

### Phase 4: Scenario B & D
- [ ] Future phases for Global GA and OTP Negotiation.

## Notes
- Strict adherence to TDD: Failing test FIRST, then minimal implementation.
- Elixir remains Control Plane, Rust remains Data Plane.
