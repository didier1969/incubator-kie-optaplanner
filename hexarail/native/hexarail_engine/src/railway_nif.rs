// Copyright (c) Didier Stadelmann. All rights reserved.

use crate::railway_topology;
use crate::{atoms, domain, railway_domain};
use petgraph::algo::astar;
use rustler::{Atom, ResourceArc};
use std::sync::RwLock;
use std::collections::HashMap;
use std::fs::File;
use std::io::BufReader;

#[derive(serde::Deserialize)]
struct OsmElement {
    #[serde(rename = "type")]
    element_type: String,
    id: i64,
    lat: Option<f64>,
    lon: Option<f64>,
    nodes: Option<Vec<i64>>,
    tags: Option<HashMap<String, String>>,
}

#[derive(serde::Deserialize)]
struct OsmData {
    elements: Vec<OsmElement>,
}

pub struct NetworkResource {
    pub manager: RwLock<railway_topology::NetworkManager>,
}

#[rustler::nif]
pub fn init_network() -> ResourceArc<NetworkResource> {
    ResourceArc::new(NetworkResource {
        manager: RwLock::new(railway_topology::NetworkManager::new()),
    })
}

#[rustler::nif]
pub fn load_stops(
    resource: ResourceArc<NetworkResource>,
    stops: Vec<railway_domain::GtfsStop>,
) -> usize {
    let mut manager = resource.manager.write().unwrap();
    manager.load_stops(stops);
    manager.physical.station_count()
}

#[rustler::nif]
pub fn load_trips(
    resource: ResourceArc<NetworkResource>,
    trips: Vec<railway_domain::GtfsTrip>,
) -> usize {
    let mut manager = resource.manager.write().unwrap();
    manager.load_trips(trips);
    manager.trips.len()
}

#[rustler::nif]
pub fn build_network_graph(edges: Vec<(String, String, Vec<(f64, f64)>)>) -> usize {
    let mut network = railway_topology::PhysicalNetwork::new();
    for (station_a, station_b, coords) in edges {
        let node_a = network.add_station(&station_a);
        let node_b = network.add_station(&station_b);
        network.add_track(node_a, node_b, coords, &std::collections::HashMap::new());
    }
    network.station_count()
}

#[rustler::nif]
pub fn get_conflict_summary(
    resource: ResourceArc<NetworkResource>,
) -> railway_domain::ConflictSummary {
    let manager = resource.manager.read().unwrap();
    manager.detect_conflicts()
}

#[rustler::nif]
pub fn load_stop_times(
    resource: ResourceArc<NetworkResource>,
    stop_times: Vec<railway_domain::GtfsStopTime>,
) -> usize {
    let mut manager = resource.manager.write().unwrap();
    manager.load_stop_times(stop_times);
    0
}

#[rustler::nif]
pub fn load_transfers(
    resource: ResourceArc<NetworkResource>,
    transfers: Vec<railway_domain::GtfsTransfer>,
) -> usize {
    let mut manager = resource.manager.write().unwrap();
    manager.load_transfers(transfers);
    manager.transfers.len()
}

#[rustler::nif]
pub fn load_calendars(
    resource: ResourceArc<NetworkResource>,
    calendars: Vec<railway_domain::GtfsCalendar>,
) -> usize {
    let mut manager = resource.manager.write().unwrap();
    manager.load_calendars(calendars);
    manager.calendars.len()
}

#[rustler::nif]
pub fn load_calendar_dates(
    resource: ResourceArc<NetworkResource>,
    dates: Vec<railway_domain::GtfsCalendarDate>,
) -> usize {
    let mut manager = resource.manager.write().unwrap();
    manager.load_calendar_dates(dates);
    manager.calendar_dates.len()
}

#[rustler::nif]
pub fn load_fleet(
    resource: ResourceArc<NetworkResource>,
    profiles: std::collections::HashMap<i64, railway_domain::RollingStockProfile>,
) -> usize {
    let mut manager = resource.manager.write().unwrap();
    manager.load_fleet(profiles);
    manager.fleet.len()
}

