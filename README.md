# HexaRail: Universal Digital Twin & Optimization Framework

HexaRail is an industrial-grade, high-performance framework designed to model, simulate, and optimize complex systems in real-time. Built to replace legacy Java-based optimization engines, it leverages the Elixir/OTP control plane for resilience and the Rust data plane for computational speed.

## 🌌 The Vision: Optimization without Compromise
Most optimization systems simplify reality to fit mathematical models. HexaRail reverses this paradigm: it models reality with 100% fidelity, ensuring that optimizations are actionable in the real world.

### The "CFF/SBB" Vertical (Showcase)
As a primary validator of its scale and precision, HexaRail currently hosts a full-scale Digital Twin of the **Swiss Federal Railways (CFF/SBB)** network. 
*   **Scale:** 1.19M+ trips, 19M+ stop events, 96k locations.
*   **Purpose:** Prove that if the framework can handle the entire Swiss railway network with zero simplification, it can optimize any industrial domain (Manufacturing, Logistics, Healthcare).

## 🏛 Architecture: Dual-Plane Scalability
*   **Control Plane (Elixir/OTP):** Handles actor-based orchestration, state management for millions of entities, and real-time interaction via Phoenix LiveView.
*   **Data Plane (Rust):** High-speed incremental computation engine (`salsa`), topological graph analysis (`petgraph`), and SIMD-accelerated search algorithms.
*   **Persistence (PostgreSQL/PostGIS):** Ultra-optimized storage for massive geospatial and temporal datasets.

## 🚀 Key Framework Capabilities
*   **Massive Ingestion:** Proprietary streaming pipeline capable of ingesting 20M+ rows in minutes.
*   **Zero-Copy Memory:** Efficient data transfer between the BEAM and the Rust Data Plane.
*   **Incremental Scoring:** Real-time conflict detection and score calculation.
*   **Real-Time Visualization:** Streaming UI capable of displaying millions of entities without reduction.

## 🛠 Getting Started (CFF Showcase)

### 1. Initialize Environment
```bash
nix develop
cd hexarail
mix deps.get
mix ecto.setup
```

### 2. Ingest the SBB Dataset
```bash
mix data.download
mix data.import
```

## 📈 Roadmap
*   **Phase 1-11:** COMPLETED (Framework foundations & Big Data pipeline).
*   **Current:** Phase 12 - Universal Graph Assembler (Rust).
*   **Future:** Generic DSL for multi-domain constraints (Manufacturing, HR).

## ⚖ Mandates
*   **Zero Simplification:** We model the world as it is, not as the math prefers it.
*   **Zero Warning Policy:** 100% test coverage and strict static analysis.
