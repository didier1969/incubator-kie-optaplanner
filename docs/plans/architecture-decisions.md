# Architecture Decisions
## Data Plane: [C] Pure Rust Engine (Incremental Score Calculation, Heuristics, & Genetic Algorithms)
## Control Plane: [A] Orchestrateur Elixir / Erlang (Actor Model & Phoenix LiveView)
## Integration Bridge (Control Plane <-> Data Plane): [A] Native Integration via NIFs (Rustler)
## Serialization Protocol: [C+A] Hybrid (ETF native for orchestration + FlatBuffers for massive topologies Boot)
## Modeling & Constraints: [C] Metaprogramming (Elixir DSL compiling to Rust AST via Functional Streams)
## User Interface: [C] Hybride "Isomorphic" (LiveView + WebComponents/Canvas via SwarmEx-viz)
## Distribution & Scalability: [A] Distributed Erlang Cluster (Peer-to-Peer with Horde/Swarm & Oban for queueing)
## Core Principle: Ecosystem Reuse (Do not reinvent the wheel. Rely on high-performance Elixir/Rust standard libraries like Oban, Broadway, Rayon, Crossbeam instead of writing custom low-level code).