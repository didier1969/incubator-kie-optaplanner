# Master Architecture Document: HexaPlanner

## 1. Executive Summary & Vision
HexaPlanner is an advanced, ultra-performant Digital Twin. Its ultimate "North Star" goal is to model, simulate, and optimize the entirety of the Swiss Federal Railways (CFF/SBB) network in real-time, without any simplifications. This document consolidates all functional, technical, and operational requirements. The system relies on a state-of-the-art hybrid architecture that combines the resilience and orchestration capabilities of Elixir/OTP, the raw computational speed of Rust (SIMD, Incremental computation via salsa), and the intelligence of Neuro-Symbolic AI.

---

## 2. Core System Architecture

### 2.1. Control Plane & Orchestration (Elixir / Erlang OTP)
The control plane is the central nervous system handling orchestration, resilience, and user interaction.
*   **Actor Model & Fault Isolation:** Built on Elixir 1.19.5 and OTP 28. Every scenario runs in an isolated `GenServer` actor. If a Rust native solver crashes, only the Elixir proxy actor dies ("Let it crash"), keeping the global system intact [Source: 03_Response_Elixir_OTP.md].
*   **Event Sourcing & Lazy Forking:** Planning states are reconstructed via an immutable event log. "What-If" scenarios utilize lazy state cloning in memory, allowing massive, non-destructive scenario forking [Source: 03_Response_Elixir_OTP.md].
*   **Distributed Clustering:** Uses native Erlang distribution, with Broadway/GenStage for demand-driven backpressure and circuit breakers to dynamically route to available computing nodes [Source: 03_Response_Elixir_OTP.md].

### 2.2. Compute & Search Engine (Rust / C++)
The central optimization engine is responsible for high-performance sequence generation.
*   **Hybrid ALNS & CP-SAT:** Combines Adaptive Large Neighborhood Search for macroscopic exploration and Google OR-Tools CP-SAT (via `cxx` FFI) for perfect sequence recreation in specific neighborhoods [Source: 02_Response_Rust_SIMD.md].
*   **Data-Oriented Design & SIMD:** Adopts a Structure of Arrays (SoA) layout with arena allocators (no GC overhead). Sequence validation heavily utilizes `std::simd` (AVX-512) to process moves in parallel [Source: 02_Response_Rust_SIMD.md].
*   **Dirty NIFs:** Interaction with Elixir occurs via `Rustler`. Heavy workloads are run on Dirty NIFs or isolated OS processes to avoid starving the BEAM schedulers [Source: 03_Response_Elixir_OTP.md, 11_Response_Manager_Program_Director.md].

### 2.3. Incremental Score Evaluation (Java / GraalVM)
Handles the complex, historical OptaPlanner business logic optimally.
*   **Decapitated Core:** The engine only retains the Bavet Constraint Streams incremental calculator; local search and orchestration have been purged [Source: 01_Response_Java_GraalVM.md].
*   **Zero-Copy Interoperability:** Employs Project Panama (Rust 2024). The Rust solver allocates a shared contiguous memory segment mapped to Java. Java accesses this segment via FFI directly, completely eliminating serialization overhead [Source: 01_Response_Java_GraalVM.md].
*   **GraalVM AOT Compilation:** The Java core is compiled to a native shared library (`.so`) using GraalVM Native Image for sub-10ms startups and minimal RAM consumption [Source: 01_Response_Java_GraalVM.md].

### 2.4. Neuro-Symbolic AI (GPU Acceleration)
*   **GNN & Meta-Heuristics:** Employs Graph Neural Networks to represent the topology and output meta-actions for the symbolic Rust solver, bridging intuition and exact constraints [Source: 04_Response_IA_GPU.md].
*   **Batched Inference:** State representations are batched by the Rust engine and transferred via Zero-Copy/Pinned Memory directly to the GPU to defeat PCIe bottlenecks, utilizing `Candle` or JAX [Source: 04_Response_IA_GPU.md].

---

## 3. Extensibility & Client Logic

*   **Secure WASM Plugins:** Client-specific rules are executed securely in-loop using WebAssembly (Wasmtime via Extism) inside the Rust solver. Strict sandbox limits are enforced: bounded memory, "Fuel" limits to prevent infinite loops, and `network/fs=none` [Source: 05_Response_WASM_Cloud.md, 18_Response_Expert_Security_AppSec.md].
*   **Edge Computing in Browser:** The Rust core compiled to WASM can be run directly inside the client's browser, offloading trivial manual "What-If" recalculations from server resources [Source: 05_Response_WASM_Cloud.md].
*   **Declarative DSL:** Configurations and heuristics are validated mathematically pre-execution using the CUE language [Source: 05_Response_WASM_Cloud.md].

---

## 4. Business & Functional Domains

### 4.1. Railway Optimization
*   **Hard Infrastructure Rules:** Supports block systems (headways), single-track alternating logic, station sizing, and hardware compatibility constraints like electrification and gauge [Source: 06_Response_Business_Ferroviaire.md].
*   **Disruption Management:** Requires sub-60-second recovery strategies including re-routing, short-turning, and bus replacements, primarily aiming to minimize missed critical passenger connections [Source: 06_Response_Business_Ferroviaire.md].