#[rustler::nif]
pub fn load_tracks(
    resource: ResourceArc<NetworkResource>,
    tracks: Vec<railway_domain::TrackSegment>,
) -> usize {
    let mut manager = resource.manager.write().unwrap();
    manager.load_tracks(tracks);
    manager.physical.track_count()
}

#[rustler::nif]
pub fn load_osm_from_json(
    resource: ResourceArc<NetworkResource>,
    path: String,
) -> Result<usize, String> {
    let mut manager = resource.manager.write().unwrap();

    let file = File::open(path).map_err(|e: std::io::Error| e.to_string())?;
    let reader = BufReader::new(file);
    let data: OsmData =
        serde_json::from_reader(reader).map_err(|e: serde_json::Error| e.to_string())?;

    let mut nodes = Vec::new();
    let mut ways = Vec::new();

    for element in data.elements {
        if element.element_type == "node" {
            nodes.push(railway_domain::OsmNode {
                id: element.id,
                lat: element.lat.unwrap_or(0.0),
                lon: element.lon.unwrap_or(0.0),
                tags: element.tags.unwrap_or_default(),
            });
        } else if element.element_type == "way" {
            ways.push(railway_domain::OsmWay {
                id: element.id,
                nodes: element.nodes.unwrap_or_default(),
                tags: element.tags.unwrap_or_default(),
            });
        }
    }

    manager.load_osm(nodes, ways);
    Ok(manager.micro.graph.edge_count())
}

#[rustler::nif]
pub fn load_osm(
    resource: ResourceArc<NetworkResource>,
    nodes: Vec<railway_domain::OsmNode>,
    ways: Vec<railway_domain::OsmWay>,
) -> usize {
    let mut manager = resource.manager.write().unwrap();
    manager.load_osm(nodes, ways);
    manager.micro.graph.edge_count()
}

#[rustler::nif]
pub fn route_micro_path(
    resource: ResourceArc<NetworkResource>,
    start_id: i64,
    end_id: i64,
) -> Vec<i64> {
    let manager = resource.manager.read().unwrap();

    if let (Some(&start_node), Some(&end_node)) = (
        manager.micro.node_map.get(&start_id),
        manager.micro.node_map.get(&end_id),
    ) {
        if let Some((_, path_nodes)) = astar(
            &manager.micro.graph,
            start_node,
            |finish| finish == end_node,
            |edge| *edge.weight(),
            |_| 0.0,
        ) {
            return path_nodes
                .into_iter()
                .map(|node| manager.micro.graph[node])
                .collect();
        }
    }

    vec![]
}

#[rustler::nif]
pub fn route_micro_path_with_kinematics(
    resource: ResourceArc<NetworkResource>,
    start_id: i64,
    end_id: i64,
    fleet_id: i64,
) -> (Vec<i64>, f64) {
    let manager = resource.manager.read().unwrap();

    let mut base_speed_ms = 80.0 / 3.6;
    let mut acceleration = 0.5;

    if let Some(profile) = manager.fleet.get(&fleet_id) {
        base_speed_ms = profile.max_speed_kmh / 3.6;
        acceleration = profile.acceleration_ms2;
    }

    if let (Some(&start_node), Some(&end_node)) = (
        manager.micro.node_map.get(&start_id),
        manager.micro.node_map.get(&end_id),
    ) {
        if let Some((total_cost, path_nodes)) = astar(
            &manager.micro.graph,
            start_node,
            |finish| finish == end_node,
            |edge| {
                let distance = *edge.weight();

                let mut speed = base_speed_ms;
                let mut penalty = 0.0;

                if distance > 200.0 {
                    speed *= 0.5;
                } else if distance > 30.0 {
                    speed = 11.1;
                    let delta_v = base_speed_ms - speed;
                    if delta_v > 0.0 {
                        penalty = (delta_v / acceleration) * 2.0;
                    }
                }

                let base_time = distance / speed;
                base_time + penalty
            },
            |_| 0.0,
        ) {
            let path_ids = path_nodes
                .into_iter()
                .map(|node| manager.micro.graph[node])
                .collect();
            return (path_ids, total_cost);
        }
    }

    (vec![], 0.0)
}

