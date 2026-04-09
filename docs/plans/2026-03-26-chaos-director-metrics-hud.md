# Chaos Director & Metrics HUD Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Transform HexaRail into a deterministic benchmarking environment where users can program, save, and analyze multi-event crisis scenarios with real-time recovery metrics.

**Architecture:** 
- **Micro**: Rust engine gains a `ScenarioManager` to handle time-bound perturbations and a `HealthTracker` for $O(1)$ metrics export.
- **Meso**: Elixir Simulation Engine becomes "Scenario-Aware", managing the loading and automatic triggering of JSON-based event timelines.
- **Macro**: A LiveView HUD provides a "Director's Console" for scenario management and high-fidelity data visualization of system health.

**Tech Stack:** 
- **Backend**: Elixir/OTP, Rustler (NIFs), Petgraph.
- **Frontend**: Phoenix LiveView, Chart.js (or simple SVG gauges), Deck.gl.

---

### Task 1: Rust Domain - SystemHealth & Perturbation Structures

**Files:**
- Modify: `hexarail/native/hexacore_engine/src/domain.rs`
- Test: `hexarail/native/hexacore_engine/src/topology.rs` (Internal unit tests)

**Step 1: Define the structs in Rust**
```rust
#[derive(Debug, Clone, Serialize, Deserialize, rustler::NifStruct)]
#[module = "HexaCore.Domain.Perturbation"]
pub struct Perturbation {
    pub id: String,
    pub perturbation_type: String, // "infrastructure" | "vehicle" | "weather"
    pub target_id: String,
    pub start_time: i32,
    pub duration: i32,
}

#[derive(Debug, Clone, Serialize, Deserialize, rustler::NifStruct)]
#[module = "HexaCore.Domain.SystemHealth"]
pub struct SystemHealth {
    pub total_delay_seconds: i64,
    pub active_conflicts: i32,
    pub broken_connections: i32,
    pub active_perturbations: i32,
}
```

**Step 2: Add failing test for health calculation**
In `topology.rs` (at the bottom):
```rust
#[test]
fn test_health_with_active_delay() {
    let mut nm = NetworkManager::new();
    // Inject a dummy trip with delay
    // health = nm.get_health();
    // assert!(health.total_delay_seconds > 0);
}
```

**Step 3: Commit**
```bash
git add hexarail/native/hexacore_engine/src/domain.rs
git commit -m "feat(rust): define Perturbation and SystemHealth domain structures"
```

---

### Task 2: Rust Engine - ScenarioManager & Auto-Recovery

**Files:**
- Modify: `hexarail/native/hexacore_engine/src/topology.rs`
- Modify: `hexarail/native/hexacore_engine/src/lib.rs`

**Step 1: Implement registry in NetworkManager**
```rust
pub struct NetworkManager {
    // ...
    pub active_perturbations: Vec<crate::domain::Perturbation>,
}
```

**Step 2: Implement `apply_perturbations(time)`**
The logic must check `start_time <= time < (start_time + duration)`. 
If an event is active, it modifies the graph (removes edges or reduces weights).
If `time >= (start_time + duration)`, the edge is automatically restored (Auto-Recovery).

**Step 3: Expose `get_health` NIF**
```rust
#[rustler::nif]
fn get_system_health(resource: ResourceArc<NetworkResource>) -> domain::SystemHealth {
    let manager = resource.manager.read().unwrap();
    manager.calculate_health()
}
```

---

### Task 3: Elixir Control Plane - Scenario Schema & Persistence

**Files:**
- Create: `hexarail/lib/hexarail/simulation/scenario.ex`
- Create: `hexarail/priv/scenarios/gotthard_blackout.json`

**Step 1: Define Scenario JSON format**
**Step 2: Create Mix Task to load scenarios into the Engine**

---

### Task 4: UI - The Chaos Director Console (LiveView)

**Files:**
- Modify: `hexarail/lib/hexarail_web/live/twin_live.ex`
- Modify: `hexarail/lib/hexarail_web/live/twin_live.html.heex`

**Step 1: Implement the "Scenario Sidebar"**
A list of available JSON scenarios.
**Step 2: Implement the "Timeline Player"**
A visual indicator of where we are in the scenario's timeline.

---

### Task 5: UI - The Metrics HUD

**Files:**
- Modify: `hexarail/priv/static/js/app.js`
- Modify: `hexarail/lib/hexarail_web/live/twin_live.ex`

**Step 1: Stream SystemHealth data alongside positions**
**Step 2: Render SVG Gauges for Delay and Connectivity**
