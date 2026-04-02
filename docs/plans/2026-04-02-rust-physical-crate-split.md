# Rust Physical Crate Split

Date: 2026-04-02
Branch: `feature/phase19-b-asymmetric-connections`

## Decision

Finish the physical Rust split between `HexaCore` and `HexaRail` instead of keeping a single mixed crate with only logical submodules.

## What Changed

- Added `hexarail/lib/hexacore/native.ex` so the agnostic Elixir facade now loads its own crate through `HexaCore.Native`.
- Repointed `hexarail/lib/hexacore/nif.ex` to `HexaCore.Native`.
- Repointed `hexarail/lib/hexarail/native.ex` from `hexacore_engine` to the new `hexarail_engine` crate.
- Created `native/hexarail_engine/` with:
  - `Cargo.toml`
  - `src/lib.rs`
  - `src/railway_domain.rs`
  - `src/railway_nif.rs`
  - `src/railway_topology.rs`
  - railway-specific test modules
- Removed railway structs, railway NIF functions, and railway topology runtime modules from `native/hexacore_engine/src/`.
- Converted `hexacore_engine` into a true reusable library crate as well as a NIF crate by:
  - enabling `crate-type = ["cdylib", "rlib"]`
  - gating `rustler::init!` behind the `nif_exports` feature
  - disabling default features when `hexarail_engine` imports `hexacore_engine`

## Why

The previous state still mixed generic optimization code and railway runtime code inside one physical crate. That contradicted the platform architecture even after the Elixir and module-level boundaries had been improved.

This split restores the intended role separation:

- `hexacore_engine`: generic solver/library/NIF for the agnostic core
- `hexarail_engine`: railway vertical crate consuming the core as a library

## Validation

- `cargo test --manifest-path hexarail/native/hexacore_engine/Cargo.toml --lib -- --nocapture`
- `cargo test --manifest-path hexarail/native/hexarail_engine/Cargo.toml --lib -- --nocapture`
- `nix develop -c bash -lc "cd hexarail && mix test test/hexacore/nif_boundary_test.exs test/hexacore/rust_domain_boundary_test.exs test/hexacore/rust_nif_module_boundary_test.exs"`
- `nix develop -c bash -lc "cd hexarail && mix test test/hexacore/domain_boundary_test.exs test/hexacore/problem_contract_test.exs test/hexacore/core_constraints_test.exs test/hexacore/core_solver_test.exs test/hexacore/nif_boundary_test.exs test/hexacore/rust_domain_boundary_test.exs test/hexacore/rust_nif_module_boundary_test.exs test/solver_nif_test.exs test/solver_integration_test.exs test/hexarail/railway_domain_boundary_test.exs test/hexarail/smoke_test.exs test/chaos_solver_test.exs test/hexaplanner_web/live/twin_live_test.exs test/hexafactory/problem_projection_test.exs test/hexafactory/solver_integration_test.exs test/hexafactory/constraint_interactions_test.exs test/hexafactory/volumetry_smoke_test.exs test/mix/tasks/hexafactory_tasks_test.exs test/mix/tasks/hexafactory_smoke_task_test.exs test/mix/tasks/hexarail_smoke_task_test.exs"`
- `nix develop -c bash -lc "cd hexarail && mix hexarail.smoke --strategy greedy --query-time 150"`
- `nix develop -c bash -lc "cd hexarail && mix hexafactory.smoke --profile volumetry_smoke --seed 2026 --iterations 64"`

## Remaining Debt

- The two crates still compile duplicate dependency graphs because there is no shared Cargo workspace yet.
- `hexarail_engine` still exposes `evaluate_problem/2` and `optimize_problem/3` internally for compatibility with the Rust NIF surface, even though the public Elixir railway facade hides them.
- Historical generated artifacts and tracked machine-specific files remain in the repo outside this slice.
