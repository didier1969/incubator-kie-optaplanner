# HexaFactory First Lot Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build the first full-scope `HexaFactory` vertical as production code, designed for the target industrial volumetry from day one, while keeping a strict generic boundary with `HexaCore`.

**Architecture:** Extend `HexaCore` only with reusable scheduling primitives such as precedence, windows, generic score metadata, and blackout intervals. Implement the manufacturing-specific domain, persistence, generator, adapter, and solver facade under `HexaFactory.*`, then prove the whole flow through deterministic integration tests and reduced-volume volumetry tests that exercise the same production paths.

**Tech Stack:** Elixir 1.16, Ecto/PostgreSQL, Phoenix app structure, Rustler 0.35, Rust 2021, current `hexacore_engine` NIF crate, Nix/Devenv shell.

---

## Implemented Slices

- Tasks 1 and 2 are implemented: `HexaCore` now carries generic precedence, windows, release/due dates, and core constraint scoring.
- Task 3 is implemented: `HexaFactory` foundation schemas and migration exist.
- Task 4 is implemented: `HexaFactory` planning schemas and migration exist.
- Task 5 is implemented: the deterministic industrial generator exists, and `generator_invariants_test.exs` now proves the per-plant machine volumetry promised by the dataset profile.
- Task 6 is implemented: planning horizon snapshot persistence and reload are covered by `persisted_dataset_test.exs`.
- Task 7 is implemented: the `HexaFactory -> HexaCore` projection layer is covered by `problem_projection_test.exs`.
- Task 8 is implemented: the vertical solver facade, decoder, and diagnostics are covered by `solver_integration_test.exs`.
- Task 9 is implemented in its first vertical-facing form: `HexaFactory.Constraints.*` now produces due-date, setup, machine-cost, transfer, buffer, maintenance, labor, batching, and scrap diagnostics, covered by `constraint_interactions_test.exs`.
- Task 10 is implemented in operator-facing form: `mix hexafactory.generate`, `mix hexafactory.persist`, `mix hexafactory.solve`, and `mix hexafactory.smoke` now exist and are exercised by dedicated Mix task tests plus `volumetry_smoke_test.exs`.

## Current Reality

- The end-to-end reduced-volume path is now real: `generator -> persisted snapshot -> projection -> generic core solve -> HexaFactory-facing diagnostics`.
- The generic `HexaCore` contract exercised by `HexaFactory` is now cleaner as well:
  - `HexaCore.Domain.Job` and `HexaCore.Domain.Resource` are plain structs rather than Ecto schemas
  - `test/hexacore/domain_boundary_test.exs` guards that boundary explicitly
- The current validation scope is green under `nix develop` for:
  - `test/hexacore/core_solver_test.exs`
  - `test/hexacore/problem_contract_test.exs`
  - `test/hexacore/core_constraints_test.exs`
  - `test/hexafactory/foundation_schema_test.exs`
  - `test/hexafactory/planning_schema_test.exs`
  - `test/hexafactory/generator_determinism_test.exs`
  - `test/hexafactory/generator_invariants_test.exs`
  - `test/hexafactory/persisted_dataset_test.exs`
  - `test/hexafactory/problem_projection_test.exs`
  - `test/hexafactory/solver_integration_test.exs`
  - `test/hexafactory/constraint_interactions_test.exs`
  - `test/hexafactory/volumetry_smoke_test.exs`
  - `test/mix/tasks/hexafactory_tasks_test.exs`
  - `test/mix/tasks/hexafactory_smoke_task_test.exs`
- The reduced-volume industrial path is now operator-facing through:
  - `mix hexafactory.generate`
  - `mix hexafactory.persist`
  - `mix hexafactory.solve`
  - `mix hexafactory.smoke`
- Remaining first-lot work is now concentrated on fuller score semantics in the generic solver and then platform closure work on `HexaRail` and the final `HexaCore` boundary cleanup.

## Global Rules

- Every modified code file must start with: `Copyright (c) Didier Stadelmann. All rights reserved.`
- No production code before a failing test.
- Run the smallest failing scope first, then the smallest passing scope, then the broader regression scope.
- Keep `HexaCore` generic. If a type name sounds manufacturing-specific, it belongs in `HexaFactory`.

### Task 1: Prove the Generic `HexaCore` Contract Is Still Too Small

