# Platform Handoff

Date: 2026-04-06
Branch: `feature/phase19-b-asymmetric-connections`
HEAD: `608118ddc`
Remote: `origin/feature/phase19-b-asymmetric-connections`

## Executive Summary

The branch is now in a materially stronger state than at pickup:

- `HexaCore` and `HexaRail` are physically separated at the Rust crate level.
- `HexaFactory` remains operational through the generic core path.
- Rust builds now use a shared workspace root and shared lockfile.
- Operator smoke paths exist and are passing for both railway and manufacturing verticals.

The branch is not "done" in the product sense, but it is now meaningfully closer to the intended platform architecture and substantially easier to continue from without redoing prior separation work.

## What Has Been Delivered

### 1. HexaCore / HexaRail Boundary

- Public Elixir NIF boundary split:
  - `HexaCore.Nif` exposes only generic core entrypoints.
  - `HexaRail.RailwayNif` owns railway-facing operations.
- Rust domain split:
  - generic structs remain in `native/hexacore_engine/src/domain.rs`
  - railway structs moved to `native/hexarail_engine/src/railway_domain.rs`
- Rust NIF split:
  - generic core NIFs live in `native/hexacore_engine/src/lib.rs`
  - railway NIFs live in `native/hexarail_engine/src/railway_nif.rs`
- Railway topology/runtime split:
  - railway runtime lives in `native/hexarail_engine/src/railway_topology.rs`
  - no railway runtime module remains inside the core crate

### 2. Physical Rust Crate Split

- `HexaCore.Native` now loads `native/hexacore_engine`
- `HexaRail.Native` now loads `native/hexarail_engine`
- `hexacore_engine` now acts as both:
  - a Rustler NIF crate for the core
  - a reusable Rust library dependency for the railway vertical
- `hexarail_engine` now depends on `hexacore_engine` as a library

### 3. Shared Rust Workspace

- Shared workspace root exists at `hexarail/native/Cargo.toml`
- Shared lockfile exists at `hexarail/native/Cargo.lock`
- Per-crate `Cargo.lock` files were removed
- Both Rustler modules now compile against a shared absolute `native/target` root
- `.gitignore` now covers nested Rust target artifacts produced by the new layout

### 4. Vertical Runtime Proofs

- `mix hexarail.smoke` is implemented and passing
- `mix hexafactory.smoke` is implemented and passing
- `TwinLive`/engine wiring and railway runtime control are no longer UI-only stubs

### 5. Documentation

Updated architecture/progress documents:

- `README.md`
- `docs/plans/2026-03-25-core-agnostic-refactoring-plan.md`
- `docs/plans/2026-04-02-rust-railway-runtime-boundary-slice.md`
- `docs/plans/2026-04-02-rust-physical-crate-split.md`
- `docs/plans/2026-04-02-rust-workspace-shared-target.md`

## Recent Commits

Most relevant recent commits on this branch:

- `608118ddc` `chore: ignore nested rust target artifacts`
- `c790d97a7` `chore: unify rust workspace and target cache`
- `36f05dbb6` `refactor: split rust core and railway crates`
- `a60a3ff10` `refactor: isolate railway runtime module from core lib`
- `5e2fd5ca3` `refactor: extract railway rust nifs from core lib`
- `a63f2a0ed` `feat: add vertical smoke operators and planning bootstrap`
- `88b112d7d` `refactor: split railway rust structs from hexacore domain`
- `48910064d` `fix: connect twin live actions to engine state and control`

## Fresh Validation Evidence

Last known passing checks on this branch:

- `mix test test/hexacore/rust_workspace_boundary_test.exs`
  - result: `1 test, 0 failures`
- `mix test test/hexacore/domain_boundary_test.exs test/hexacore/problem_contract_test.exs test/hexacore/core_constraints_test.exs test/hexacore/core_solver_test.exs test/hexacore/nif_boundary_test.exs test/hexacore/rust_domain_boundary_test.exs test/hexacore/rust_nif_module_boundary_test.exs test/hexacore/rust_workspace_boundary_test.exs test/solver_nif_test.exs test/solver_integration_test.exs test/hexarail/railway_domain_boundary_test.exs test/hexarail/smoke_test.exs test/chaos_solver_test.exs test/hexaplanner_web/live/twin_live_test.exs test/hexafactory/problem_projection_test.exs test/hexafactory/solver_integration_test.exs test/hexafactory/constraint_interactions_test.exs test/hexafactory/volumetry_smoke_test.exs test/mix/tasks/hexafactory_tasks_test.exs test/mix/tasks/hexafactory_smoke_task_test.exs test/mix/tasks/hexarail_smoke_task_test.exs`
  - result: `31 tests, 0 failures`
- `mix hexarail.smoke --strategy greedy --query-time 150`
  - result: `resolution_status=success trains_impacted=1 delay_added=2060`
- `mix hexafactory.smoke --profile volumetry_smoke --seed 2026 --iterations 64`
  - result: `late_jobs=0 overdue_minutes=0`

## Current Git Reality

At the time of writing:

- branch is pushed to remote
- tracked work for the slices above is committed
- one unrelated untracked file remains outside this handoff scope:
  - `docs/plans/2026-03-26-chaos-director-metrics-hud.md`

## Remaining Risks

### 1. Rustler Build Cost

The workspace and shared `target` reduced fragmentation, but they do not fully eliminate repeated work across the two Rustler compile invocations. The current state is operationally better, not fully optimized.

### 2. Residual Native Surface

`hexarail_engine` still carries some native functions such as railway-side `evaluate_problem/2` and `optimize_problem/3` for compatibility with the NIF surface, even though the public Elixir facade hides them.

### 3. Repository Hygiene

The repository still contains historical/generated artifacts outside the scope of the separation work. That remains a platform hygiene problem and should be addressed explicitly rather than opportunistically.

### 4. Product Completion

Architectural separation is much stronger, but this does not mean:

- `HexaRail` is product-complete
- `HexaFactory` is product-complete
- the platform is fully finalized

This branch is now structurally credible; it is not yet the terminal delivery state of the whole initiative.

## Recommended Next Steps

### Option A. Build-System Tightening

Focus on reducing the remaining Rustler duplicate compile work and stabilizing the native build loop.

### Option B. Repository Hygiene Pass

Clean tracked/generated artifacts and close the remaining "dirty repo" debt so branch state becomes less misleading.

### Option C. Product-Facing Closure

Resume user-visible completion work:

- `HexaRail` runtime/operator closure
- deeper `HexaFactory` execution path and dataset realism
- final documentation consolidation for delivery

## Recommended Order

1. Build-system tightening
2. Repository hygiene pass
3. Product-facing closure

## Files To Read First In A Follow-Up Session

- `README.md`
- `docs/plans/2026-03-25-core-agnostic-refactoring-plan.md`
- `docs/plans/2026-04-02-rust-physical-crate-split.md`
- `docs/plans/2026-04-02-rust-workspace-shared-target.md`
- `hexarail/lib/hexacore/native.ex`
- `hexarail/lib/hexarail/native.ex`
- `hexarail/native/Cargo.toml`
- `hexarail/native/hexacore_engine/Cargo.toml`
- `hexarail/native/hexarail_engine/Cargo.toml`

## Bottom Line

The branch has crossed an important threshold:

- the platform vision is now materially reflected in the Rust/Elixir structure
- the second vertical still works
- the railway showcase still works
- the next work can focus more on finishing and hardening, and less on undoing architectural mixing
