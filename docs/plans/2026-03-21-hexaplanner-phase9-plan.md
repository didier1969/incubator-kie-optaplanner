# HexaRail Phase 9 Implementation Plan: Graphe Topologique Exact (Rust)

> **For Claude/Gemini:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Create the topological representation of the railway network in the Rust engine using a graph library. This graph will allow the solver to calculate paths, distances, and enforce physical constraints (e.g., single tracks, capacity limits) between the GTFS stops ingested in Phase 8. We will serialize this data from Elixir to Rust.

**Architecture:** Rust (Data Plane) / `petgraph` library.

**Tech Stack:** Rust, `petgraph`, `rustler`.

---

### Task 1: Add Graph Library to Rust Engine

**Files:**
- Modify: `hexarail/native/hexa_solver/Cargo.toml`

**Step 1: Write the failing check**
Run: `nix develop -c bash -c "cd hexarail/native/hexa_solver && cargo tree | grep petgraph"`
Expected: FAIL

**Step 2: Write minimal implementation**
Add `petgraph` to the Rust project dependencies.
```toml
[dependencies]
petgraph = "0.6.5"
```

**Step 3: Run check to verify it passes**
Run: `nix develop -c bash -c "cd hexarail/native/hexa_solver && cargo update && cargo tree | grep petgraph"`
Expected: PASS

**Step 4: Commit**
```bash
git add hexarail/native/hexa_solver/Cargo.toml hexarail/native/hexa_solver/Cargo.lock
git commit -m "chore(deps): add petgraph for exact topological network modeling"
```

---

### Task 2: Model the Physical Network Graph

**Files:**
- Create: `hexarail/native/hexa_solver/src/topology.rs`
- Modify: `hexarail/native/hexa_solver/src/lib.rs`

**Step 1: Write the failing test**
Create `hexarail/native/hexa_solver/src/topology.rs` with a basic test:
```rust
#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_network_graph_creation() {
        let mut network = PhysicalNetwork::new();
        let bern = network.add_station("8507000");
        let zurich = network.add_station("8503000");
        
        network.add_track(bern, zurich, 120.5); // 120.5 km
        
        assert_eq!(network.station_count(), 2);
        assert_eq!(network.track_count(), 1);
    }
}
```

**Step 2: Run test to verify it fails**
Run: `nix develop -c bash -c "cd hexarail/native/hexa_solver && cargo test topology"`
Expected: FAIL

**Step 3: Write minimal implementation**
Implement the graph wrapper using `petgraph`.
```rust
use petgraph::graph::{NodeIndex, UnGraph};
use std::collections::HashMap;

pub struct PhysicalNetwork {
    graph: UnGraph<String, f64>, // Node: Station ID, Edge: Distance/Weight
    station_map: HashMap<String, NodeIndex>,
}

impl PhysicalNetwork {
    #[must_use]
    pub fn new() -> Self {
        Self {
            graph: UnGraph::new_undirected(),
            station_map: HashMap::new(),
        }
    }

    pub fn add_station(&mut self, station_id: &str) -> NodeIndex {
        let id_str = station_id.to_string();
        if let Some(&index) = self.station_map.get(&id_str) {
            return index;
        }
        let index = self.graph.add_node(id_str.clone());
        self.station_map.insert(id_str, index);
        index
    }

    pub fn add_track(&mut self, a: NodeIndex, b: NodeIndex, weight: f64) {
        self.graph.add_edge(a, b, weight);
    }

    #[must_use]
    pub fn station_count(&self) -> usize {
        self.graph.node_count()
    }

    #[must_use]
    pub fn track_count(&self) -> usize {
        self.graph.edge_count()
    }
}

impl Default for PhysicalNetwork {
    fn default() -> Self {
        Self::new()
    }
}
```
Add `pub mod topology;` to `lib.rs`.

**Step 4: Run test to verify it passes**
Run: `nix develop -c bash -c "cd hexarail/native/hexa_solver && cargo test topology"`
Expected: PASS

**Step 5: Commit**
```bash
git add hexarail/native/hexa_solver/src/
git commit -m "feat(topology): model physical railway network using petgraph"
```

---

### Task 3: Expose Topology Ingestion to Elixir via NIF

**Files:**
- Modify: `hexarail/native/hexa_solver/src/lib.rs`
- Modify: `hexarail/lib/hexarail/solver_nif.ex`
- Create: `hexarail/test/topology_nif_test.exs`

**Step 1: Write the failing test**
Create Elixir test for pushing a list of edges to build the graph.
```elixir
# hexarail/test/topology_nif_test.exs
defmodule HexaRail.TopologyNifTest do
  use ExUnit.Case

  test "can build rust topological graph via NIF" do
    # Edges: {StationA, StationB, Distance_km}
    edges = [
      {"8507000", "8503000", 120.5},
      {"8501008", "8507000", 160.0}
    ]
    
    # Should return the number of nodes built in Rust
    assert HexaRail.SolverNif.build_network_graph(edges) == 3
  end
end
```

**Step 2: Run test to verify it fails**
Run: `nix develop -c bash -c "cd hexarail && mix test test/topology_nif_test.exs"`
Expected: FAIL (Undefined function)

**Step 3: Write minimal implementation**
1. Add NIF stub in `solver_nif.ex`:
```elixir
  def build_network_graph(_edges), do: :erlang.nif_error(:nif_not_loaded)
```
2. Implement NIF in `lib.rs`:
```rust
#[rustler::nif]
fn build_network_graph(edges: Vec<(String, String, f64)>) -> usize {
    let mut network = topology::PhysicalNetwork::new();
    for (station_a, station_b, weight) in edges {
        let node_a = network.add_station(&station_a);
        let node_b = network.add_station(&station_b);
        network.add_track(node_a, node_b, weight);
    }
    network.station_count()
}
// Add `build_network_graph` to the rustler::init! array
```

**Step 4: Run test to verify it passes**
Run: `nix develop -c bash -c "cd hexarail && mix test test/topology_nif_test.exs"`
Expected: PASS

**Step 5: Commit**
```bash
git add hexarail/
git commit -m "feat(bridge): implement NIF to ingest topological edges into rust graph"
```