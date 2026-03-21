# Delta Report : Transition from OptaPlanner to HexaPlanner

This report outlines the rigorous architectural delta required to transform the existing OptaPlanner codebase into the target vision of **HexaPlanner**, a highly resilient, polyglot, and high-performance industrial digital twin.

## 1. WHAT WE KEEP
The following components from the existing repository align with the HexaPlanner vision and will be isolated and maintained:

*   **Constraint Streams API (`optaplanner-constraint-streams-common`)**: The declarative API for defining constraints remains the foundation of our business logic modeling. It provides an excellent, intuitive abstraction for complex constraints.
*   **Bavet Incremental Score Engine (`optaplanner-constraint-streams-bavet`)**: The Bavet implementation is retained as the core "Score Data Plane". It will be decapitated from the rest of the solver, optimized for Ahead-Of-Time (AOT) compilation via GraalVM Native Image, and exposed via C-FFI.
*   **Domain Modeling Primitives (Shadow Variables)**: The concepts of planning variables and specifically **Shadow Variables** will be kept and updated automatically via Java listeners. The Rust solver will modify the planning variables (sequences), while the Java engine will incrementally recalculate shadow variables (e.g., start times, sequence-dependent setup times).
*   **ScoreDirector Interfaces**: The interfaces bridging the domain state with the incremental calculation engine will be kept to interact with the isolated Bavet engine.

## 2. WHAT WE THROW AWAY
The following legacy components are dead-ends, incompatible with the new hybrid architecture, or detrimental to our performance/resilience goals:

*   **LocalSearch and Construction Heuristics (`optaplanner-core`)**: The pure Java implementation of search algorithms is completely purged from the final binary. The heuristic and local search logic will be strictly delegated to the new Rust engine.
*   **SolverManager and Java Orchestration (`optaplanner-core`)**: Global orchestration, thread management, and solver execution lifecycle currently handled by Java are removed. This responsibility shifts entirely to the Elixir/OTP Control Plane.
*   **Drools Rule Engine (`optaplanner-constraint-streams-drools`, `optaplanner-constraint-drl`)**: Drools is fundamentally incompatible with our ultra-fast AOT (GraalVM) startup goals and zero-copy memory requirements. It is discarded in favor of Bavet exclusively.
*   **XML / JSON Configuration (`optaplanner-persistence`, `optaplanner-core`)**: The historical XML solver configuration and Jackson/XStream persistence are too fragile. They will be replaced by a declarative DSL (CUE) and zero-copy memory boundaries. No serialization (JSON/Protobuf) will occur on the hot path.
*   **Easy/Incremental Java Score Calculators**: Deprecated in favor of a strictly Constraint Streams/Bavet approach to guarantee incremental performance and PGO (Profile-Guided Optimization) compatibility.

## 3. WHAT WE CREATE FROM SCRATCH
To achieve the HexaPlanner vision, the following subsystems must be built from the ground up:

*   **Hybrid Search Engine (Rust SIMD & CP-SAT)**: A high-performance brain written in Rust (2024 edition) utilizing Data-Oriented Design (SoA, Arena allocation). It will implement Adaptive Large Neighborhood Search (ALNS) accelerated by explicit SIMD (AVX-512) and use C++ FFI (`cxx`) to interact with Google OR-Tools (CP-SAT) for exact sub-problem recreation.
*   **Control Plane and Orchestration (Elixir/OTP)**: A distributed orchestration layer built on Elixir 1.18. It will use the Actor Model (`GenServer`) to handle multi-tenant simulation sessions, state forking ("What-If" scenarios), and fault isolation ("Let it crash" philosophy). Phoenix LiveView will serve real-time updates.
*   **Zero-Copy FFI Interoperability Bridges**:
    *   **Java-Rust (Project Panama)**: A shared off-heap memory bridge allowing the Rust solver to mutate state and the Java Bavet engine to compute scores via `java.lang.foreign` and GraalVM `@CEntryPoint`, avoiding serialization overhead.
    *   **Elixir-Rust (Rustler NIFs)**: Integration of Rust compute bounds into the BEAM VM via Dirty NIFs and Erlang Ports/C-Nodes to ensure heavy solving never starves the Elixir schedulers.
*   **Neuro-Symbolic Reinforcement Learning Subsystem**: An AI agent utilizing Graph Neural Networks (GNN) to act as a search oracle/meta-heuristic director. It will use batched inference via JAX/XLA or Candle (Rust) over pinned memory for sub-millisecond GPU evaluations.
*   **Secure Client Plugin Sandbox (WASM)**: Integration of Wasmtime/Extism directly into the scoring loop to allow clients to securely inject ultra-specific business rules compiled to WebAssembly, with strict resource metering (Fuel) and zero I/O capabilities.
*   **Declarative Typed Configuration (CUE DSL)**: A mathematically validated configuration layer to replace XML, ensuring shift-left validation of solver parameters and constraints before execution.
*   **"Bit-for-Bit" Infrastructure as Code (Nix Flakes)**: A unified, cryptographically locked build pipeline (`flake.nix`) orchestrating the cross-compilation of Rust, Java GraalVM, and Elixir components to guarantee absolute reproducibility.