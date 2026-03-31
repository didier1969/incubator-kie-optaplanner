# HexaFactory First Lot Design

## Context

`HexaFactory` is the second vertical of the platform. It is not a toy proof and it is not a reduced demo. The first lot must already embody the full manufacturing scope documented in the repository, while preserving a strict separation between the agnostic core (`HexaCore`) and the vertical (`HexaFactory`).

The design is constrained by four realities:

1. The platform mandate is multi-vertical, not railway-only.
2. `HexaCore` has only recently proven a first core-only solve path.
3. `HexaFactory` already has documented domain expectations and volumetry targets.
4. Product architecture must be designed for the target industrial scale from day one, even if automated tests run on smaller datasets.

## Non-Negotiable Constraints

- Full first-lot manufacturing scope stays in scope.
- `HexaCore` remains agnostic and does not absorb manufacturing semantics.
- `HexaFactory` exists as production code under its own namespace.
- Product code is designed for the target volumetry:
  - about 60 plants
  - about 200 to 800 machines per plant
  - routings with 5 to 30 operations
  - BOM hierarchy from ROH/F to HALB/T0/T1/T2/T3/T4
  - inter-plant lead times
  - setup matrices, batch operations, transfer batches, buffer limits, scrap/yield, maintenance, tooling, labor skills, and shift asymmetry
- Test volumetry may be reduced, but test paths must execute the same code used by the production architecture.

## Approaches Considered

### Option A. Single OTP app, strict namespace and contract separation

Keep the current Mix application and Rust crate layout for now, but add a real `HexaFactory` vertical with explicit Elixir modules, schemas, generator, adapter, solver facade, and tests. `HexaCore` stays generic and only receives projected planning problems.

Pros:

- Fastest path to a real vertical without fake proof work
- Lowest migration risk on the current branch
- Preserves future extraction into a dedicated app or crate
- Keeps TDD feasible

Cons:

- Physical isolation remains incomplete in the first iteration
- Requires discipline to avoid leaking manufacturing logic into `HexaCore`

### Option B. Immediate physical split into new Mix app and new Rust crate

Create a second OTP application and a second Rust vertical crate immediately, then connect both through a new boundary.

Pros:

- Strongest physical separation
- Best match to the long-term architecture

Cons:

- Too much moving infrastructure at once
- High risk of spending the lot on packaging instead of proving the vertical
- Slows the first full-scope delivery

### Option C. Extend `HexaCore` directly with manufacturing semantics

Push BOM, setup matrices, batching, maintenance, and plant topology directly into `HexaCore`.

Pros:

- Short-term convenience

Cons:

- Breaks the platform mandate
- Recreates the railway coupling problem in a new form
- Makes future verticals harder, not easier

## Decision

Option A is the design for the first lot.

The first lot ships a complete `HexaFactory` vertical inside the existing application boundary, but with strict namespace, persistence, adaptation, and runtime boundaries. Physical extraction remains a later refactoring, not a blocker for the first real manufacturing lot.

## First-Lot Scope

The first lot includes all documented product capabilities below.

### Enterprise Topology

- multi-company, multi-plant topology
- storage locations for ROH, HALB, FERT, and intermediate buffers
- deterministic transport lanes with article-dependent transit times

### Materials and BOM

- material taxonomy for ROH, procured/subcontracted components, HALB, T0, T1, T2, T3, T4
- reusable BOM graph with multi-level parent-child relationships
- quantity-per-parent, scrap assumptions, and substitution-ready hooks

### Production Orders and Routings

- production orders with due dates, priorities, quantities, and release dates
- routing alternatives:
  - in-house
  - subcontracted step
  - cross-plant
- strict linear operation order with optional transfer batches

### Resources and Capacities

- work centers
- machine instances and machine groups
- labor pools and skills
- park-level supervision constraints
- asymmetric calendars between labor and machines
- tooling and fixture resources with finite availability

### Industrial Constraints

- sequence-dependent setup matrices
- lot splitting
- batch operations
- transfer batches
- storage and buffer capacities
- scrap and yield propagation
- preventive and curative maintenance
- deterministic transit between plants
- economic penalties for overqualified labor assignment

### Optimization Objective

Priority order is fixed:

1. due-date adherence and starvation avoidance across the chain
2. setup reduction through favorable sequencing
3. cost reduction through cheaper compatible machines and appropriate labor assignment