**Files:**
- Create: `hexarail/test/hexacore/problem_contract_test.exs`
- Modify: `hexarail/lib/hexacore/domain/problem.ex`
- Modify: `hexarail/lib/hexacore/domain/job.ex`
- Modify: `hexarail/lib/hexacore/domain/resource.ex`
- Create: `hexarail/lib/hexacore/domain/edge.ex`
- Create: `hexarail/lib/hexacore/domain/window.ex`
- Create: `hexarail/lib/hexacore/domain/score_component.ex`

**Step 1: Write the failing test**

```elixir
defmodule HexaCore.ProblemContractTest do
  use ExUnit.Case, async: true

  alias HexaCore.Domain.{Edge, Job, Problem, Resource, Window}

  test "generic problem can carry precedence, windows, and score metadata" do
    problem = %Problem{
      id: "factory-horizon",
      resources: [
        %Resource{id: 1, name: "machine-1", capacity: 1, availability_windows: [%Window{start_at: 0, end_at: 480}]}
      ],
      jobs: [
        %Job{id: 10, duration: 120, required_resources: [1], release_time: 0, due_time: 240, batch_key: "heat-a"}
      ],
      edges: [
        %Edge{from_job_id: 10, to_job_id: 11, lag: 30, edge_type: :finish_to_start}
      ]
    }

    assert length(problem.edges) == 1
    assert hd(problem.resources).availability_windows != []
    assert hd(problem.jobs).due_time == 240
  end
end
```

**Step 2: Run test to verify it fails**

Run: `cd hexarail && mix test test/hexacore/problem_contract_test.exs`

Expected: FAIL because `Edge`, `Window`, and new generic fields do not exist yet.

**Step 3: Write minimal implementation**

- Add generic `defstruct` or schema-backed fields for:
  - `Problem.edges`
  - `Resource.availability_windows`
  - `Job.release_time`
  - `Job.due_time`
  - `Job.batch_key`
- Create lightweight generic structs:
  - `HexaCore.Domain.Edge`
  - `HexaCore.Domain.Window`
  - `HexaCore.Domain.ScoreComponent`

**Step 4: Run test to verify it passes**

Run: `cd hexarail && mix test test/hexacore/problem_contract_test.exs`

Expected: PASS

**Step 5: Commit**

```bash
git add hexarail/test/hexacore/problem_contract_test.exs hexarail/lib/hexacore/domain/problem.ex hexarail/lib/hexacore/domain/job.ex hexarail/lib/hexacore/domain/resource.ex hexarail/lib/hexacore/domain/edge.ex hexarail/lib/hexacore/domain/window.ex hexarail/lib/hexacore/domain/score_component.ex
git commit -m "feat: extend hexacore generic problem contract"
```

### Task 2: Make the Rust NIF Understand the Generic Core Uplift

**Files:**
- Modify: `hexarail/native/hexacore_engine/src/domain.rs`
- Modify: `hexarail/native/hexacore_engine/src/lib.rs`
- Create: `hexarail/native/hexacore_engine/src/generic_constraints.rs`
- Create: `hexarail/test/hexacore/core_constraints_test.exs`
- Modify: `hexarail/test/hexacore/core_solver_test.exs`

**Step 1: Write the failing test**

```elixir
test "core evaluation penalizes generic precedence and blackout violations" do
  problem = %HexaCore.Domain.Problem{
    id: "core-generic",
    resources: [
      %HexaCore.Domain.Resource{id: 1, name: "machine-1", capacity: 1, availability_windows: [%HexaCore.Domain.Window{start_at: 0, end_at: 60}]}
    ],
    jobs: [
      %HexaCore.Domain.Job{id: 1, duration: 50, required_resources: [1], start_time: 30},
      %HexaCore.Domain.Job{id: 2, duration: 10, required_resources: [1], start_time: 0}
    ],
    edges: [
      %HexaCore.Domain.Edge{from_job_id: 1, to_job_id: 2, lag: 0, edge_type: :finish_to_start}
    ]
  }

  assert HexaCore.Nif.evaluate_problem_core(problem) < 0
end
```

**Step 2: Run test to verify it fails**

Run: `cd hexarail && mix test test/hexacore/core_constraints_test.exs`

Expected: FAIL because Rust structs and score logic still ignore the new generic fields.

**Step 3: Write minimal implementation**

- Mirror the new generic fields into `domain.rs`
- Add `generic_constraints.rs` to calculate penalties for:
  - precedence violation
  - availability-window violation
  - overdue completion
