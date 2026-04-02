# Rust Railway Runtime Boundary Slice

Date: 2026-04-02
Branch: `feature/phase19-b-asymmetric-connections`

## Decision

Push the Rust-side `HexaCore` / `HexaRail` boundary one level deeper without attempting the final physical crate split yet.

## What Changed

- Moved the railway runtime module from `native/hexacore_engine/src/topology.rs` to `native/hexacore_engine/src/railway_topology.rs`.
- Moved `NetworkResource` ownership from `native/hexacore_engine/src/lib.rs` to `native/hexacore_engine/src/railway_nif.rs`.
- Kept `native/hexacore_engine/src/lib.rs` focused on:
  - generic core entrypoints
  - module declarations
  - `rustler::init!`
  - railway resource registration only
- Moved the unit test for the railway topology runtime into `native/hexacore_engine/src/railway_topology_tests.rs` so the runtime file no longer embeds `mod tests`.

## Why

The previous slice split railway data types and railway NIF functions, but `lib.rs` still directly owned a railway resource and directly referenced the railway runtime module. That meant the generic crate root still encoded part of the vertical runtime contract.

This slice makes the remaining coupling narrower and more explicit:

- generic root: module wiring and core entrypoints
- railway NIF layer: railway resource ownership and BEAM-facing operations
- railway runtime layer: topology, timetable, perturbation, and resolution behavior

## Validation

- `cargo test --manifest-path hexarail/native/hexacore_engine/Cargo.toml --lib -- --nocapture`
- `nix develop -c bash -lc "cd hexarail && mix test test/hexacore/rust_nif_module_boundary_test.exs test/hexacore/nif_boundary_test.exs test/hexarail/railway_domain_boundary_test.exs test/solver_nif_test.exs test/chaos_solver_test.exs test/hexarail/smoke_test.exs test/mix/tasks/hexarail_smoke_task_test.exs"`
- `nix develop -c bash -lc "cd hexarail && mix test test/hexacore/domain_boundary_test.exs test/hexacore/problem_contract_test.exs test/hexacore/core_constraints_test.exs test/hexacore/core_solver_test.exs test/hexacore/nif_boundary_test.exs test/hexacore/rust_domain_boundary_test.exs test/hexacore/rust_nif_module_boundary_test.exs test/solver_nif_test.exs test/solver_integration_test.exs test/hexarail/railway_domain_boundary_test.exs test/hexarail/smoke_test.exs test/chaos_solver_test.exs test/hexaplanner_web/live/twin_live_test.exs test/hexafactory/problem_projection_test.exs test/hexafactory/solver_integration_test.exs test/hexafactory/constraint_interactions_test.exs test/hexafactory/volumetry_smoke_test.exs test/mix/tasks/hexafactory_tasks_test.exs test/mix/tasks/hexafactory_smoke_task_test.exs test/mix/tasks/hexarail_smoke_task_test.exs"`
- `nix develop -c bash -lc "cd hexarail && mix hexarail.smoke --strategy greedy --query-time 150"`
- `nix develop -c bash -lc "cd hexarail && mix hexafactory.smoke --profile volumetry_smoke --seed 2026 --iterations 64"`

## Remaining Debt

- `hexacore_engine` is still a shared crate.
- `rustler::init!` is still single-surface.
- railway runtime code is still compiled alongside the generic core solver.
- the final physical crate split remains the next structural step if we want the architecture to match the long-term target exactly.
