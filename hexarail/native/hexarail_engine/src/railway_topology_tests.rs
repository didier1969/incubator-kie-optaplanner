// Copyright (c) Didier Stadelmann. All rights reserved.

use crate::railway_topology::PhysicalNetwork;

#[test]
fn test_network_graph_creation() {
    let mut network = PhysicalNetwork::new();
    let bern = network.add_station("BN");
    let zurich = network.add_station("ZUE");
    network.add_track(
        bern,
        zurich,
        vec![(7.4, 46.9), (8.5, 47.3)],
        &std::collections::HashMap::new(),
    );
    assert_eq!(network.station_count(), 2);
}