- Wire the new penalties into `evaluate_problem_core/1`

**Step 4: Run test to verify it passes**

Run: `cd hexarail && mix test test/hexacore/core_constraints_test.exs`

Expected: PASS

**Step 5: Commit**

```bash
git add hexarail/native/hexacore_engine/src/domain.rs hexarail/native/hexacore_engine/src/lib.rs hexarail/native/hexacore_engine/src/generic_constraints.rs hexarail/test/hexacore/core_constraints_test.exs hexarail/test/hexacore/core_solver_test.exs
git commit -m "feat: add generic core scheduling constraints"
```

### Task 3: Create the `HexaFactory` Namespace and Persistence Skeleton

**Files:**
- Create: `hexarail/lib/hexafactory/application.ex`
- Create: `hexarail/lib/hexafactory/repo_bridge.ex`
- Create: `hexarail/lib/hexafactory/domain/company_code.ex`
- Create: `hexarail/lib/hexafactory/domain/plant.ex`
- Create: `hexarail/lib/hexafactory/domain/storage_location.ex`
- Create: `hexarail/lib/hexafactory/domain/material.ex`
- Create: `hexarail/lib/hexafactory/domain/work_center.ex`
- Create: `hexarail/lib/hexafactory/domain/machine.ex`
- Create: `hexarail/lib/hexafactory/domain/skill.ex`
- Create: `hexarail/lib/hexafactory/domain/operator.ex`
- Create: `hexarail/lib/hexafactory/domain/labor_pool.ex`
- Create: `hexarail/lib/hexafactory/domain/tool.ex`
- Create: `hexarail/lib/hexafactory/domain/tool_instance.ex`
- Create: `hexarail/lib/hexafactory/domain/transport_lane.ex`
- Create: `hexarail/priv/repo/migrations/20260331110000_create_hexafactory_foundation_tables.exs`
- Create: `hexarail/test/hexafactory/foundation_schema_test.exs`

**Step 1: Write the failing test**

```elixir
defmodule HexaFactory.FoundationSchemaTest do
  use HexaRail.DataCase, async: true

  alias HexaFactory.Domain.{CompanyCode, Machine, Material, Plant, StorageLocation, Tool, ToolInstance, TransportLane, WorkCenter}

  test "foundation schemas persist the multi-plant manufacturing topology" do
    plant = HexaRail.Repo.insert!(%Plant{code: "PLANT-001", name: "Plant 001", company_code: "CC-01"})
    work_center = HexaRail.Repo.insert!(%WorkCenter{code: "WC-100", plant_id: plant.id, kind: "decolletage"})
    machine = HexaRail.Repo.insert!(%Machine{code: "M-100", plant_id: plant.id, work_center_id: work_center.id, hourly_cost_cents: 12000})

    assert plant.id
    assert machine.work_center_id == work_center.id
  end
end
```

**Step 2: Run test to verify it fails**

Run: `cd hexarail && mix test test/hexafactory/foundation_schema_test.exs`

Expected: FAIL because the namespace, migration, and schemas do not exist.

**Step 3: Write minimal implementation**

- Create the namespace skeleton and foundation migration
- Add Ecto schemas for the core manufacturing topology
- Use `HexaRail.Repo` through `HexaFactory.RepoBridge`

**Step 4: Run test to verify it passes**

Run: `cd hexarail && mix test test/hexafactory/foundation_schema_test.exs`

Expected: PASS

**Step 5: Commit**

```bash
git add hexarail/lib/hexafactory/application.ex hexarail/lib/hexafactory/repo_bridge.ex hexarail/lib/hexafactory/domain/company_code.ex hexarail/lib/hexafactory/domain/plant.ex hexarail/lib/hexafactory/domain/storage_location.ex hexarail/lib/hexafactory/domain/material.ex hexarail/lib/hexafactory/domain/work_center.ex hexarail/lib/hexafactory/domain/machine.ex hexarail/lib/hexafactory/domain/skill.ex hexarail/lib/hexafactory/domain/operator.ex hexarail/lib/hexafactory/domain/labor_pool.ex hexarail/lib/hexafactory/domain/tool.ex hexarail/lib/hexafactory/domain/tool_instance.ex hexarail/lib/hexafactory/domain/transport_lane.ex hexarail/priv/repo/migrations/20260331110000_create_hexafactory_foundation_tables.exs hexarail/test/hexafactory/foundation_schema_test.exs
git commit -m "feat: add hexafactory foundation schemas"
```

