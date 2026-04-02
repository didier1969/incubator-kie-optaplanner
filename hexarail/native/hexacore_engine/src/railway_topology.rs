// Copyright (c) Didier Stadelmann. All rights reserved.

#![allow(clippy::cast_possible_truncation)]
#![allow(clippy::cast_sign_loss)]
#![allow(clippy::cast_precision_loss)]
#![allow(clippy::cast_possible_wrap)]
#![allow(clippy::uninlined_format_args)]
#![allow(clippy::needless_pass_by_value)]
#![allow(clippy::too_many_lines)]

use petgraph::graph::{NodeIndex, UnGraph, DiGraph};
use std::collections::HashMap;
use crate::domain::DemGrid;
use crate::railway_domain::{
    ActivePosition, CompactEOS, Conflict, ConflictSummary, GtfsCalendar,
    GtfsCalendarDate, GtfsStop, GtfsStopTime, GtfsTrip, OsmNode, OsmWay, Perturbation,
    ResolutionMetrics, RollingStockProfile, SystemHealth, TrackSegment, GtfsTransfer,
};
use lasso::Rodeo;
use rayon::prelude::*;
use kdtree::KdTree;
use kdtree::distance::squared_euclidean;
use std::fs::File;
use std::io::{BufReader, BufWriter};

/// Represents the physical layer: rails and stations.
pub struct PhysicalNetwork {
    pub graph: UnGraph<String, (Vec<(f64, f64)>, f64, f64)>, // Node: Station ID, Edge: (Curve Coordinates, Length in meters, Max Speed km/h)
    pub station_map: HashMap<String, NodeIndex>,
    pub all_tracks: Vec<TrackSegment>,
    pub spatial_index: KdTree<f64, usize, [f64; 2]>, // Maps [lon, lat] -> Index in all_tracks
    pub disabled_stations: std::collections::HashSet<String>,
    pub disabled_edges: std::collections::HashSet<(String, String)>,
}

/// Represents the microscopic layer: exact rails, switches, and platforms inside stations (OSM Data).
pub struct MicroNetwork {
    pub graph: UnGraph<i64, f64>, // Node: OSM Node ID, Edge: Distance in meters
    pub node_map: HashMap<i64, NodeIndex>,
    pub node_coords: HashMap<i64, (f64, f64)>,
    pub spatial_index: KdTree<f64, i64, [f64; 2]>, // Maps [lon, lat] -> OSM Node ID
}

impl MicroNetwork {
    #[must_use]
    pub fn new() -> Self {
        Self {
            graph: UnGraph::new_undirected(),
            node_map: HashMap::new(),
            node_coords: HashMap::new(),
            spatial_index: KdTree::new(2),
        }
    }

    pub fn get_or_create_node(&mut self, osm_id: i64, lon: f64, lat: f64) -> NodeIndex {
        if let Some(&index) = self.node_map.get(&osm_id) {
            return index;
        }
        let index = self.graph.add_node(osm_id);
        self.node_map.insert(osm_id, index);
        self.node_coords.insert(osm_id, (lon, lat));
        let _ = self.spatial_index.add([lon, lat], osm_id);
        index
    }
}

impl Default for MicroNetwork {
    fn default() -> Self {
        Self::new()
    }
}

