# Refactoring Plan: HexaCore vs HexaRail

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

## Phase 4: Re-Integration & TDD
- Fix all failing tests.
- Prove the separation by writing a dummy "Logistics" test that optimizes truck routes using `HexaCore` without touching `HexaRail` railway logic.