### Task 4: Add BOM, Routing, Orders, Setup, Maintenance, Buffers, and Batching Persistence

**Files:**
- Create: `hexarail/lib/hexafactory/domain/bom_item.ex`
- Create: `hexarail/lib/hexafactory/domain/routing.ex`
- Create: `hexarail/lib/hexafactory/domain/routing_operation.ex`
- Create: `hexarail/lib/hexafactory/domain/production_order.ex`
- Create: `hexarail/lib/hexafactory/domain/setup_profile.ex`
- Create: `hexarail/lib/hexafactory/domain/setup_transition.ex`
- Create: `hexarail/lib/hexafactory/domain/maintenance_window.ex`
- Create: `hexarail/lib/hexafactory/domain/buffer.ex`
- Create: `hexarail/lib/hexafactory/domain/batch_policy.ex`
- Create: `hexarail/priv/repo/migrations/20260331113000_create_hexafactory_planning_tables.exs`
- Create: `hexarail/test/hexafactory/planning_schema_test.exs`

**Step 1: Write the failing test**

```elixir
test "planning schemas represent bom, routing, setup, batching, maintenance, and buffers" do
  routing = %HexaFactory.Domain.Routing{code: "R-100", alternative_kind: "cross_plant"}
  operation = %HexaFactory.Domain.RoutingOperation{sequence: 10, operation_kind: "heat_treatment", batchable: true}
  transition = %HexaFactory.Domain.SetupTransition{from_profile_code: "cold", to_profile_code: "hot", duration_minutes: 45}
  buffer = %HexaFactory.Domain.Buffer{code: "BUF-T0-01", capacity_units: 1000}

  assert operation.batchable
  assert transition.duration_minutes == 45
  assert buffer.capacity_units == 1000
end
```

**Step 2: Run test to verify it fails**

Run: `cd hexarail && mix test test/hexafactory/planning_schema_test.exs`

Expected: FAIL because the planning layer schemas do not exist.

**Step 3: Write minimal implementation**

- Add the planning migration
- Implement the missing schemas and associations
- Keep all naming manufacturing-specific inside `HexaFactory`

**Step 4: Run test to verify it passes**

Run: `cd hexarail && mix test test/hexafactory/planning_schema_test.exs`

Expected: PASS

**Step 5: Commit**

```bash
git add hexarail/lib/hexafactory/domain/bom_item.ex hexarail/lib/hexafactory/domain/routing.ex hexarail/lib/hexafactory/domain/routing_operation.ex hexarail/lib/hexafactory/domain/production_order.ex hexarail/lib/hexafactory/domain/setup_profile.ex hexarail/lib/hexafactory/domain/setup_transition.ex hexarail/lib/hexafactory/domain/maintenance_window.ex hexarail/lib/hexafactory/domain/buffer.ex hexarail/lib/hexafactory/domain/batch_policy.ex hexarail/priv/repo/migrations/20260331113000_create_hexafactory_planning_tables.exs hexarail/test/hexafactory/planning_schema_test.exs
git commit -m "feat: add hexafactory planning schemas"
```

### Task 5: Build the Deterministic Industrial Generator

**Files:**
- Create: `hexarail/lib/hexafactory/generator/seed.ex`
- Create: `hexarail/lib/hexafactory/generator/dataset.ex`
- Create: `hexarail/lib/hexafactory/generator/topology_builder.ex`
- Create: `hexarail/lib/hexafactory/generator/materials_builder.ex`
- Create: `hexarail/lib/hexafactory/generator/routing_builder.ex`
- Create: `hexarail/lib/hexafactory/generator/capacity_builder.ex`
- Create: `hexarail/lib/hexafactory/generator/setup_builder.ex`
- Create: `hexarail/lib/hexafactory/generator/orders_builder.ex`
- Create: `hexarail/test/hexafactory/generator_determinism_test.exs`
- Create: `hexarail/test/hexafactory/generator_invariants_test.exs`

**Step 1: Write the failing tests**

```elixir
test "generator is deterministic for the same seed" do
  left = HexaFactory.Generator.Dataset.build(seed: 42, profile: :smoke)
  right = HexaFactory.Generator.Dataset.build(seed: 42, profile: :smoke)

  assert left.signature == right.signature
end

test "generator emits the full industrial feature set" do
  dataset = HexaFactory.Generator.Dataset.build(seed: 42, profile: :smoke)

  assert dataset.plants != []
  assert dataset.bom_items != []
  assert dataset.routing_operations != []
  assert dataset.setup_transitions != []
  assert dataset.maintenance_windows != []
  assert dataset.buffers != []
  assert dataset.batch_policies != []
end
```

