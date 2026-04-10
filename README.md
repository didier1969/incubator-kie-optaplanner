# HexaCore Platform with HexaRail & HexaFactory Showcases

This repository is an industrial-grade, high-performance optimization and digital twin platform built around an agnostic core, functionally equivalent to TimeFold (OptaPlanner) but powered by SOTA Neural Combinatorial Optimization (NCO).

The architecture separates:
*   **HexaCore:** the reusable optimization engine, orchestration platform, Salsa-based reactive scoring, and PyTorch-ready NCO feature extractor.
*   **HexaRail:** the railway vertical and primary showcase (SBB network).
*   **HexaFactory:** the manufacturing/job-shop vertical implemented as a real production namespace with generator, persistence, projection, diagnostics, and a massive offline dataset generator for Deep Learning.

## Vision
Most optimization systems simplify reality to fit mathematical models. This project takes the opposite stance: model reality with enough physical, temporal, and operational fidelity that proposed optimizations remain actionable in the real world.

The long-term goal is a multi-vertical platform that can support domains such as:
*   Rail operations and disruption management
*   Manufacturing / Job-Shop scheduling (JSSP)
*   Logistics and supply chain flows
*   Workforce and rostering problems

## Current Vertical Status

### HexaRail
HexaRail serves as the technical validator and showcase by modeling the **Swiss Federal Railways (CFF/SBB)** network.
*   **Scale:** 1.19M+ trips, 19M+ stop events, 96k locations
*   **Role:** prove that the platform can handle a zero-simplification, high-density real-world system
*   **Operator smoke:** `mix hexarail.smoke` exercises a deterministic railway path through topology, timetable, perturbation, and conflict resolution.

### HexaFactory
HexaFactory is the manufacturing, job-shop scheduling vertical.
*   **Focus:** setup optimization, plant capacities, supply chain constraints, and AI dataset generation.
*   **Status:** domain ontology, production namespace, deterministic curriculum generation, and offline Reinforcement Learning expert trajectories generator.
*   **Operator tasks:** `mix hexafactory.generate_dataset` (generates 10k+ expert scenarios in JSON for PyTorch), `mix hexafactory.persist`, `mix hexafactory.solve`, and `mix hexafactory.smoke`.

## Architecture & SOTA Capabilities
*   **Control Plane (Elixir/OTP):** orchestration, actor-based state management, resilience, and real-time interfaces via Phoenix LiveView. Massive parallel ingestion and dataset generation.
*   **Data Plane (Rust):** incremental computation via **Salsa (O(delta))**, graph analysis, Late Acceptance Hill Climbing (LAHC), and performance-critical simulation logic.
*   **SOTA NCO (Latent Space):** The Rust Data Plane extracts an exact, normalized Markov Decision Process (MDP) state of the factory (Heterogeneous COO Graph, Dynamic Machine Occupancy, Categorical Dictionaries) ready for PyTorch/dfdx Graph Neural Networks.
*   **Explainable AI (XAI):** The system returns a prioritized `HardMediumSoftScore` along with a detailed `ScoreExplanation` mapping every constraint violation back to the physical source.
*   **Persistence (PostgreSQL/PostGIS):** storage for large geospatial, temporal, operational datasets, and JSONB tensors.

## Getting Started

### Showcase
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
*   **Near term:** integrate `dfdx` or `tch-rs` to provide the neural network (Brain Infill) that consumes the generated NCO tensors to predict Branching Probability Maps.
*   **Medium term:** port all constraints to the Salsa reactive engine to allow <1ms "What-if" score recalculations in the UI.
*   **Long term:** ship a true multi-vertical optimization platform, blending exact Operations Research with Neural Combinatorial Optimization.

## Mandates
*   **Zero Simplification:** model the world as it is, not as the math prefers it.
*   **Framework First:** verticals must sit on a reusable agnostic core.
*   **Zero Warning Policy:** strict testing and static analysis standards.
