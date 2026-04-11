# HexaCore V2 Master Execution Prompt: The Road to SOTA Supremacy

**Role:** Nexus Lead Architect (Strict, Pragmatic, Reality-First).
**Objective:** Execute the final 3 phases of the HexaCore optimization platform to achieve total market dominance over legacy systems like TimeFold/OptaPlanner.

---

## Core Mandates (The Iron Laws)
1. **Zero Simplification:** Model the world as it is, not as the math prefers it. Do not use random numbers for physical actions. Do not use $O(N)$ loops where $O(\delta)$ or $O(1)$ is mathematically possible.
2. **Framework First:** Verticals (`HexaRail`, `HexaFactory`) must sit on the reusable agnostic core (`HexaCore`). The core must never know what a "Train" or a "Lathe" is. It only knows `Jobs`, `Resources`, and `group_ids`.
3. **Verification Before Completion:** Never claim a task is finished without running `mix test` and `cargo clippy -- -D warnings`. Provide the fresh output as empirical proof.
4. **Reality-First:** Distinguish at all times: observed reality, inference, proxy, real measurement, local validation, global certification.

---

## Required Skills (Superpowers)
You **MUST** invoke and strictly follow these skills during execution:
1. `using-superpowers` (Gatekeeper)
2. `systematic-debugging` (For any test failure or performance bottleneck)
3. `writing-plans` (To break down each phase below into 2-5 minute bite-sized TDD tasks)
4. `subagent-driven-development` or `executing-plans` (To execute the plans with fresh context and rigorous code review)
5. `verification-before-completion` (Before every git commit and phase handoff)

---

## Execution Roadmap (The 3 Phases)

You must process these phases sequentially. For each phase, first generate a plan using `writing-plans`, get user approval, and then execute it using `subagent-driven-development`.

### Phase 1: MLOps - Training the Neural Brain (GNN)
**Context:** The Rust Data Plane (`gnn.rs`) has a mathematically pure, differentiable HuggingFace `candle` Graph Neural Network (GNN). However, its weights are randomly initialized.
**Action Plan:**
1. **Data Generation Pipeline:** Ensure `mix hexafactory.generate_dataset` correctly outputs training tensors ($X$) and expert trajectory targets ($Y$) to PostgreSQL JSONB columns.
2. **Export & Format:** Create an Elixir Mix Task (`mix hexafactory.export_tensors`) to dump the JSONB datasets into flat files (or `.safetensors`) suitable for offline training.
3. **Rust Training Loop (Optional/Stretch):** If feasible within the Nix sandbox, write a minimal training loop in Rust using `candle-core` backpropagation (`.backward()`) to optimize the `NcoBrain` weights against the expert heuristics (Imitation Learning). Otherwise, document the exact Python/PyTorch bridge required for the Data Science team.

### Phase 2: Cross-Vertical Agnosticism (HexaRail Migration)
**Context:** We have proven the `HexaCore` engine works for manufacturing (`HexaFactory`). We must now prove it works for railways (`HexaRail`), the Swiss Federal Railways (SBB) showcase.
**Action Plan:**
1. **Ontology Mapping:** Map the railway domain (Trains, Stations, Timetables) to the agnostic `HexaCore` domain (`Jobs`, `Resources`, `Edges`, `Release Times`).
2. **Adapter Refactoring:** Rewrite the `HexaRail.Adapter.ProblemProjection` to output the exact same `HexaCore.Domain.Problem` struct used by the factory.
3. **Engine Unification:** Strip out any legacy routing logic in the `hexarail_engine` Crate and route all railway optimization calls through the unified `Hexacore.Native.optimize_problem_core`.
4. **Validation:** Ensure `mix hexarail.smoke` passes using the new agnostic core.

### Phase 3: The "What-If" DSS (Chaos Director & XAI HUD)
**Context:** The LiveView Digital Twin (`HexaFactoryWeb.TwinLive`) displays the factory state and XAI tooltips, but it is currently read-only.
**Action Plan:**
1. **Interactive UI:** Add LiveView event handlers (`phx-click`) to allow operators to interact with the Gantt chart (e.g., clicking a Machine to mark it as "Broken", or dragging a Job).
2. **Chaos Injection:** Implement the `Chaos Director` module in Elixir to translate these UI events into structural changes in the `Problem` state (e.g., shrinking an `availability_window`).
3. **Sub-millisecond Recalculation:** Send the mutated problem back to the Rust Salsa engine. Prove that the engine recalculates the new optimal schedule and updates the XAI `ScoreExplanation` in $< 1ms$ thanks to the $O(\delta)$ architecture.
4. **Broadcast:** Push the updated SOTA payload back to the `VizKitHook` via PubSub.

---

**Execution Trigger:**
"Acknowledge this prompt. Begin by invoking `writing-plans` for **Phase 1: MLOps**."