**Step 2: Run tests to verify they fail**

Run: `cd hexarail && mix test test/hexafactory/generator_determinism_test.exs test/hexafactory/generator_invariants_test.exs`

Expected: FAIL because the generator does not exist yet.

**Step 3: Write minimal implementation**

- Create a seed wrapper and dataset struct
- Build deterministic generators for:
  - enterprise topology
  - BOM graph
  - routings and operations
  - labor and tool capacities
  - setup transitions
  - maintenance windows
  - buffers
  - batch policies
  - order book

**Step 4: Run tests to verify they pass**

Run: `cd hexarail && mix test test/hexafactory/generator_determinism_test.exs test/hexafactory/generator_invariants_test.exs`

Expected: PASS

**Step 5: Commit**

```bash
git add hexarail/lib/hexafactory/generator/seed.ex hexarail/lib/hexafactory/generator/dataset.ex hexarail/lib/hexafactory/generator/topology_builder.ex hexarail/lib/hexafactory/generator/materials_builder.ex hexarail/lib/hexafactory/generator/routing_builder.ex hexarail/lib/hexafactory/generator/capacity_builder.ex hexarail/lib/hexafactory/generator/setup_builder.ex hexarail/lib/hexafactory/generator/orders_builder.ex hexarail/test/hexafactory/generator_determinism_test.exs hexarail/test/hexafactory/generator_invariants_test.exs
git commit -m "feat: add deterministic hexafactory generator"
```

### Task 6: Persist and Reload a Manufacturing Dataset End-to-End

**Files:**
- Create: `hexarail/lib/hexafactory/ingestion/persisted_dataset.ex`
- Create: `hexarail/test/hexafactory/persisted_dataset_test.exs`

**Step 1: Write the failing test**

```elixir
test "generated dataset can be persisted and reloaded without losing industrial semantics" do
  dataset = HexaFactory.Generator.Dataset.build(seed: 123, profile: :smoke)

  persisted = HexaFactory.Ingestion.PersistedDataset.persist!(dataset)
  reloaded = HexaFactory.Ingestion.PersistedDataset.load!(persisted.horizon_id)

  assert length(reloaded.plants) == length(dataset.plants)
  assert length(reloaded.setup_transitions) == length(dataset.setup_transitions)
  assert length(reloaded.maintenance_windows) == length(dataset.maintenance_windows)
end
```

**Step 2: Run test to verify it fails**

Run: `cd hexarail && mix test test/hexafactory/persisted_dataset_test.exs`

Expected: FAIL because there is no ingestion/persistence orchestration layer yet.

**Step 3: Write minimal implementation**

- Add a persisted dataset service using the new schemas
- Persist master data first, then planning data, then lookup maps
- Reload a planning horizon in a solver-ready shape

**Step 4: Run test to verify it passes**

Run: `cd hexarail && mix test test/hexafactory/persisted_dataset_test.exs`

Expected: PASS

**Step 5: Commit**

```bash
git add hexarail/lib/hexafactory/ingestion/persisted_dataset.ex hexarail/test/hexafactory/persisted_dataset_test.exs
git commit -m "feat: persist and reload hexafactory datasets"
```

### Task 7: Project Manufacturing Reality Into `HexaCore`

**Files:**
- Create: `hexarail/lib/hexafactory/adapter/problem_projection.ex`
- Create: `hexarail/lib/hexafactory/adapter/resource_projection.ex`
- Create: `hexarail/lib/hexafactory/adapter/job_projection.ex`
- Create: `hexarail/lib/hexafactory/adapter/score_projection.ex`
- Create: `hexarail/test/hexafactory/problem_projection_test.exs`

**Step 1: Write the failing test**

```elixir
test "adapter projects machines, labor, tooling, maintenance, buffers, and transfers into a generic core problem" do
  dataset = HexaFactory.Generator.Dataset.build(seed: 7, profile: :smoke)

  problem = HexaFactory.Adapter.ProblemProjection.build(dataset)

  assert %HexaCore.Domain.Problem{} = problem
  assert Enum.any?(problem.resources, &String.starts_with?(&1.name, "machine:"))
  assert Enum.any?(problem.resources, &String.starts_with?(&1.name, "tool:"))
  assert Enum.any?(problem.jobs, &(&1.batch_key != nil))
  assert problem.edges != []
end
```