## Architectural Boundaries

### `HexaCore`

`HexaCore` owns only generic planning primitives and solve interfaces:

- generic resources
- generic jobs and precedence edges
- generic capacities and availability windows
- generic solve/evaluate entrypoints
- generic score components and solver heuristics

`HexaCore` must not know:

- plant semantics
- BOM semantics
- tooling semantics
- SAP vocabulary
- manufacturing-specific scoring rules

### Required Generic Uplift in `HexaCore`

The current `HexaCore` solve path is still minimal. It can score unassigned jobs and assign simplistic start times, but it does not yet model the generic primitives needed by a full industrial vertical.

The first lot therefore includes a generic extension of the core contract, still without manufacturing semantics:

- job precedence edges
- release dates and due dates
- availability windows
- generic setup/changeover metadata
- batch group identifiers
- transfer/transport lag edges
- maintenance blackout intervals
- generic score component breakdowns

This uplift belongs in `HexaCore` because these are reusable planning primitives. Plant names, BOM semantics, tooling vocabulary, and SAP concepts still remain exclusively in `HexaFactory`.

### `HexaFactory`

`HexaFactory` owns:

- manufacturing domain model
- persistence schemas
- synthetic generator
- import/projection pipeline
- setup matrix construction
- buffer, batching, maintenance, and scrap logic
- translation from manufacturing state to `HexaCore` planning problems
- vertical-facing result interpretation

## Target Module Layout

The first lot adds a dedicated production namespace under `hexarail/lib`.

```text
hexarail/lib/hexafactory/
  application.ex
  repo_bridge.ex
  domain/
    company_code.ex
    plant.ex
    storage_location.ex
    material.ex
    bom_item.ex
    work_center.ex
    machine.ex
    labor_pool.ex
    operator.ex
    skill.ex
    tool.ex
    tool_instance.ex
    setup_profile.ex
    setup_transition.ex
    maintenance_window.ex
    transport_lane.ex
    production_order.ex
    routing.ex
    routing_operation.ex
    order_allocation.ex
    buffer.ex
    batch_policy.ex
  generator/
    seed.ex
    topology_builder.ex
    materials_builder.ex
    routing_builder.ex
    capacity_builder.ex
    setup_builder.ex
    orders_builder.ex
    dataset.ex
  constraints/
    due_date.ex
    setup_sequence.ex
    machine_cost.ex
    labor_skill.ex
    batching.ex
    transfer_batch.ex
    buffer_capacity.ex
    scrap_yield.ex
    maintenance.ex
    transport.ex
  adapter/
    problem_projection.ex
    resource_projection.ex
    job_projection.ex
    score_projection.ex
  solver/
    facade.ex
    result_decoder.ex
    diagnostics.ex
  telemetry/
    metrics.ex
```

The first lot also adds persistence and test modules under:

```text
hexarail/priv/repo/migrations/
hexarail/test/hexafactory/
```

## Persistence Model

The first lot uses the existing `HexaRail.Repo` for practical reasons, but all manufacturing data uses dedicated tables and schemas under `HexaFactory.*`.

The core persistence strategy is:

- normalized master data for plants, materials, resources, skills, tools, transport lanes, and calendars
- normalized planning data for orders, routings, operations, maintenance windows, buffer policies, and setup transitions
- denormalized planning snapshots for solver projection and diagnostics

The first lot should prepare a solver-ready snapshot layer so high-volume scheduling does not depend on repeated deep Ecto graph traversal.

## Volumetry-First Product Design

The product architecture must support the target scale without structural redesign.

### Expected Product Scale

- around 60 plants
- around 12,000 to 30,000 machines overall
- large operator pools and cross-skill matrices
- thousands of tools and fixtures
- large multi-level BOMs with strong component reuse
- large order books and rush-order injections

### Design Consequences

- use integer ticks and compact identifiers in projections to `HexaCore`
- keep setup transitions sparse and indexed by profile, not naïve full dense matrices when avoidable
- separate canonical domain storage from solver-ready projections
- precompute and cache deterministic setup transitions, transport durations, and availability windows
- stream generator and import work instead of assembling giant in-memory graphs in Elixir
- encode precedence, batching, and buffer constraints explicitly before crossing the NIF boundary
- avoid per-job round trips between Elixir and Rust

## Data Flow

### 1. Domain Build