### 4.2. Manufacturing (Just-In-Time & S&OP)
*   **JIT Penalties:** Driven by non-linear Earliness (holding cost) and Tardiness (client SLAs/SLA penalties) variables [Source: 07_Response_Business_Manufacturing_JIT.md].
*   **Multi-Resource Modeling:** Operations require simultaneous resource availability (Machine + Tool/Mold + Qualified Human + Materials) and incorporate Sequence-Dependent Setup Times (SMED) and predictive wear-and-tear [Source: 07_Response_Business_Manufacturing_JIT.md].
*   **Stable Planning:** Enforces "Frozen Zones" and non-disruptive replanning penalties to prevent shop-floor nervousness [Source: 08_Response_Business_Simulation_SOP.md].
*   **Collaborative Branching:** S&OP process works via Git-like "Branches," enabling Sales and Production to evaluate baseline vs. what-if scenarios side-by-side before merging [Source: 08_Response_Business_Simulation_SOP.md].

### 4.3. Human Resources & Crew Rostering
*   **Legal Compliance:** Strict enforcement of daily/weekly rest and shift limits. Matrix of dynamically expiring skills and certifications [Source: 09_Response_Business_Human_Resources.md].
*   **Day-of-Operations Urgency:** Handles H-1 absenteeism automatically via a 3-tier cascade: internal redeployment, voluntary shift pinging (SMS), and finally external temp hiring, with automated post-mortem adjustments [Source: 09_Response_Business_Human_Resources.md].

### 4.4. Explainable AI (XAI) & BI
*   **Glass-Box Output:** Every counter-intuitive decision by the algorithm must be justified with natural language tooltips and counterfactuals (e.g., explaining a deliberate gap to avoid a setup cost) [Source: 10_Response_Business_Explicabilite_BI.md].
*   **Human-in-the-Loop:** Support for manual "Pinning" (locking tasks as hard constraints) for customized scenario building [Source: 10_Response_Business_Explicabilite_BI.md].
*   **Vital KPIs:** Dashboards must track OTIF, Bottleneck Saturation, Waste Cost, Schedule Robustness, and Human Burnout Risk [Source: 10_Response_Business_Explicabilite_BI.md].

---

## 5. Engineering, Delivery, & Governance

### 5.1. Program Strategy & Agile Delivery
*   **Steel Thread Execution:** Delivery avoids traditional layer-by-layer development, utilizing vertical slices starting from a distributed technical "Hello World" down to industry MVPs to unearth FFI/integration risks early [Source: 11_Response_Manager_Program_Director.md].
*   **Team Topologies:** Split into Stream-Aligned Teams (Industrial Scenarios, Solve & Compute, Orchestration) and Platform/Enabling Teams [Source: 11_Response_Manager_Program_Director.md].
*   **Dual-Track Agile:** Decouples AI research cycles from Product Delivery through Contract-Driven Development (CDD), leaning on API stubs (Protobuf/gRPC) to eliminate cross-team bottlenecks [Source: 12_Response_Manager_Agile_Delivery.md].

### 5.2. Quality Assurance & Testing
*   **Algorithmic Definition of Done:** Code is only merged if it proves mathematical integrity, performance, and deterministic reproducibility using fixed PRNG seeds [Source: 13_Response_Manager_QA_Testing.md].
*   **Shadow Calculation Assertions:** Guarantees state integrity by ensuring the highly optimized incremental score perfectly matches the full-state score [Source: 13_Response_Manager_QA_Testing.md].
*   **Continuous Benchmarking:** Validates score distributions over 50 reference industrial datasets iteratively [Source: 13_Response_Manager_QA_Testing.md].

### 5.3. DevOps, FinOps, & Environments
*   **Polyglot Bazel & Nix:** Relies on Bazel for hermetic, incremental, and remote-cached builds, combined with Nix for bit-for-bit reproducibility [Source: 14_Response_Manager_DevOps_FinOps.md, 05_Response_WASM_Cloud.md].
*   **Ephemeral CI/CD Environments:** Ephemeral vcluster environments instantiated via GitOps with dynamic Spot instances/GPUs using Karpenter, strictly reclaimed by TTL controllers [Source: 14_Response_Manager_DevOps_FinOps.md].
*   **Tenant-Level Chargeback:** Uses OpenCost/Kubecost with forced namespace tagging for granular FinOps monitoring [Source: 14_Response_Manager_DevOps_FinOps.md].

### 5.4. Developer Experience (DevEx) & AI-Assisted Workflows
*   **Inner Loop Automation:** `devenv` enables a <3-minute onboarding time. Monorepo bounded contexts ensure an Elixir dev doesn't need to compile the Rust solver locally [Source: 15_Response_Manager_DevEx_Culture.md].
*   **Zero-Warning Culture:** Code must pass Clippy (Rust), Credo (Elixir), and SonarQube/ErrorProne (Java) without a single warning [Source: 16_Response_Expert_Code_Quality_Best_Practices.md].
*   **AI Augmented Pipelines (Zero-Trust):** MCP-powered local IDE agents and autonomous CI pipelines generate tests and conduct semantic "LLM-as-a-Judge" code reviews [Source: 17_Response_Expert_LLM_Modern_Dev.md].

### 5.5. Application Security (AppSec)
*   **Zero Trust & Boundary Validation:** Absolute distrust at C-FFI boundaries. Use of `unsafe` Rust is highly regulated [Source: 18_Response_Expert_Security_AppSec.md].
*   **Secure Supply Chain (SSSC):** Requires SBOM generation (CycloneDX/SPDX), cryptographic artifacts signing via Sigstore/Cosign, and dependency quarantine scans [Source: 18_Response_Expert_Security_AppSec.md].
*   **Continuous Fuzzing:** Implementation of robust SAST (Semgrep) coupled with AFL++ automated fuzzing targets on Rust optimization endpoints [Source: 18_Response_Expert_Security_AppSec.md].