**Step 2: Run test to verify it fails**

Run: `cd hexarail && mix test test/hexafactory/problem_projection_test.exs`

Expected: FAIL because the projection layer does not exist.

**Step 3: Write minimal implementation**

- Build generic resources for:
  - machines
  - labor pools
  - tools
  - buffers
- Build generic jobs for:
  - setup
  - production
  - transfer
  - maintenance
  - batch operations
- Add generic edges for precedence, lag, transfer, and blackout interactions

**Step 4: Run test to verify it passes**

Run: `cd hexarail && mix test test/hexafactory/problem_projection_test.exs`

Expected: PASS

**Step 5: Commit**

```bash
git add hexarail/lib/hexafactory/adapter/problem_projection.ex hexarail/lib/hexafactory/adapter/resource_projection.ex hexarail/lib/hexafactory/adapter/job_projection.ex hexarail/lib/hexafactory/adapter/score_projection.ex hexarail/test/hexafactory/problem_projection_test.exs
git commit -m "feat: project hexafactory datasets into hexacore"
```

### Task 8: Add the Vertical Solver Facade and Result Decoder

**Files:**
- Create: `hexarail/lib/hexafactory/solver/facade.ex`
- Create: `hexarail/lib/hexafactory/solver/result_decoder.ex`
- Create: `hexarail/lib/hexafactory/solver/diagnostics.ex`
- Create: `hexarail/test/hexafactory/solver_integration_test.exs`

**Step 1: Write the failing test**

```elixir
test "hexafactory solves a reduced industrial horizon through the generic hexacore boundary" do
  dataset = HexaFactory.Generator.Dataset.build(seed: 99, profile: :smoke)

  result = HexaFactory.Solver.Facade.solve(dataset, iterations: 250)

  assert result.score_breakdown.late_jobs >= 0
  assert result.machine_schedules != []
  assert result.transfer_plan != []
  assert result.buffer_diagnostics != []
end
```

**Step 2: Run test to verify it fails**

Run: `cd hexarail && mix test test/hexafactory/solver_integration_test.exs`

Expected: FAIL because the vertical solver facade and decoder do not exist.

**Step 3: Write minimal implementation**

- Call `HexaCore.Nif.evaluate_problem_core/1` and `optimize_problem_core/2`
- Decode the generic result back into manufacturing-facing diagnostics
- Expose machine schedules, labor allocations, setup chains, transfer plan, and score breakdown

**Step 4: Run test to verify it passes**

Run: `cd hexarail && mix test test/hexafactory/solver_integration_test.exs`

Expected: PASS

**Step 5: Commit**

```bash
git add hexarail/lib/hexafactory/solver/facade.ex hexarail/lib/hexafactory/solver/result_decoder.ex hexarail/lib/hexafactory/solver/diagnostics.ex hexarail/test/hexafactory/solver_integration_test.exs
git commit -m "feat: add hexafactory solver facade"
```

### Task 9: Prove the Constraint Interactions That Matter

**Files:**
- Create: `hexarail/test/hexafactory/constraint_interactions_test.exs`
- Modify: `hexarail/lib/hexafactory/constraints/due_date.ex`
- Modify: `hexarail/lib/hexafactory/constraints/setup_sequence.ex`
- Modify: `hexarail/lib/hexafactory/constraints/machine_cost.ex`
- Modify: `hexarail/lib/hexafactory/constraints/labor_skill.ex`
- Modify: `hexarail/lib/hexafactory/constraints/batching.ex`
- Modify: `hexarail/lib/hexafactory/constraints/transfer_batch.ex`
- Modify: `hexarail/lib/hexafactory/constraints/buffer_capacity.ex`
- Modify: `hexarail/lib/hexafactory/constraints/scrap_yield.ex`
- Modify: `hexarail/lib/hexafactory/constraints/maintenance.ex`
- Modify: `hexarail/lib/hexafactory/constraints/transport.ex`

**Step 1: Write the failing test**

```elixir
test "due date dominates cost but compatible setup and batching still improve the selected plan" do
  dataset = HexaFactory.Generator.Dataset.build(seed: 555, profile: :interaction)

  result = HexaFactory.Solver.Facade.solve(dataset, iterations: 400)

  assert result.score_breakdown.overdue_minutes == 0
  assert result.score_breakdown.setup_minutes >= 0
  assert result.score_breakdown.machine_cost_cents >= 0
end
```

