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
- Railway-facing Elixir tests that were still exercising generic solve/evaluate through `HexaRail.RailwayNif` now call `HexaCore.Nif` directly.
- This removes the railway loaders and topology operations from the public `HexaCore.Nif` surface without yet splitting the Rust crate itself.
- A further core-domain boundary slice is now proven:
  - `HexaCore.Domain.Job` and `HexaCore.Domain.Resource` are plain data structs and no longer export Ecto schema metadata
  - `test/hexacore/domain_boundary_test.exs` now protects that contract explicitly
- The remaining P0 debt is now lower in the stack:
  - `rustler::init!` and topology still live in `hexacore_engine`
  - GTFS/OSM/fleet/topology runtime code is still compiled inside the core crate
  - `HexaCore.Domain.Problem` is clean, but the deeper Rust crate split is still missing

## Proven Slice (2026-04-01, Rust Type Boundary)
- Railway-specific Rust NIF structs now live in `native/hexacore_engine/src/railway_domain.rs`.
- `native/hexacore_engine/src/domain.rs` now carries only the generic problem contract plus shared geospatial primitives.
- This removes `HexaRail.*` Rust structs from the generic Rust domain module without yet splitting the crate or the NIF registration surface.
- The remaining Rust-side debt is now concentrated in:
  - `topology.rs` still living in the same crate as the generic solver

## Proven Slice (2026-04-01, Rust NIF Module Boundary)
- Railway-specific Rust NIF functions now live in `native/hexacore_engine/src/railway_nif.rs`.
- `native/hexacore_engine/src/lib.rs` now keeps only:
  - generic core entrypoints
  - shared resource registration
  - Rustler initialization
- This is still a single crate, but the remaining coupling is now substantially narrower and concentrated in:
  - `topology.rs`
  - the shared `NetworkResource`
  - the single `rustler::init!` surface

## Proven Slice (2026-04-02, Rust Railway Runtime Boundary)
- Railway topology/runtime code now lives in `native/hexacore_engine/src/railway_topology.rs`.
- `NetworkResource` now belongs to `native/hexacore_engine/src/railway_nif.rs` instead of `lib.rs`.
- `native/hexacore_engine/src/lib.rs` now registers the railway resource type but keeps only:
  - generic core entrypoints
  - Rustler initialization
  - module wiring
- The topology unit test has been moved out of the runtime file into `native/hexacore_engine/src/railway_topology_tests.rs`, keeping the railway runtime module free of embedded test scaffolding.
- This reduces the remaining coupling to:
  - a shared Rust crate and `rustler::init!` surface
  - railway runtime modules still compiled alongside the generic solver
  - the missing final physical crate split between core and railway vertical

## Proven Slice (2026-04-02, Rust Physical Crate Split)
- `HexaCore.Native` now loads `native/hexacore_engine`.
- `HexaRail.Native` now loads `native/hexarail_engine`.
- `native/hexacore_engine` is now a core-only crate carrying:
  - generic domain structs
  - incremental score engine
  - generic score logic
  - generic optimize/evaluate/add entrypoints
- `native/hexarail_engine` now carries:
  - `railway_domain.rs`
  - `railway_nif.rs`
  - `railway_topology.rs`
  - railway-specific unit coverage
- `hexacore_engine` now builds as both `cdylib` and `rlib`, with NIF exports gated behind a feature so it can be linked safely as a library by `hexarail_engine`.
- The physical split between core and railway vertical is therefore now real, not only logical.
- The remaining debt is now narrower:
  - dependency compilation is still not fully minimized even with a shared target cache
  - some railway-internal Rust NIFs still exist even when hidden by the public Elixir facade
  - historical generated artifacts in the repo still need cleanup

## Proven Slice (2026-04-02, Rust Workspace And Shared Target)
- Added `native/Cargo.toml` as a shared Cargo workspace for:
  - `hexacore_engine`
  - `hexarail_engine`
- Added `native/Cargo.lock` as the single lockfile for both crates.
- Removed per-crate lockfiles from `native/hexacore_engine/` and `native/hexarail_engine/`.
- `HexaCore.Native` and `HexaRail.Native` now both compile into the same absolute `native/target` directory via Rustler `target_dir`.
- `test/hexacore/rust_workspace_boundary_test.exs` now protects that contract explicitly.
- This does not eliminate all duplicate build work yet, but it converts the multi-crate layout into a real shared Rust workspace with a single lockfile and shared artifact cache root.

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
