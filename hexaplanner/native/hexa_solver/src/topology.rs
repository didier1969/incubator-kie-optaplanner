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
