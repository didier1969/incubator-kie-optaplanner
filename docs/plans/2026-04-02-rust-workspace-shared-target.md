# Rust Workspace And Shared Target

Date: 2026-04-02
Branch: `feature/phase19-b-asymmetric-connections`

## Decision

After the physical split into `hexacore_engine` and `hexarail_engine`, introduce a shared Cargo workspace and a shared Rustler target directory so the split does not leave the build graph fragmented.

## What Changed

- Added `hexarail/native/Cargo.toml` as the workspace root.
- Generated `hexarail/native/Cargo.lock` as the single lockfile for both crates.
- Removed crate-local lockfiles from:
  - `hexarail/native/hexacore_engine/Cargo.lock`
  - `hexarail/native/hexarail_engine/Cargo.lock`
- Updated:
  - [native.ex](/home/dstadel/projects/incubator-kie-optaplanner/hexarail/lib/hexacore/native.ex)
  - [native.ex](/home/dstadel/projects/incubator-kie-optaplanner/hexarail/lib/hexarail/native.ex)
  so both Rustler modules compile into the same absolute `native/target` directory.
- Added [rust_workspace_boundary_test.exs](/home/dstadel/projects/incubator-kie-optaplanner/hexarail/test/hexacore/rust_workspace_boundary_test.exs) to protect:
  - workspace root presence
  - shared lockfile presence
  - absence of member lockfiles
  - shared Rustler target directory configuration

## Why

The physical crate split solved the architectural boundary, but it left an operational issue:

- two independent lockfiles
- two independent target directories
- more rebuild churn than necessary

This slice restores a single Rust workspace truth while preserving the split between core and railway.

## Validation

- `nix develop -c bash -lc "cd hexarail && mix test test/hexacore/rust_workspace_boundary_test.exs"`
- `nix develop -c bash -lc "cd hexarail && mix test test/hexacore/domain_boundary_test.exs test/hexacore/problem_contract_test.exs test/hexacore/core_constraints_test.exs test/hexacore/core_solver_test.exs test/hexacore/nif_boundary_test.exs test/hexacore/rust_domain_boundary_test.exs test/hexacore/rust_nif_module_boundary_test.exs test/hexacore/rust_workspace_boundary_test.exs test/solver_nif_test.exs test/solver_integration_test.exs test/hexarail/railway_domain_boundary_test.exs test/hexarail/smoke_test.exs test/chaos_solver_test.exs test/hexaplanner_web/live/twin_live_test.exs test/hexafactory/problem_projection_test.exs test/hexafactory/solver_integration_test.exs test/hexafactory/constraint_interactions_test.exs test/hexafactory/volumetry_smoke_test.exs test/mix/tasks/hexafactory_tasks_test.exs test/mix/tasks/hexafactory_smoke_task_test.exs test/mix/tasks/hexarail_smoke_task_test.exs"`
- `nix develop -c bash -lc "cd hexarail && mix hexarail.smoke --strategy greedy --query-time 150"`
- `nix develop -c bash -lc "cd hexarail && mix hexafactory.smoke --profile volumetry_smoke --seed 2026 --iterations 64"`

## Remaining Debt

- the shared `target` reduces fragmentation, but the two Rustler compile invocations still trigger some repeated work
- a deeper optimization would require either coordinated compilation orchestration or a different Rustler integration strategy
- repository cleanup for historical generated artifacts remains separate from this slice