#[rustler::nif]
pub fn stitch_osm_to_macro(resource: ResourceArc<NetworkResource>) -> bool {
    let mut manager = resource.manager.write().unwrap();
    manager.stitch_osm_to_macro();
    true
}

#[rustler::nif]
pub fn get_all_tracks(
    resource: ResourceArc<NetworkResource>,
) -> Vec<railway_domain::TrackSegment> {
    let manager = resource.manager.read().unwrap();
    manager.physical.all_tracks.clone()
}

#[rustler::nif]
pub fn get_train_position(
    resource: ResourceArc<NetworkResource>,
    trip_id: i64,
    time: i32,
) -> Option<(f64, f64)> {
    let mut manager = resource.manager.write().unwrap();
    manager.apply_perturbations(time);
    manager.get_position(trip_id, time)
}

#[rustler::nif(schedule = "DirtyCpu")]
pub fn get_active_positions(
    resource: ResourceArc<NetworkResource>,
    time: i32,
) -> Vec<railway_domain::ActivePosition> {
    let mut manager = resource.manager.write().unwrap();
    manager.apply_perturbations(time);
    manager.get_active_positions(time)
}

#[rustler::nif]
pub fn load_dem(resource: ResourceArc<NetworkResource>, dem: domain::DemGrid) -> Atom {
    let mut manager = resource.manager.write().unwrap();
    manager.load_dem(dem);
    atoms::ok()
}

#[rustler::nif]
pub fn load_perturbations(
    resource: ResourceArc<NetworkResource>,
    perturbations: Vec<railway_domain::Perturbation>,
) -> Atom {
    let mut manager = resource.manager.write().unwrap();
    manager.load_perturbations(perturbations);
    atoms::ok()
}

#[rustler::nif]
pub fn get_system_health(
    resource: ResourceArc<NetworkResource>,
) -> railway_domain::SystemHealth {
    let manager = resource.manager.read().unwrap();
    manager.calculate_health()
}

#[rustler::nif]
pub fn finalize_temporal_graph(resource: ResourceArc<NetworkResource>) -> usize {
    let mut manager = resource.manager.write().unwrap();
    manager.finalize_temporal_graph()
}

#[rustler::nif]
pub fn detect_conflicts(
    resource: ResourceArc<NetworkResource>,
) -> railway_domain::ConflictSummary {
    let manager = resource.manager.read().unwrap();
    manager.detect_conflicts()
}

#[rustler::nif]
pub fn freeze_state(
    resource: ResourceArc<NetworkResource>,
    path: String,
) -> Result<String, rustler::Error> {
    let manager = resource.manager.read().unwrap();
    match manager.freeze_state(&path) {
        Ok(()) => Ok("ok".to_string()),
        Err(error) => Err(rustler::Error::Term(Box::new(error))),
    }
}

#[rustler::nif]
pub fn thaw_state(
    resource: ResourceArc<NetworkResource>,
    path: String,
) -> Result<String, rustler::Error> {
    let mut manager = resource.manager.write().unwrap();
    match manager.thaw_state(&path) {
        Ok(()) => Ok("ok".to_string()),
        Err(error) => Err(rustler::Error::Term(Box::new(error))),
    }
}

#[rustler::nif]
pub fn inject_delay(
    resource: ResourceArc<NetworkResource>,
    trip_id: i64,
    delay_seconds: i32,
) -> rustler::Atom {
    let mut manager = resource.manager.write().unwrap();
    match manager.inject_delay(trip_id, delay_seconds) {
        Ok(()) => rustler::types::atom::ok(),
        Err(_) => rustler::types::atom::error(),
    }
}

#[rustler::nif]
pub fn resolve_conflict_greedy(
    resource: ResourceArc<NetworkResource>,
) -> railway_domain::ResolutionMetrics {
    let mut manager = resource.manager.write().unwrap();
    manager.resolve_conflict_greedy()
}

#[rustler::nif]
pub fn resolve_conflict_local_search(
    resource: ResourceArc<NetworkResource>,
) -> railway_domain::ResolutionMetrics {
    let mut manager = resource.manager.write().unwrap();
    manager.resolve_conflict_local_search()
}
