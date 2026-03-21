# HexaPlanner: Market Research & Open-Source Alternatives (Buy vs. Build)

## Executive Summary
This document provides an evaluation of state-of-the-art open-source components, libraries, and frameworks that could replace or complement parts of the current OptaPlanner implementation for our new HexaPlanner hybrid architecture (Rust/Java/Elixir). The research covers four strategic areas: Rust ALNS frameworks, CP/SAT solvers, WASM sandboxing engines, and Graph Neural Network (GNN) libraries.

## 1. Rust ALNS (Adaptive Large Neighborhood Search) Frameworks

**State of the Art:**
ALNS is a powerful metaheuristic framework for Vehicle Routing (VRP) and Scheduling. While there isn't a single dominant industry-standard ALNS crate in Rust yet (like Python's `alns`), several high-quality implementations and ecosystems are emerging, benefiting from Rust's performance and memory safety.

**Key Libraries/Projects:**
*   **alns-rs:** A hobbyist/community implementation of the ALNS algorithm in Rust, including features like Linear-RRT acceptance criteria.
*   **DR-ALNS:** State-of-the-art "Deep Reinforced ALNS" architectures where neural networks select destroy/repair operators. While primary research is often in Python, reimplementing these architectures in Rust is the current benchmark for high-performance solvers.
*   **Supporting Ecosystem:** Crates like `pathfinding` (graph algorithms), `rand` (stochastic operator selection), and `rayon` (parallelizing search threads) form the backbone of a custom Rust ALNS implementation.

**Buy vs. Build Analysis:**
*   **Build:** Highly recommended. Given the lack of a mature, plug-and-play production-ready ALNS crate in Rust, building a custom ALNS engine leveraging Rust's `rayon` for parallelism and zero-cost abstractions will provide the best performance tailored to our specific VRP/Scheduling needs.

## 2. CP/SAT Solvers (Google OR-Tools, Choco, Rust-Native)

**State of the Art:**
The choice of solver depends heavily on the integration ecosystem (Rust vs. Java) and the problem type (Scheduling vs. VRP).

**Key Libraries/Projects:**
*   **Google OR-Tools (CP-SAT):** The industry standard for large-scale optimization and scheduling. Written in C++, it consistently wins the MiniZinc Challenge. Rust integration is possible via the community `cp_sat` crate (FFI wrapper). It also includes a specialized Routing Library for VRP using Local Search.
*   **Choco Solver (Java):** A mature Constraint Programming library. It is highly extensible, making it excellent for writing custom constraints. However, it trails CP-SAT in raw solving speed for standard benchmarks. Fits well into our Java legacy/ecosystem.
*   **Rust-Native Solvers:**
    *   **SolverForge:** A modern framework designed for planning and scheduling focusing on metaheuristics. It uses a "zero-erasure" architecture for CPU cache efficiency.
    *   **Pumpkin:** A state-of-the-art Lazy Clause Generation solver written in pure Rust, supporting global constraints like `Cumulative` and `Disjunctive`.

**Buy vs. Build Analysis:**
*   **Buy (Integrate):** For pure performance in scheduling, wrapping **Google OR-Tools CP-SAT** via FFI in Rust is the most pragmatic approach. For deep integration within the existing Java ecosystem where custom heuristics are needed, **Choco** is a strong candidate. For a pure Rust CP approach without C++ dependencies, integrating **Pumpkin** or **SolverForge** is viable. We should "Buy" (integrate) these engines rather than building a CP-SAT solver from scratch, which requires years of specialized academic effort.

## 3. WASM Sandboxing Engines: Extism vs. Wasmtime

**State of the Art:**
WebAssembly (WASM) provides a secure, portable execution environment, ideal for executing user-defined heuristics or isolated scoring functions in our hybrid architecture.

**Key Libraries/Projects:**
*   **Wasmtime:** A low-level, high-performance standalone runtime by the Bytecode Alliance (written in Rust). It offers near-native performance using the Cranelift JIT compiler and strong WASI-based sandboxing. Passing complex data types requires manual memory management.
*   **Extism:** A high-level framework that simplifies building plugin systems. It wraps low-level engines (often Wasmtime on the server) and handles complex data types (Strings, JSON, Protobuf) via a shared virtual memory space ("Kernel"). Supported in over 15 languages including Rust, Java, and Elixir.

**Buy vs. Build Analysis:**
*   **Buy (Integrate):** We should definitely leverage existing engines. **Extism** is the clear winner for our hybrid architecture. Its multi-language support (Rust, Java, Elixir) and abstraction over WASM linear memory will drastically reduce the engineering effort needed to implement a universal plugin system for custom constraints or score calculation modules.

## 4. Graph Neural Network (GNN) Libraries for Routing/Scheduling

**State of the Art:**
GNNs are increasingly used for "Neural Combinatorial Optimization," augmenting or replacing traditional heuristics in routing (VRP) and scheduling (JSSP) tasks.

**Key Libraries/Projects:**
*   **PyTorch Geometric (PyG):** The leading library for research and rapid prototyping. It treats graphs as pure PyTorch tensors, making it highly flexible and fast for small-to-midsize graphs. It has massive community support for RL4CO (Reinforcement Learning for Combinatorial Optimization).
*   **Deep Graph Library (DGL):** Better suited for massive-scale industrial graphs and memory efficiency. Strongly backed by AWS/NVIDIA and used in industrial solvers like Wheatley (scheduling).
*   **Specialized Frameworks:**
    *   **RL4CO:** Built on PyTorch for state-of-the-art VRP/TSP solvers.
    *   **JobShopLib / Wheatley:** Libraries focused on Job Shop Scheduling using GNNs and RL.

**Buy vs. Build Analysis:**
*   **Buy (Integrate):** For integrating AI-driven heuristics, we should leverage **PyTorch Geometric (PyG)** (via Rust bindings like `tch-rs` or via Python microservices) due to its dominance in recent Neural Combinatorial Optimization research (e.g., RL4CO). Building custom GNN primitives from scratch is not recommended.

## Conclusion & Architectural Recommendations
For the HexaPlanner hybrid architecture:
1.  **ALNS:** **Build** a custom, highly parallel ALNS framework in Rust using `rayon` and core algorithmic crates.
2.  **CP/SAT:** **Integrate** Google OR-Tools (via FFI) for raw performance, or explore pure Rust solvers like Pumpkin for a C++-free stack.
3.  **WASM Plugins:** **Integrate** Extism to enable seamless, cross-language (Rust/Java/Elixir) execution of custom scoring rules and constraints.
4.  **AI/GNN:** **Integrate** PyG / RL4CO models to serve as advanced dispatchers or learned heuristics.
