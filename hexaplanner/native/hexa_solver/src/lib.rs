#![deny(warnings)]
#![deny(clippy::all)]
#![deny(clippy::pedantic)]
#![allow(non_local_definitions)]
#![allow(clippy::needless_pass_by_value)]
#![allow(clippy::type_complexity)]

pub mod domain;
pub mod incremental_score;
pub mod score;
pub mod solver;
pub mod topology;

use rustler::{Env, ResourceArc, Term};
use std::sync::RwLock;
use crate::topology::NetworkManager;

pub struct NetworkResource {
    pub manager: RwLock<NetworkManager>,
}

#[rustler::nif]
fn evaluate_problem(resource: ResourceArc<NetworkResource>, problem: domain::Problem) -> i64 {
    let manager = resource.manager.read().unwrap();
    score::calculate_score(&problem, &manager)
}

#[rustler::nif]
fn add(a: i64, b: i64) -> i64 {
    a + b
}

#[rustler::nif]
#[allow(clippy::needless_pass_by_value)]
fn optimize_problem(resource: ResourceArc<NetworkResource>, problem: domain::Problem, iterations: i32) -> domain::Problem {
    let manager = resource.manager.read().unwrap();
    solver::optimize(problem, &manager, iterations)
}

#[rustler::nif]
fn init_network() -> ResourceArc<NetworkResource> {
    ResourceArc::new(NetworkResource {
        manager: RwLock::new(NetworkManager::new()),
    })
}

#[rustler::nif]
fn load_stops(resource: ResourceArc<NetworkResource>, stops: Vec<domain::GtfsStop>) -> usize {
    let mut manager = resource.manager.write().unwrap();
    manager.load_stops(stops);
    manager.physical.station_count()
}

#[rustler::nif]
fn build_network_graph(edges: Vec<(String, String, Vec<(f64, f64)>)>) -> usize {
    let mut network = topology::PhysicalNetwork::new();
    for (station_a, station_b, coords) in edges {
        let node_a = network.add_station(&station_a);
        let node_b = network.add_station(&station_b);
        network.add_track(node_a, node_b, coords);
    }
    network.station_count()
}

#[rustler::nif]
fn load_stop_times(resource: ResourceArc<NetworkResource>, stop_times: Vec<domain::GtfsStopTime>) -> usize {
    let mut manager = resource.manager.write().unwrap();
    manager.load_stop_times(stop_times);
    0
}

#[rustler::nif]
fn load_transfers(resource: ResourceArc<NetworkResource>, transfers: Vec<domain::GtfsTransfer>) -> usize {
    let mut manager = resource.manager.write().unwrap();
    manager.load_transfers(transfers);
    manager.transfers.len()
}

#[rustler::nif]
fn load_calendars(resource: ResourceArc<NetworkResource>, calendars: Vec<domain::GtfsCalendar>) -> usize {
    let mut manager = resource.manager.write().unwrap();
    manager.load_calendars(calendars);
    manager.calendars.len()
}

#[rustler::nif]
fn load_calendar_dates(resource: ResourceArc<NetworkResource>, dates: Vec<domain::GtfsCalendarDate>) -> usize {
    let mut manager = resource.manager.write().unwrap();
    manager.load_calendar_dates(dates);
    manager.calendar_dates.len()
}

#[rustler::nif]
fn load_fleet(resource: ResourceArc<NetworkResource>, profiles: std::collections::HashMap<i64, domain::RollingStockProfile>) -> usize {
    let mut manager = resource.manager.write().unwrap();
    manager.load_fleet(profiles);
    manager.fleet.len()
}

#[rustler::nif]
fn load_tracks(resource: ResourceArc<NetworkResource>, tracks: Vec<domain::TrackSegment>) -> usize {
    let mut manager = resource.manager.write().unwrap();
    manager.load_tracks(tracks);
    manager.physical.track_count()
}

#[rustler::nif]
fn load_osm(resource: ResourceArc<NetworkResource>, nodes: Vec<domain::OsmNode>, ways: Vec<domain::OsmWay>) -> usize {
    let mut manager = resource.manager.write().unwrap();
    manager.load_osm(nodes, ways);
    manager.micro.graph.edge_count()
}

#[rustler::nif]
fn stitch_osm_to_macro(resource: ResourceArc<NetworkResource>) -> bool {
    let mut manager = resource.manager.write().unwrap();
    manager.stitch_osm_to_macro();
    true
}

#[rustler::nif]
fn get_all_tracks(resource: ResourceArc<NetworkResource>) -> Vec<domain::TrackSegment> {
    let manager = resource.manager.read().unwrap();
    manager.physical.all_tracks.clone()
}

#[rustler::nif]
fn get_train_position(
    resource: ResourceArc<NetworkResource>,
    trip_id: i64,
    time: i32,
) -> Option<(f64, f64)> {
    let manager = resource.manager.read().unwrap();
    manager.get_position(trip_id, time)
}

#[rustler::nif]
fn get_active_positions(
    resource: ResourceArc<NetworkResource>,
    time: i32,
) -> Vec<(i64, f64, f64)> {
    let manager = resource.manager.read().unwrap();
    manager.get_active_positions(time)
}

#[rustler::nif]
fn finalize_temporal_graph(resource: ResourceArc<NetworkResource>) -> usize {
    let mut manager = resource.manager.write().unwrap();
    manager.finalize_temporal_graph()
}

#[rustler::nif]
fn detect_conflicts(resource: ResourceArc<NetworkResource>) -> domain::ConflictSummary {
    let manager = resource.manager.read().unwrap();
    manager.detect_conflicts()
}

fn load(env: Env, _info: Term) -> bool {
    let _ = rustler::resource!(NetworkResource, env);
    true
}

rustler::init!("Elixir.HexaPlanner.SolverNif", load = load);