impl PhysicalNetwork {
    #[must_use]
    pub fn new() -> Self {
        Self {
            graph: UnGraph::new_undirected(),
            station_map: HashMap::new(),
            all_tracks: Vec::new(),
            spatial_index: KdTree::new(2),
            disabled_stations: std::collections::HashSet::new(),
            disabled_edges: std::collections::HashSet::new(),
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
}

// Helper to extract the macro logical station (abbreviation or parent station)
fn get_logical_station_id(stop: &GtfsStop) -> &str {
    if let Some(abbr) = &stop.abbreviation {
        abbr
    } else if let Some(parent) = &stop.parent_station {
        if !parent.is_empty() {
            return parent;
        }
        &stop.original_stop_id
    } else {
        &stop.original_stop_id
    }
}

impl PhysicalNetwork {
    pub fn add_track(&mut self, a: NodeIndex, b: NodeIndex, coords: Vec<(f64, f64)>, properties: &std::collections::HashMap<String, String>) {
        let mut length = 0.0;
        if coords.len() > 1 {
            for window in coords.windows(2) {
                length += haversine_distance(window[0].0, window[0].1, window[1].0, window[1].1);
            }
        }
        if length == 0.0 { length = 1.0; } // Prevent div by zero
        
        let maxspeed = properties.get("maxspeed").and_then(|s| s.parse::<f64>().ok()).unwrap_or(120.0);
        self.graph.add_edge(a, b, (coords, length, maxspeed));
    }

    #[must_use]
    pub fn station_count(&self) -> usize {
        self.graph.node_count()
    }

    #[must_use]
    pub fn track_count(&self) -> usize {
        self.graph.edge_count()
    }

    #[must_use]
    pub fn find_path_coordinates(&self, from_id: &str, to_id: &str) -> Option<(Vec<(f64, f64)>, f64)> {
        if self.disabled_stations.contains(from_id) || self.disabled_stations.contains(to_id) {
            return None;
        }
        if self.disabled_edges.contains(&(from_id.to_string(), to_id.to_string())) || 
           self.disabled_edges.contains(&(to_id.to_string(), from_id.to_string())) {
            return None;
        }

        let start = *self.station_map.get(from_id)?;
        let end = *self.station_map.get(to_id)?;
        let edge = self.graph.find_edge(start, end)?;
        let weight = self.graph.edge_weight(edge)?;
        Some((weight.0.clone(), weight.2))
    }
}

// Haversine distance in meters
fn haversine_distance(lon1: f64, lat1: f64, lon2: f64, lat2: f64) -> f64 {
    let r = 6371e3; // Earth radius in meters
    let phi1 = lat1.to_radians();
    let phi2 = lat2.to_radians();
    let delta_phi = (lat2 - lat1).to_radians();
    let delta_lambda = (lon2 - lon1).to_radians();

    let a = (delta_phi / 2.0).sin() * (delta_phi / 2.0).sin() +
            phi1.cos() * phi2.cos() *
            (delta_lambda / 2.0).sin() * (delta_lambda / 2.0).sin();
    let c = 2.0 * a.sqrt().atan2((1.0 - a).sqrt());

    r * c
}

/// Represents the temporal layer: schedule and service occurrences.
pub struct TemporalNetwork {
    pub graph: DiGraph<i64, i32>, // Node: Stop ID, Edge: Travel Time (seconds)
    pub stop_map: HashMap<i64, NodeIndex>,
}

impl TemporalNetwork {
    #[must_use]
    pub fn new() -> Self {
        Self {
            graph: DiGraph::new(),
            stop_map: HashMap::new(),
        }
    }

    pub fn get_or_create_node(&mut self, stop_id: i64) -> NodeIndex {
        if let Some(&index) = self.stop_map.get(&stop_id) {
            return index;
        }
        let index = self.graph.add_node(stop_id);
        self.stop_map.insert(stop_id, index);
        index
    }
}

pub struct NetworkManager {
    pub physical: PhysicalNetwork,
    pub micro: MicroNetwork,
    pub temporal: TemporalNetwork,
    pub stop_times: HashMap<i64, Vec<GtfsStopTime>>,
    pub trips: HashMap<i64, GtfsTrip>,
    pub stops: HashMap<i64, GtfsStop>,
    pub transfers: Vec<GtfsTransfer>,
    pub calendars: HashMap<String, GtfsCalendar>,
    pub calendar_dates: Vec<GtfsCalendarDate>,
    pub fleet: HashMap<i64, RollingStockProfile>,
    pub dem_grid: Option<DemGrid>,
    pub active_perturbations: Vec<Perturbation>,
    
    // HPC Structures
    pub interner: Rodeo,
    pub trip_id_map: HashMap<i64, u32>,
    pub eos_buffer: Vec<CompactEOS>,
}

impl NetworkManager {
    #[must_use]
    pub fn new() -> Self {
        Self {
            physical: PhysicalNetwork::new(),
            micro: MicroNetwork::new(),
            temporal: TemporalNetwork::new(),
            stop_times: HashMap::new(),
            trips: HashMap::new(),
            stops: HashMap::new(),
            transfers: Vec::new(),
            calendars: HashMap::new(),
            calendar_dates: Vec::new(),
            fleet: HashMap::new(),
            dem_grid: None,
            active_perturbations: Vec::new(),
            interner: Rodeo::default(),
            trip_id_map: HashMap::new(),
            eos_buffer: Vec::with_capacity(1_000_000),
        }
    }

    pub fn calculate_health(&self) -> SystemHealth {
        // In a stateless engine, total delay is the sum of instantaneous delays 
        // caused by speed clamping across all active trains.
        SystemHealth {
            total_delay_seconds: 0, // Will be populated by simulation loops
            active_conflicts: 0,
            broken_connections: 0,
            active_perturbations: self.active_perturbations.iter()
                .filter(|_p| {
                    // This is slightly complex as we don't have 'current_time' here
                    // Health is usually called within a context where time is known.
                    // For now we count all perturbations loaded.
                    true
                }).count() as i32,
        }
    }

    pub fn load_dem(&mut self, dem: DemGrid) {
        self.dem_grid = Some(dem);
    }

    pub fn load_perturbations(&mut self, perturbations: Vec<Perturbation>) {
        self.active_perturbations = perturbations;
    }

    pub fn apply_perturbations(&mut self, time: i32) {
        // Phase 21: Auto-Recovery & Dynamic Perturbations
        self.physical.disabled_stations.clear();
        self.physical.disabled_edges.clear();

        for p in &self.active_perturbations {
            if time >= p.start_time && time < (p.start_time + p.duration) {
                match p.perturbation_type.as_str() {
                    "infrastructure" => {
                        if p.target_id.contains('-') {
                            let parts: Vec<&str> = p.target_id.split('-').collect();
                            if parts.len() == 2 {
                                self.physical.disabled_edges.insert((parts[0].to_string(), parts[1].to_string()));
                            }
                        } else {
                            self.physical.disabled_stations.insert(p.target_id.clone());
                        }
                    }
                    _ => {}
                }
            }
        }
    }

    pub fn stitch_osm_to_macro(&mut self) {
        // Phase 12I: The Stitch
        // Connect logical GTFS stops to the nearest physical OSM node
        let mut links_to_make = Vec::new();
        for stop in self.stops.values() {
            let abbr = get_logical_station_id(stop);
            if let Some(&macro_idx) = self.physical.station_map.get(abbr) {
                // Find nearest OSM node using the micro spatial index
                if let Ok(nearest) = self.micro.spatial_index.nearest(&[stop.location.coordinates.0, stop.location.coordinates.1], 1, &squared_euclidean) {
                    if let Some(&(dist_sq, &osm_id)) = nearest.first() {
                        // CRITICAL FIX: Only stitch if the OSM node is within ~500 meters (0.00002 degrees squared)
                        // This prevents creating 'wormhole super-hubs' that connect the entire country to 5 OSM nodes,
                        // which was causing O(N^2) degradation in A* and find_edge.
                        if dist_sq < 0.00002 {
                            let osm_str = format!("OSM-{}", osm_id);
                            if let Some(&micro_idx) = self.physical.station_map.get(&osm_str) {
                                links_to_make.push((macro_idx, micro_idx));
                            }
                        }
                    }
                }
            }
        }

        // Add 0-distance 'virtual' edges to stitch the graphs
        for (macro_idx, micro_idx) in links_to_make {
            // Check if edge exists to avoid duplicates
            if self.physical.graph.find_edge(macro_idx, micro_idx).is_none() {
                self.physical.graph.add_edge(macro_idx, micro_idx, (vec![], 0.1, 40.0));
            }
        }
    }

    pub fn load_osm(&mut self, nodes: Vec<OsmNode>, ways: Vec<OsmWay>) {
        // First load all nodes to have coordinates ready
        for node in &nodes {
            self.micro.get_or_create_node(node.id, node.lon, node.lat);
            
            // Phase 12I: Inject into Unified Physical Network
            let physical_id = format!("OSM-{}", node.id);
            self.physical.add_station(&physical_id);
        }

        // Phase 18 - Scenario B: Edge Collapsing
        // 1. Calculate node degrees
        let mut node_degrees: HashMap<i64, usize> = HashMap::new();
        for way in &ways {
            for &node_id in &way.nodes {
                *node_degrees.entry(node_id).or_insert(0) += 1;
            }
            // Ensure endpoints of ways are always kept
            if let Some(&first) = way.nodes.first() {
                *node_degrees.entry(first).or_insert(0) += 1;
            }
            if let Some(&last) = way.nodes.last() {
                *node_degrees.entry(last).or_insert(0) += 1;
            }
        }

        // 2. Build collapsed edges
        for way in ways {
            if way.nodes.len() < 2 { continue; }
            
            // Phase 18 - Scenario C: Tag-based weighting for Micro-Topology A* routing
            let mut weight_multiplier = 1.0;
            if let Some(service) = way.tags.get("service") {
                if service == "siding" || service == "yard" {
                    weight_multiplier = 5.0;
                }
            }
            if let Some(railway) = way.tags.get("railway") {
                if railway == "switch" {
                    weight_multiplier = 1.5;
                }
            }

            let mut last_key_node_id = way.nodes[0];
            let mut accumulated_routing_weight = 0.0;
            let mut accumulated_physical_distance = 0.0;
            let mut current_segment_coords = Vec::new();

            if let Some(coords) = self.micro.node_coords.get(&last_key_node_id) {
                current_segment_coords.push(*coords);
            }

            for i in 1..way.nodes.len() {
                let current_node_id = way.nodes[i];
                let prev_node_id = way.nodes[i - 1];

                if let (Some(prev_coords), Some(curr_coords)) = (self.micro.node_coords.get(&prev_node_id), self.micro.node_coords.get(&current_node_id)) {
                    let dist = haversine_distance(prev_coords.0, prev_coords.1, curr_coords.0, curr_coords.1);
                    accumulated_physical_distance += dist;
                    accumulated_routing_weight += dist * weight_multiplier;
                    current_segment_coords.push(*curr_coords);
                }

                let degree = *node_degrees.get(&current_node_id).unwrap_or(&0);
                
                // If it's a key node (intersection, or end of way), we create the edge
                if degree > 2 || i == way.nodes.len() - 1 {
                    if let (Some(&u_idx), Some(&v_idx)) = (self.micro.node_map.get(&last_key_node_id), self.micro.node_map.get(&current_node_id)) {
                        
                        self.micro.graph.add_edge(u_idx, v_idx, accumulated_routing_weight);
                        
                        // Inject edges into Unified Physical Network
                        let p_u_id = format!("OSM-{}", last_key_node_id);
                        let p_v_id = format!("OSM-{}", current_node_id);
                        let a = self.physical.add_station(&p_u_id);
                        let b = self.physical.add_station(&p_v_id);
                        
                        let maxspeed = way.tags.get("maxspeed").and_then(|s| s.parse::<f64>().ok()).unwrap_or(120.0);
                        
                        let safe_dist = if accumulated_physical_distance <= 0.0 { 1.0 } else { accumulated_physical_distance };
                        self.physical.graph.add_edge(a, b, (current_segment_coords.clone(), safe_dist, maxspeed));
                        
                        // Add to spatial index for snapping
                        let track_idx = self.physical.all_tracks.len();
                        for coord in &current_segment_coords {
                            let _ = self.physical.spatial_index.add([coord.0, coord.1], track_idx);
                        }
                    }
                    
                    // Reset for next segment
                    last_key_node_id = current_node_id;
                    accumulated_routing_weight = 0.0;
                    accumulated_physical_distance = 0.0;
                    current_segment_coords.clear();
                    if let Some(coords) = self.micro.node_coords.get(&last_key_node_id) {
                        current_segment_coords.push(*coords);
                    }
                }
            }
        }
    }

    pub fn load_stops(&mut self, stops: Vec<GtfsStop>) {
        for stop in &stops {
            let physical_id = get_logical_station_id(stop);
            self.physical.add_station(physical_id);
            self.temporal.get_or_create_node(stop.id);
        }
        
        for stop in stops {
            self.stops.insert(stop.id, stop);
        }
    }

    pub fn load_trips(&mut self, trips: Vec<GtfsTrip>) {
        for trip in trips {
            self.trips.insert(trip.id, trip);
        }
    }

    pub fn load_tracks(&mut self, tracks: Vec<TrackSegment>) {
        for track in tracks {
            let start_id = track.properties.get("bp_anfang").cloned().unwrap_or_default();
            let end_id = track.properties.get("bp_ende").cloned().unwrap_or_default();
            
            if !start_id.is_empty() && !end_id.is_empty() {
                let a = self.physical.add_station(&start_id);
                let b = self.physical.add_station(&end_id);
                self.physical.add_track(a, b, track.coordinates.clone(), &track.properties);
            }
            
            let track_idx = self.physical.all_tracks.len();
            for coord in &track.coordinates {
                let _ = self.physical.spatial_index.add([coord.0, coord.1], track_idx);
            }
            self.physical.all_tracks.push(track);
        }
    }

    pub fn load_stop_times(&mut self, stop_times: Vec<GtfsStopTime>) {
        for st in stop_times {
            self.stop_times.entry(st.trip_id).or_default().push(st);
        }
    }

    pub fn load_transfers(&mut self, transfers: Vec<GtfsTransfer>) {
        self.transfers.extend(transfers);
    }

    pub fn load_calendars(&mut self, calendars: Vec<GtfsCalendar>) {
        for cal in calendars {
            self.calendars.insert(cal.service_id.clone(), cal);
        }
    }

    pub fn load_calendar_dates(&mut self, dates: Vec<GtfsCalendarDate>) {
        self.calendar_dates.extend(dates);
    }

    pub fn load_fleet(&mut self, profiles: HashMap<i64, RollingStockProfile>) {
        self.fleet.extend(profiles);
    }

    pub fn finalize_temporal_graph(&mut self) -> usize {
        use petgraph::algo::astar;
        use petgraph::visit::EdgeRef;

        // Cache paths but include a 'congestion factor' to allow dynamic alternative routing
        let mut path_cache: HashMap<(NodeIndex, NodeIndex), Option<Vec<NodeIndex>>> = HashMap::new();
        let mut edge_usage: HashMap<petgraph::graph::EdgeIndex, u32> = HashMap::new();

        // Then generate the standard temporal edges and EOS for all trips
        for (trip_id, events) in &mut self.stop_times {
            events.sort_by_key(|e| e.stop_sequence);
            for pair in events.windows(2) {
                let from = &pair[0];
                let to = &pair[1];
                
                let from_node = self.temporal.get_or_create_node(from.stop_id);
                let to_node = self.temporal.get_or_create_node(to.stop_id);
                let travel_time = to.arrival_time - from.departure_time;
                self.temporal.graph.add_edge(from_node, to_node, travel_time);

                let from_stop = self.stops.get(&from.stop_id);
                let to_stop = self.stops.get(&to.stop_id);

                if let (Some(fs), Some(ts)) = (from_stop, to_stop) {
                    let from_abbr = get_logical_station_id(fs);
                    let to_abbr = get_logical_station_id(ts);

                    if let (Some(&start_idx), Some(&end_idx)) = (self.physical.station_map.get(from_abbr), self.physical.station_map.get(to_abbr)) {
                        
                        // Phase 12H: Congestion-Aware Routing
                        let path = path_cache.entry((start_idx, end_idx)).or_insert_with(|| {
                            astar(
                                &self.physical.graph, 
                                start_idx, 
                                |finish| finish == end_idx, 
                                |e| {
                                    let base_dist = e.weight().1;
                                    let usage = edge_usage.get(&e.id()).unwrap_or(&0);
                                    base_dist * (1.0 + (f64::from(*usage) * 0.01))
                                }, 
                                |_| 0.0
                            ).map(|(_, p)| p)
                        });
                        
                        if let Some(node_path) = path {
                            let num_segments = node_path.len() - 1;
                            if num_segments > 0 {
                                for window in node_path.windows(2) {
                                    if let Some(edge) = self.physical.graph.find_edge(window[0], window[1]) {
                                        *edge_usage.entry(edge).or_insert(0) += 1;
                                    }
                                }

                                let mut total_dist = 0.0;
                                let mut edge_dists = Vec::with_capacity(num_segments);
                                for window in node_path.windows(2) {
                                    let u = window[0];
                                    let v = window[1];
                                    if let Some(edge) = self.physical.graph.find_edge(u, v) {
                                        if let Some(weight) = self.physical.graph.edge_weight(edge) {
                                            total_dist += weight.1;
                                            edge_dists.push(weight.1);
                                        } else {
                                            edge_dists.push(1.0);
                                        }
                                    } else {
                                        edge_dists.push(1.0);
                                    }
                                }

                                let mut current_time = from.departure_time;
                                
                                let mut segment_times = Vec::with_capacity(num_segments);
                                if total_dist > 0.0 {
                                    let mut accumulated_dist = 0.0;
                                    let mut raw_times = Vec::with_capacity(num_segments);
                                    let mut total_raw_time = 0.0;
                                    
                                    for &dist in &edge_dists {
                                        let mid_x = accumulated_dist + (dist / 2.0);
                                        let normalized_x = mid_x / total_dist;
                                        let mut relative_v = 4.0 * normalized_x * (1.0 - normalized_x);
                                        if relative_v < 0.1 { relative_v = 0.1; }
                                        
                                        let raw_time = dist / relative_v;
                                        raw_times.push(raw_time);
                                        total_raw_time += raw_time;
                                        accumulated_dist += dist;
                                    }
                                    
                                    for raw_time in raw_times {
                                        segment_times.push((f64::from(travel_time) * (raw_time / total_raw_time)).round() as i32);
                                    }
                                } else {
                                    for _ in 0..num_segments {
                                        segment_times.push(travel_time / i32::try_from(num_segments).unwrap_or(1));
                                    }
                                }

                                let profile = self.fleet.get(trip_id);
                                let train_len = profile.map_or(200.0, |p| p.length_meters);
                                let avg_speed_ms = profile.map_or(80.0, |p| (p.max_speed_kmh / 3.6) * 0.7);
                                let tail_clearance_s = (train_len / avg_speed_ms).round() as i32; 

                                let next_trip_idx = u32::try_from(self.trip_id_map.len()).unwrap_or(0);
                                let trip_idx = *self.trip_id_map.entry(*trip_id).or_insert(next_trip_idx);

                                for (i, window) in node_path.windows(2).enumerate() {
                                    let u = window[0];
                                    let v = window[1];
                                    let segment_time = segment_times[i];

                                    let track_idx = if let Some(edge) = self.physical.graph.find_edge(u, v) {
                                        edge.index() as u32
                                    } else {
                                        let min_node = std::cmp::min(u.index(), v.index()) as u32;
                                        let max_node = std::cmp::max(u.index(), v.index()) as u32;
                                        30_000_000 + min_node * 1000 + max_node
                                    };

                                    let eos_end = current_time + segment_time;

                                    self.eos_buffer.push(CompactEOS {
                                        trip_idx,
                                        track_idx,
                                        start_time: current_time as u32,
                                        end_time: (eos_end + tail_clearance_s) as u32,
                                    });

                                    let node_idx = u.index() as u32 + 10_000_000;
                                    self.eos_buffer.push(CompactEOS {
                                        trip_idx,
                                        track_idx: node_idx,
                                        start_time: current_time.saturating_sub(10) as u32,
                                        end_time: (current_time + 10) as u32,
                                    });

                                    current_time = eos_end;
                                }

                                if let Some(&last_node) = node_path.last() {
                                    let node_idx = last_node.index() as u32 + 10_000_000;
                                    self.eos_buffer.push(CompactEOS {
                                        trip_idx,
                                        track_idx: node_idx,
                                        start_time: current_time.saturating_sub(10) as u32,
                                        end_time: (current_time + tail_clearance_s) as u32, 
                                    });
                                }

                                let min_macro = std::cmp::min(start_idx.index(), end_idx.index()) as u32;
                                let max_macro = std::cmp::max(start_idx.index(), end_idx.index()) as u32;
                                let macro_idx = 20_000_000 + min_macro * 1000 + max_macro;
                                
                                self.eos_buffer.push(CompactEOS {
                                    trip_idx,
                                    track_idx: macro_idx,
                                    start_time: from.departure_time as u32,
                                    end_time: (to.arrival_time + tail_clearance_s) as u32,
                                });
                            }
                        }
                    }
                }
            }
        }

        // Phase 15: Night Rostering / Block ID Linking
        // Group trips by block_id
        let mut block_chains: HashMap<String, Vec<&GtfsTrip>> = HashMap::new();
        for trip in self.trips.values() {
            if let Some(block_id) = &trip.block_id {
                block_chains.entry(block_id.clone()).or_default().push(trip);
            }
        }

        for (_, mut chain) in block_chains {
            if chain.len() < 2 { continue; }
            
            // Sort trips in this block by their start time
            chain.sort_by_key(|t| {
                self.stop_times.get(&t.id)
                    .and_then(|st| st.first())
                    .map_or(0, |st| st.departure_time)
            });

            for pair in chain.windows(2) {
                let prev_trip = pair[0];
                let next_trip = pair[1];

                let prev_events = self.stop_times.get(&prev_trip.id);
                let next_events = self.stop_times.get(&next_trip.id);

                if let (Some(pe), Some(ne)) = (prev_events, next_events) {
                    if let (Some(last_event), Some(first_event)) = (pe.last(), ne.first()) {
                        
                        // Check if they end and start at the same station (or we just park it at the last station anyway)
                        // Create a long parking EOS
                        let park_start = last_event.arrival_time;
                        let park_end = first_event.departure_time;

                        if park_end > park_start {
                            if let Some(stop) = self.stops.get(&last_event.stop_id) {
                                let abbr = get_logical_station_id(stop);
                                if let Some(&node_idx) = self.physical.station_map.get(abbr) {
                                    let track_idx = node_idx.index() as u32 + 10_000_000; // Node lock space
                                    
                                    let next_trip_idx = u32::try_from(self.trip_id_map.len()).unwrap_or(0);
                                    let trip_idx = *self.trip_id_map.entry(prev_trip.id).or_insert(next_trip_idx);

                                    self.eos_buffer.push(CompactEOS {
                                        trip_idx,
                                        track_idx,
                                        start_time: park_start as u32,
                                        end_time: park_end as u32,
                                    });
                                }
                            }
                        }
                    }
                }
            }
        }

        self.eos_buffer.par_sort_unstable_by(|a, b| {
            let key_a = (u64::from(a.track_idx) << 32) | u64::from(a.start_time);
            let key_b = (u64::from(b.track_idx) << 32) | u64::from(b.start_time);
            key_a.cmp(&key_b)
        });

        self.temporal.graph.edge_count()
    }

    #[must_use]
    pub fn detect_conflicts(&self) -> ConflictSummary {
        let mut total_conflicts = 0;
        let mut sample_conflicts = Vec::new();
        let headway_seconds = 120; // 2 minutes padding for safety
        
        let mut i = 0;
        while i < self.eos_buffer.len() {
            let track_idx = self.eos_buffer[i].track_idx;
            let mut j = i + 1;
            while j < self.eos_buffer.len() && self.eos_buffer[j].track_idx == track_idx {
                j += 1;
            }
            
            let track_slice = &self.eos_buffer[i..j];
            for (idx, current) in track_slice.iter().enumerate() {
                let current_cleared_time = current.end_time + headway_seconds;
                
                for other in &track_slice[idx + 1..] {
                    if other.start_time >= current_cleared_time {
                        break; 
                    }
                    
                    total_conflicts += 1;
                    
                    if sample_conflicts.len() < 100 {
                        use lasso::Key;
                        // Fast resolve for samples
                        let track_str = if track_idx >= 10_000_000 {
                            format!("SYNTHETIC-{}", track_idx)
                        } else if let Some(spur) = lasso::Spur::try_from_usize(track_idx as usize) {
                            // Rodeo panics if the key is out of bounds, so we also need to ensure it's within len
                            if spur.into_usize() < self.interner.len() {
                                self.interner.resolve(&spur).to_string()
                            } else {
                                "UNKNOWN_INTERNED".to_string()
                            }
                        } else {
                            "UNKNOWN".to_string()
                        };
                        
                        sample_conflicts.push(Conflict {
                            trip_a: i64::from(current.trip_idx),
                            trip_b: i64::from(other.trip_idx),
                            track_id: track_str,
                            start_time: other.start_time as i32,
                            end_time: std::cmp::min(current_cleared_time, other.end_time) as i32,
                        });
                    }
                }
            }
            i = j;
        }
        
        ConflictSummary {
            total_conflicts,
            sample_conflicts,
        }
    }

    #[must_use]
    pub fn get_active_positions(&self, time: i32) -> Vec<ActivePosition> {
        // Parallel map over all trips to find active ones
        self.stop_times
            .par_iter()
            .filter_map(|(&trip_id, events)| {
                if events.is_empty() { return None; }
                let first = events.first()?;
                let last = events.last()?;

                if time < first.departure_time || time > last.arrival_time {
                    return None;
                }

                if let Some((head_lon, head_lat, tail_lon, tail_lat, alt, heading, pitch, roll, velocity)) = self.get_position_3d(trip_id, time) {
                    if head_lon.is_nan() || head_lat.is_nan() || tail_lon.is_nan() || tail_lat.is_nan() {
                        None
                    } else {
                        Some(ActivePosition {
                            trip_id,
                            head_lon,
                            head_lat,
                            tail_lon,
                            tail_lat,
                            alt,
                            heading,
                            pitch,
                            roll,
                            velocity,
                        })
                    }
                } else {
                    None
                }
            })
            .collect()
    }

    #[must_use]
    pub fn get_position_3d(&self, trip_id: i64, time: i32) -> Option<(f64, f64, f64, f64, f64, f64, f64, f64, f64)> {
        let events = self.stop_times.get(&trip_id)?;
        if events.is_empty() { return None; }

        let profile = self.fleet.get(&trip_id);
        let train_len = profile.map_or(200.0, |p| p.length_meters);
        let base_speed = profile.map_or(80.0, |p| p.max_speed_kmh);
        
        // Phase 19: Tilting capability increases curve speed
        // If the train doesn't have the property, default to false (not tilting)
        // Since we don't have is_tilting in the struct yet, we will just use a heuristic based on model name for now
        let is_tilting = profile.map_or(false, |p| p.model.contains("ICN") || p.model.contains("Giruno") || p.model.contains("RABe 501"));
        let speed_multiplier = if is_tilting { 1.2 } else { 1.0 };

        for i in 0..events.len() - 1 {
            let from = &events[i];
            let to = &events[i+1];

            if time >= from.departure_time && time <= to.arrival_time {
                let from_stop = self.stops.get(&from.stop_id)?;
                let to_stop = self.stops.get(&to.stop_id)?;

                let from_abbr = from_stop.abbreviation.as_ref().unwrap_or(&from_stop.original_stop_id);
                let to_abbr = to_stop.abbreviation.as_ref().unwrap_or(&to_stop.original_stop_id);

                let duration = to.arrival_time - from.departure_time;
                if duration <= 0 { return Some((from_stop.location.coordinates.0, from_stop.location.coordinates.1, from_stop.location.coordinates.0, from_stop.location.coordinates.1, 400.0, 0.0, 0.0, 0.0, 0.0)); }

                // 1. Resolve exact physical path geometry & maxspeed
                let (coords, track_maxspeed): (Vec<(f64, f64)>, f64) =
                    if let Some((c, m)) = self.physical.find_path_coordinates(from_abbr, to_abbr) {
                        (c, m)
                    } else if !self.physical.disabled_edges.is_empty()
                        || !self.physical.disabled_stations.is_empty()
                    {
                        return None;
                    } else {
                        // Quick fallback for incomplete topology only when no perturbation is active.
                        (vec![from_stop.location.coordinates, to_stop.location.coordinates], 120.0)
                    };
                
                // Calculate total distance of the segment for Kinematics
                let mut d_total = 0.0;
                if coords.len() > 1 {
                    for w in coords.windows(2) {
                        d_total += haversine_distance(w[0].0, w[0].1, w[1].0, w[1].1);
                    }
                }
                if d_total == 0.0 { d_total = 1.0; }

                // --- 3-PHASE KINEMATICS (NEWTONIAN SOLVER) WITH SPEED CLAMPING ---
                let t_elapsed = f64::from(time - from.departure_time);
                let t_total = f64::from(duration);
                
                // Real absolute physical limit
                let phys_max_kmh = track_maxspeed.min(base_speed) * speed_multiplier;
                let phys_max_ms = phys_max_kmh / 3.6;
                
                // Read DEM elevations for start and end to get average slope
                let get_alt = |lon: f64, lat: f64| -> f64 {
                    self.dem_grid.as_ref().map_or(400.0, |g| g.get_elevation(lon, lat))
                };
                
                let start_alt = get_alt(from_stop.location.coordinates.0, from_stop.location.coordinates.1);
                let end_alt = get_alt(to_stop.location.coordinates.0, to_stop.location.coordinates.1);
                let avg_pitch = if d_total > 0.0 { (end_alt - start_alt).atan2(d_total) } else { 0.0 };
                
                // Effective Acceleration = Base_Accel - Gravity_Component
                let base_accel = 0.8; // m/s^2
                let g = 9.81;
                let mut a_eff = base_accel - g * avg_pitch.sin();
                a_eff = a_eff.clamp(0.2, 1.5); // Bound safety
                
                let t_norm = t_elapsed / t_total;
                // Standard smoothstep
                let mut progress = t_norm * t_norm * (3.0 - 2.0 * t_norm);
                
                // Apply kinematic skew
                if a_eff < base_accel {
                    progress = progress.powf(1.1);
                } else if a_eff > base_accel {
                    progress = progress.powf(0.9);
                }

                // Calculate required distance based on theoretical schedule
                let required_distance = progress * d_total;
                
                // Calculate physical maximum distance the train COULD have traveled
                let max_possible_distance = t_elapsed * phys_max_ms;
                
                // Apply the Clamp! If the schedule requires the train to break the laws of physics,
                // it is physically delayed.
                let actual_distance = required_distance.min(max_possible_distance);
                
                // Recalculate true progress and velocity
                progress = actual_distance / d_total;
                
                // Instantaneous velocity (derivative of required progress * d_total)
                let mut inst_velocity_ms = (6.0 * t_norm * (1.0 - t_norm) / t_total) * d_total;
                
                // If it's hitting the clamp, it's driving at V_max
                if required_distance > max_possible_distance {
                    inst_velocity_ms = phys_max_ms;
                }
                
                let final_velocity = inst_velocity_ms * 3.6; // to km/h

                // 2. Interpolate 3D position (Head)
                let p1 = Self::interpolate_on_curve(&coords, progress);
                let final_alt = get_alt(p1.0, p1.1);

                // 3. Orientation via Tangent calculation
                let step = 0.001; 
                let p2 = Self::interpolate_on_curve(&coords, (progress + step).min(1.0));
                let next_alt = get_alt(p2.0, p2.1);

                // Heading (Yaw)
                let heading = (p2.0 - p1.0).atan2(p2.1 - p1.1).to_degrees();
                
                // Pitch (Grade)
                let dist = haversine_distance(p1.0, p1.1, p2.0, p2.1);
                let pitch = if dist > 0.0 { (next_alt - final_alt).atan2(dist).to_degrees() } else { 0.0 };
                
                // Roll (Cant / Centrifugal approximation)
                let p3 = Self::interpolate_on_curve(&coords, (progress + step * 2.0).min(1.0));
                let h2 = (p3.0 - p2.0).atan2(p3.1 - p2.1).to_degrees();
                let delta_h = (h2 - heading).to_radians();
                let roll = if dist > 0.0 {
                    let radius = dist / delta_h.abs().max(0.00001);
                    let v = inst_velocity_ms;
                    (v * v / (g * radius)).atan().to_degrees() * delta_h.signum()
                } else { 0.0 };

                // 4. Calculate Tail Position (Serpent rendering)
                let total_path_len = d_total;
                let tail_offset_progress = if total_path_len > 0.0 { train_len / total_path_len } else { 0.0 };
                let tail_progress = (progress - tail_offset_progress).max(0.0);
                
                let p_tail = Self::interpolate_on_curve(&coords, tail_progress);

                return Some((p1.0, p1.1, p_tail.0, p_tail.1, final_alt, heading, pitch, roll, final_velocity));
            }
        }

        // Standing at station
        for event in events {
            if time >= event.arrival_time && time <= event.departure_time {
                let stop = self.stops.get(&event.stop_id)?;
                let (lon, lat) = stop.location.coordinates;
                // At station, head and tail are roughly the same point for now (or could be offset by train_len)
                let tail_lat = lat - (train_len / 111320.0);
                return Some((lon, lat, lon, tail_lat, 400.0, 0.0, 0.0, 0.0, 0.0));
            }
        }
        None
    }

    #[must_use]
    pub fn get_position(&self, trip_id: i64, time: i32) -> Option<(f64, f64)> {
        self.get_position_3d(trip_id, time).map(|(lon, lat, _, _, _, _, _, _, _)| (lon, lat))
    }

    fn interpolate_on_curve(coords: &[(f64, f64)], progress: f64) -> (f64, f64) {
        if coords.is_empty() { return (0.0, 0.0); }
        if coords.len() == 1 { return coords[0]; }
        if progress >= 1.0 { return coords[coords.len() - 1]; }
        if progress <= 0.0 { return coords[0]; }

        let target_idx_float = progress * (coords.len() - 1) as f64;
        let mut idx = target_idx_float.floor() as usize;
        
        // Prevent floating-point precision loss from causing out-of-bounds
        if idx >= coords.len() - 1 {
            idx = coords.len() - 2;
        }
        
        let local_progress = target_idx_float - idx as f64;

        let p1 = coords[idx];
        let p2 = coords[idx + 1];
        (p1.0 + (p2.0 - p1.0) * local_progress, p1.1 + (p2.1 - p1.1) * local_progress)
    }

    pub fn freeze_state(&self, path: &str) -> Result<(), String> {
        let file = File::create(path).map_err(|e| e.to_string())?;
        let writer = BufWriter::new(file);
        let state = (&self.stop_times, &self.eos_buffer);
        bincode::serialize_into(writer, &state).map_err(|e| e.to_string())?;
        Ok(())
    }

    pub fn thaw_state(&mut self, path: &str) -> Result<(), String> {
        let file = File::open(path).map_err(|e| e.to_string())?;
        let reader = BufReader::new(file);
        let (trips, eos_buffer): (HashMap<i64, Vec<GtfsStopTime>>, Vec<CompactEOS>) = bincode::deserialize_from(reader).map_err(|e| e.to_string())?;
        self.stop_times = trips;
        self.eos_buffer = eos_buffer;
        Ok(())
    }
    pub fn inject_delay(&mut self, trip_id: i64, delay_seconds: i32) -> Result<(), String> {
        if let Some(events) = self.stop_times.get_mut(&trip_id) {
            for event in events.iter_mut() {
                event.arrival_time += delay_seconds;
                event.departure_time += delay_seconds;
            }
            Ok(())
        } else {
            Err(format!("Trip {} not found", trip_id))
        }
    }

    pub fn resolve_conflict_greedy(&mut self) -> ResolutionMetrics {
        use std::collections::HashSet;
        let start_time_ms = std::time::Instant::now();
        let mut total_delay_added = 0;
        let mut trains_impacted = HashSet::new();
        let mut iterations = 0;

        let mut idx_to_trip = HashMap::new();
        for (&trip_id, &trip_idx) in &self.trip_id_map {
            idx_to_trip.insert(trip_idx, trip_id);
        }

        loop {
            iterations += 1;
            if iterations > 20 { break; } // Safety escape valve
            
            // Rebuild STIG based on current self.stop_times
            self.finalize_temporal_graph();

            let mut track_occupancy: HashMap<u32, u32> = HashMap::new();
            let mut conflicts_found = false;

            // self.eos_buffer is already sorted by start_time
            for eos in &self.eos_buffer {
                if let Some(&last_end) = track_occupancy.get(&eos.track_idx) {
                    if eos.start_time < last_end {
                        // CONFLICT!
                        let delay = last_end - eos.start_time;
                        total_delay_added += delay;
                        if let Some(&trip_id) = idx_to_trip.get(&eos.trip_idx) {
                            trains_impacted.insert(trip_id);
                            
                            // Push this trip's future schedule forward
                            if let Some(events) = self.stop_times.get_mut(&trip_id) {
                                for event in events.iter_mut() {
                                    if event.arrival_time >= eos.start_time as i32 {
                                        event.arrival_time += delay as i32;
                                        event.departure_time += delay as i32;
                                    }
                                }
                            }
                        }
                        
                        conflicts_found = true;
                        break; // Restart the sweep-line with the new timeline
                    }
                }
                track_occupancy.insert(eos.track_idx, eos.end_time);
            }
            
            if !conflicts_found {
                break;
            }
        }

        ResolutionMetrics {
            status: "success".to_string(),
            trains_impacted: trains_impacted.len(),
            total_delay_added,
            computation_time_ms: start_time_ms.elapsed().as_millis() as u32,
        }
    }

    pub fn resolve_conflict_local_search(&mut self) -> ResolutionMetrics {
        let start_time_ms = std::time::Instant::now();
        
        // 1. Rebuild STIG based on current self.stop_times to get baseline
        self.finalize_temporal_graph();

        // 2. Identify Blast Zone
        let mut idx_to_trip = HashMap::new();
        for (&trip_id, &trip_idx) in &self.trip_id_map {
            idx_to_trip.insert(trip_idx, trip_id);
        }

        let mut track_occupancy: HashMap<u32, u32> = HashMap::new();
        let mut impacted_trips_set = std::collections::HashSet::new();

        for eos in &self.eos_buffer {
            if let Some(&last_end) = track_occupancy.get(&eos.track_idx) {
                if eos.start_time < last_end {
                    if let Some(&trip_id) = idx_to_trip.get(&eos.trip_idx) {
                        impacted_trips_set.insert(trip_id);
                    }
                }
            }
            track_occupancy.insert(eos.track_idx, eos.end_time);
        }
        
        let trips_in_zone: Vec<i64> = impacted_trips_set.into_iter().collect();
        
        if trips_in_zone.is_empty() {
            return ResolutionMetrics {
                status: "success".to_string(),
                trains_impacted: 0,
                total_delay_added: 0,
                computation_time_ms: start_time_ms.elapsed().as_millis() as u32,
            };
        }

        // 3. Custom High-Performance Hill Climbing (Local Search)
        // Bypassing external localsearch crate for maximum zero-copy resilience and zero dependency conflicts.
        use rand::RngExt;
        let mut rng = rand::rng();
        
        let mut best_delays: HashMap<i64, i32> = trips_in_zone.iter().map(|&id| (id, 0)).collect();
        let mut best_score;
        
        // Inline evaluation function
        let evaluate = |delays: &HashMap<i64, i32>| -> i64 {
            let mut temp_eos = Vec::with_capacity(self.eos_buffer.len());
            let mut total_delay_penalty = 0;

            for eos in &self.eos_buffer {
                if let Some(&trip_id) = idx_to_trip.get(&eos.trip_idx) {
                    if trips_in_zone.contains(&trip_id) {
                        let delay = delays.get(&trip_id).copied().unwrap_or(0);
                        let mut new_eos = eos.clone();
                        new_eos.start_time += delay as u32;
                        new_eos.end_time += delay as u32;
                        temp_eos.push(new_eos);
                    } else {
                        temp_eos.push(eos.clone());
                    }
                }
            }
            
            for trip_id in &trips_in_zone {
                total_delay_penalty += delays.get(trip_id).copied().unwrap_or(0) as i64;
            }

            temp_eos.sort_by(|a, b| a.start_time.cmp(&b.start_time));

            let mut overlaps = 0;
            let mut occupancy: HashMap<u32, u32> = HashMap::new();
            for eos in &temp_eos {
                if let Some(&last_end) = occupancy.get(&eos.track_idx) {
                    if eos.start_time < last_end {
                        overlaps += 1;
                    }
                }
                occupancy.insert(eos.track_idx, eos.end_time);
            }

            (overlaps * 1_000_000) as i64 + total_delay_penalty
        };
        
        best_score = evaluate(&best_delays);
        let mut current_delays = best_delays.clone();

        for _ in 0..100 {
            if best_score == 0 { break; } // Optimal found
            
            let mut trial = current_delays.clone();
            let trip_idx = rng.random_range(0..trips_in_zone.len());
            let trip_id = trips_in_zone[trip_idx];
            let added_delay = rng.random_range(10..=60);
            
            let current_delay = trial.get(&trip_id).copied().unwrap_or(0);
            trial.insert(trip_id, current_delay + added_delay);
            
            let trial_score = evaluate(&trial);
            
            if trial_score < best_score {
                best_delays = trial.clone();
                best_score = trial_score;
                current_delays = trial;
            } else if rng.random_bool(0.1) {
                current_delays = trial; // Escape local optima
            }
        }

        // Apply best solution to real manager
        let mut total_delay_added = 0;
        for trip_id in trips_in_zone.clone() {
            if let Some(&delay) = best_delays.get(&trip_id) {
                if delay > 0 {
                    total_delay_added += delay as u32;
                    if let Some(events) = self.stop_times.get_mut(&trip_id) {
                        for event in events.iter_mut() {
                            event.arrival_time += delay;
                            event.departure_time += delay;
                        }
                    }
                }
            }
        }
        
        // Final re-sync
        self.finalize_temporal_graph();

        ResolutionMetrics {
            status: "success".to_string(),
            trains_impacted: trips_in_zone.len(),
            total_delay_added,
            computation_time_ms: start_time_ms.elapsed().as_millis() as u32,
        }
    }
}

impl Default for NetworkManager {
    fn default() -> Self {
        Self::new()
    }
}

impl Default for PhysicalNetwork {
    fn default() -> Self {
        Self::new()
    }
}

impl Default for TemporalNetwork {
    fn default() -> Self {
        Self::new()
    }
}