**Step 2: Run test to verify it fails**

Run: `cd hexarail && mix test test/hexafactory/constraint_interactions_test.exs`

Expected: FAIL because the score breakdown and constraint layer are incomplete.

**Step 3: Write minimal implementation**

- Add vertical score breakdown logic
- Ensure the result decoder exposes overdue, setup, cost, transfer, buffer, and maintenance diagnostics
- Keep the generic core free of manufacturing names; the vertical maps generic penalties back into manufacturing-facing dimensions

**Step 4: Run test to verify it passes**

Run: `cd hexarail && mix test test/hexafactory/constraint_interactions_test.exs`

Expected: PASS

**Step 5: Commit**

```bash
git add hexarail/test/hexafactory/constraint_interactions_test.exs hexarail/lib/hexafactory/constraints/due_date.ex hexarail/lib/hexafactory/constraints/setup_sequence.ex hexarail/lib/hexafactory/constraints/machine_cost.ex hexarail/lib/hexafactory/constraints/labor_skill.ex hexarail/lib/hexafactory/constraints/batching.ex hexarail/lib/hexafactory/constraints/transfer_batch.ex hexarail/lib/hexafactory/constraints/buffer_capacity.ex hexarail/lib/hexafactory/constraints/scrap_yield.ex hexarail/lib/hexafactory/constraints/maintenance.ex hexarail/lib/hexafactory/constraints/transport.ex
git commit -m "feat: add hexafactory constraint diagnostics"
```

### Task 10: Add Reduced-Volume Volumetry Tests and Full Validation

**Files:**
- Create: `hexarail/test/hexafactory/volumetry_smoke_test.exs`
- Modify: `docs/plans/2026-03-25-core-agnostic-refactoring-plan.md`
- Modify: `README.md`

**Step 1: Write the failing test**

```elixir
test "smoke profile preserves the same production code path under reduced test volumetry" do
  dataset = HexaFactory.Generator.Dataset.build(seed: 1001, profile: :volumetry_smoke)

  result = HexaFactory.Solver.Facade.solve(dataset, iterations: 200)

  assert dataset.metadata.target_topology.plant_count > 1
  assert result.machine_schedules != []
end
```

**Step 2: Run test to verify it fails**

Run: `cd hexarail && mix test test/hexafactory/volumetry_smoke_test.exs`

Expected: FAIL until the smoke profile and metadata exist.

**Step 3: Write minimal implementation**

- Add a reduced-volume but structurally faithful smoke profile
- Update docs to reflect the new vertical reality
- Keep the same generator, persistence, projection, and solver path

**Step 4: Run full validation**

Run: `cd hexarail && mix test test/hexacore/problem_contract_test.exs test/hexacore/core_constraints_test.exs test/hexacore/core_solver_test.exs test/hexafactory/foundation_schema_test.exs test/hexafactory/planning_schema_test.exs test/hexafactory/generator_determinism_test.exs test/hexafactory/generator_invariants_test.exs test/hexafactory/persisted_dataset_test.exs test/hexafactory/problem_projection_test.exs test/hexafactory/solver_integration_test.exs test/hexafactory/constraint_interactions_test.exs test/hexafactory/volumetry_smoke_test.exs`

Run: `cd hexarail && cargo test --manifest-path native/hexacore_engine/Cargo.toml --lib -- --nocapture`

Expected: PASS

**Step 5: Commit**

```bash
git add hexarail/test/hexafactory/volumetry_smoke_test.exs docs/plans/2026-03-25-core-agnostic-refactoring-plan.md README.md
git commit -m "feat: validate hexafactory first lot"
```

## Execution Notes

- Start with Task 1 and do not jump ahead.
- If a task reveals a missing generic primitive in `HexaCore`, add it there only if it can be named without manufacturing vocabulary.
- If a task reveals a missing manufacturing concept, add it under `HexaFactory`.
- After each task, run the focused test first, then the adjacent regression scope.

## Ready to Execute

Plan complete and saved to `docs/plans/2026-03-31-hexafactory-first-lot-implementation-plan.md`.

Two execution options:

1. Subagent-Driven (this session) - dispatch a fresh subagent per task, review between tasks, fast iteration
2. Parallel Session (separate) - open a new session with executing-plans, batch execution with checkpoints
