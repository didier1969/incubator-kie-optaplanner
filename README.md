# HexaCore Platform with HexaRail Showcase

This repository is evolving toward an industrial-grade, high-performance optimization and digital twin platform built around an agnostic core.

The target architecture separates:
*   **HexaCore:** the reusable optimization engine and orchestration platform.
*   **HexaRail:** the railway vertical and primary showcase.
*   **HexaFactory:** the manufacturing/job-shop vertical now implemented as a real production namespace with generator, persistence, projection, diagnostics, and smoke execution path.

## Vision
Most optimization systems simplify reality to fit mathematical models. This project takes the opposite stance: model reality with enough physical, temporal, and operational fidelity that proposed optimizations remain actionable in the real world.

The long-term goal is not a single railway product. The goal is a multi-vertical platform that can support domains such as:
*   Rail operations and disruption management
*   Manufacturing / job-shop scheduling
*   Logistics and supply chain flows
*   Workforce and rostering problems

## Current Vertical Status

### HexaRail
HexaRail is the most advanced vertical in the repository. It serves as the technical validator and showcase by modeling the **Swiss Federal Railways (CFF/SBB)** network.
*   **Scale:** 1.19M+ trips, 19M+ stop events, 96k locations
*   **Role:** prove that the platform can handle a zero-simplification, high-density real-world system
*   **Operator smoke:** `mix hexarail.smoke` now exercises a deterministic railway path through topology, timetable, perturbation, and conflict resolution

### HexaFactory
HexaFactory is the second vertical already initiated in the repo.
*   **Focus:** manufacturing, job-shop scheduling, setup optimization, plant capacities, and supply chain constraints
*   **Status:** domain ontology and design documents are present under `docs/plans/hexafactory/`, and the production namespace under `hexarail/lib/hexafactory/` now includes foundation/planning persistence, deterministic dataset generation, planning-horizon snapshots, projection into `HexaCore`, vertical diagnostics, and an executable `mix hexafactory.smoke` path
*   **Operator tasks:** `mix hexafactory.generate`, `mix hexafactory.persist`, `mix hexafactory.solve`, and `mix hexafactory.smoke`

## Architecture
*   **Control Plane (Elixir/OTP):** orchestration, actor-based state management, resilience, and real-time interfaces via Phoenix LiveView
*   **Data Plane (Rust):** incremental computation, graph analysis, heuristics, and performance-critical simulation logic
*   **Persistence (PostgreSQL/PostGIS):** storage for large geospatial, temporal, and operational datasets

## Core Capabilities
*   **Agnostic optimization core:** reusable solver, DSL, transpilation, and incremental score engine
*   **Massive ingestion:** high-volume import pipelines for dense industrial datasets
*   **Zero-copy boundaries:** efficient transfer between the BEAM and Rust
*   **Real-time visualization:** operational dashboards and scenario playback
*   **Scenario-based planning:** support for live replanning and what-if simulation

## Getting Started

### Railway Showcase
```bash
direnv allow
nix develop
bash scripts/env-smoke-check.sh
cd hexarail
mix deps.get
mix ecto.setup
```

To ingest the SBB showcase dataset:

```bash
mix data.download
mix data.import
```

The shell now isolates mutable state under `./.state/` and exports project-local randomized ports for the web endpoint, tests, and PostgreSQL.

## Repository Direction
*   **Near term:** finish the remaining deep separation between `HexaCore` and the railway-specific vertical. The public Elixir NIF boundary is now split, the Rust type layer is split between `domain.rs` and `railway_domain.rs`, the Rust NIF functions are split between `lib.rs` and `railway_nif.rs`, and the railway runtime now lives in `railway_topology.rs` with `NetworkResource` owned by the railway module. The crate still remains shared, so the final physical crate split is still ahead.
*   **Medium term:** stabilize the agnostic APIs and prove reuse across multiple verticals
*   **Long term:** ship a true multi-vertical optimization platform, with HexaRail as showcase and HexaFactory as the next concrete industrial implementation

## Mandates
*   **Zero Simplification:** model the world as it is, not as the math prefers it
*   **Framework First:** verticals must sit on a reusable agnostic core
*   **Zero Warning Policy:** strict testing and static analysis standards
