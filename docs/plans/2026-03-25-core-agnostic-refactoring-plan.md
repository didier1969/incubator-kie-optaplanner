# Refactoring Plan: HexaCore vs HexaRail

## Proven Slice (2026-03-30)
- A first API-boundary slice is now proven through a `HexaCore`-only test path.
- `HexaCore.Nif` exposes core-only `evaluate_problem_core/1` and `optimize_problem_core/2`.
- The Rust score/solver kernel no longer depends directly on `NetworkManager`; railway conflict count is now injected from the vertical-backed path.
- This does not yet remove railway loaders from `HexaCore.Nif`, but it proves the first reusable optimization path without GTFS/OSM resource state.

## Proven Slice (2026-03-31)
- `HexaCore` now carries a first generic uplift required by future verticals:
  - generic precedence edges
  - generic availability windows
  - generic release and due dates
  - generic batch keys
- These primitives are proven through:
  - `test/hexacore/problem_contract_test.exs`
  - `test/hexacore/core_constraints_test.exs`
  - Rust unit coverage in `native/hexacore_engine/src/score.rs` and `native/hexacore_engine/src/domain.rs`
- The solve path is still minimal, but the contract is no longer railway-shaped-only.

## Proven Slice (2026-04-01)
- A second vertical now exercises the generic core through a real manufacturing path:
  - deterministic dataset generation
  - persisted planning horizon snapshots
  - `HexaFactory -> HexaCore` projection
  - vertical diagnostics and smoke execution through `mix hexafactory.smoke`
- This replaces the earlier placeholder idea of proving separation with a dummy logistics test.
- The main remaining separation debt is now concentrated in the railway-backed NIF surface and Rust domain/types still hosted under `HexaCore`.

## Proven Slice (2026-04-01, API Boundary Closure)
- The public Elixir NIF boundary is now split in practice:
  - `HexaCore.Nif` exposes only generic core entrypoints
  - `HexaRail.RailwayNif` owns the railway-facing operations
  - `HexaRail.Native` is the internal Rustler bridge that loads the shared crate
- Railway-facing NIF structs exposed back to the BEAM now live under `HexaRail.Domain` instead of `HexaCore.Domain`.
- This removes the railway loaders and topology operations from the public `HexaCore.Nif` surface without yet splitting the Rust crate itself.
- The remaining P0 debt is now lower in the stack:
  - `rustler::init!` and topology still live in `hexacore_engine`
  - GTFS/OSM/fleet/topology Rust types are still compiled inside the core crate
  - `HexaCore.Domain.Job/Resource` still carry Ecto concerns

## Phase 1: Elixir Namespace & Directory Restructuring
- Create `lib/hexacore` to house agnostic components.
- Move `lib/hexarail/dsl`, `lib/hexarail/transpiler`, and `lib/hexarail/domain/job.ex`/`problem.ex` into `lib/hexacore`.
- Rename modules from `HexaRail.Domain.Problem` to `HexaCore.Domain.Problem`.
- Update all aliases in the application.

## Phase 2: Rust Crate Extraction
- Rename `native/hexa_solver` to `native/hexacore_engine`.
- Extract generic `salsa` incremental score, `solver.rs` (metaheuristics), and basic `domain.rs` (Job/Problem) into `native/hexacore_engine`.
- Create a new Rust crate `native/hexarail_vertical` (or keep it in a sub-module of engine for now to avoid complex NIF chaining) that contains `topology.rs`, `osm.rs`, and kinematics.

## Phase 3: Generic NIF Bridge
- Refactor `SolverNif` to `HexaCore.Nif`.
- Expose a generic entity loading function `load_entities/2` instead of hardcoded `load_stops`, `load_trips`, etc.
- Completed in public Elixir API terms through `HexaRail.Native` as the internal bridge and `HexaCore.Nif` as the generic-only facade.

## Phase 4: Re-Integration & TDD
- Fix all failing tests.
- Extend the manufacturing proof and then finish moving railway-specific loaders/types behind a true `HexaRail` facade so that `HexaCore.Nif` exposes only generic optimization entrypoints.