`HexaFactory.Generator` creates a deterministic, seed-based industrial dataset matching the target operating model:

- 60-plant topology
- machine fleet distribution
- material graph and BOM hierarchy
- routing alternatives
- setup profiles and transitions
- transport lanes
- order book with due dates and urgency
- maintenance windows and random disruptions

### 2. Persistence

Generated or imported data is persisted into dedicated `HexaFactory` tables through Ecto.

### 3. Projection

`HexaFactory.Adapter` loads a planning horizon and projects the manufacturing state into a generic `HexaCore.Domain.Problem`.

This projection contains:

- generic resources for machines, labor pools, tools, buffers, and transport capacity proxies
- generic jobs for setups, production runs, batches, inspections, transfers, and maintenance blocks
- precedence edges and availability windows
- score metadata needed to evaluate lateness, setup penalties, and economic cost

### 4. Solve

`HexaFactory.Solver.Facade` calls the `HexaCore.Nif` core-only path.

### 5. Decode

`HexaFactory.Solver.ResultDecoder` turns the solved generic problem back into:

- machine schedules
- labor assignments
- setup chains
- batch compositions
- transfer timing
- lateness and starvation diagnostics

## Generator Design

The synthetic generator is part of the first lot, not an optional accessory.

The generator must be:

- deterministic from a seed
- parametrizable by volumetry profile
- able to generate production-like heterogeneity rather than uniform toy data
- suitable for both tests and high-volume product runs

The generator profile must include:

- plant count and plant typology
- machine families and distributions
- labor and skill pools
- material families and BOM reuse intensity
- routing complexity and alternative routing rates
- setup complexity
- scrap/yield distributions
- maintenance patterns
- batching and transfer policies
- order pressure profile

## Open Source Reuse Posture

The first lot must reuse stable external building blocks where they help, and must not reinvent canonical semantics that already exist elsewhere.

### Manufacturing Semantics

- Use `B2MML / BatchML` as the canonical semantic reference for ISA-95 / ISA-88 manufacturing concepts.
- Use `AAS` submodel templates as the canonical reference for equipment, maintenance, production calendars, and hierarchical asset structures.
- Use operational ERP references such as `ERPNext` and `Odoo` to validate executable manufacturing concepts such as BOM, routing, workstation capacity, scrap, downtime, and maintenance.

### Elixir

- Prefer stdlib `:rand`, `Calendar`, and `:calendar` for deterministic generation primitives.
- Evaluate `Tempus` as the primary calendar and timeslot helper instead of inventing a new interval algebra in Elixir.
- Evaluate `Holidays` only as a holiday-source helper, not as the core planning model.
- Avoid narrow date helpers that do not cover real industrial time windows well enough.

### Rust

- Keep `petgraph` as the graph foundation and plan an upgrade to the current stable line instead of introducing another general graph library.
- Evaluate `rangemap` for generic availability and blackout interval handling.
- Evaluate `rand_chacha` for deterministic scenario replay and seeded generation.
- Evaluate `good_lp` with a `HiGHS` backend only as a bounded exact sidecar for local subproblems, not as a replacement for `HexaCore`.
- Avoid pulling in a second pathfinding library when `petgraph` already covers the required graph layer.

## Testing and Validation Strategy

The first lot follows strict TDD.

### Product-Level Test Principle

- tests may run on smaller datasets
- test code must execute the same domain, generator, adapter, and solver paths as production
- no fake alternate code path for tests

### Required Test Layers

- domain invariants
- generator determinism
- Ecto schema and migration integrity
- adapter projection correctness
- solver integration on manufacturing-shaped problems
- volumetry smoke tests on reduced but representative datasets
- regression tests for buffer, setup, batching, transfer, and maintenance interactions

## Exit Criteria for the First Lot

The first lot is complete only when all of the following are true:

- `HexaFactory` exists as production code under a dedicated namespace
- the full documented manufacturing scope is represented in code
- dedicated persistence exists for the vertical
- the generator produces deterministic large-scale manufacturing datasets
- the adapter projects manufacturing state into `HexaCore` without leaking semantics into the core
- solver integration passes through the generic `HexaCore` boundary
- tests are green
- documentation reflects the new reality

## Immediate Next Step

Write the implementation plan and execute it in strict TDD order:

1. failing tests first
2. minimal production code
3. green verification
4. refactor
5. validation
6. documentation updates
7. commit
