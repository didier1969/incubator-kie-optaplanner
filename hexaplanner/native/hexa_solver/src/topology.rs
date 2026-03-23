#![allow(clippy::cast_possible_truncation)]
#![allow(clippy::cast_sign_loss)]
#![allow(clippy::cast_precision_loss)]
#![allow(clippy::cast_possible_wrap)]
#![allow(clippy::uninlined_format_args)]
#![allow(clippy::needless_pass_by_value)]
#![allow(clippy::too_many_lines)]

use petgraph::graph::{NodeIndex, UnGraph, DiGraph};
use std::collections::HashMap;
use crate::domain::{GtfsStop, GtfsStopTime, TrackSegment, GtfsTransfer, GtfsCalendar, GtfsCalendarDate, Conflict, ConflictSummary, CompactEOS, OsmNode, OsmWay};
use lasso::Rodeo;
use rayon::prelude::*;
use kdtree::KdTree;
use kdtree::distance::squared_euclidean;
use std::fs::File;
use std::io::{BufReader, BufWriter};

/// Represents the physical layer: rails and stations.
pub struct PhysicalNetwork {
    pub graph: UnGraph<String, (Vec<(f64, f64)>, f64)>, // Node: Station ID, Edge: (Curve Coordinates, Length in meters)
    pub station_map: HashMap<String, NodeIndex>,
    pub all_tracks: Vec<TrackSegment>,
    pub spatial_index: KdTree<f64, usize, [f64; 2]>, // Maps [lon, lat] -> Index in all_tracks
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
    pub fn add_track(&mut self, a: NodeIndex, b: NodeIndex, coords: Vec<(f64, f64)>) {
        let mut length = 0.0;
        if coords.len() > 1 {
            for window in coords.windows(2) {
                length += haversine_distance(window[0].0, window[0].1, window[1].0, window[1].1);
            }
        }
        if length == 0.0 { length = 1.0; } // Prevent div by zero
        self.graph.add_edge(a, b, (coords, length));
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
    pub fn find_path_coordinates(&self, from_id: &str, to_id: &str) -> Option<Vec<(f64, f64)>> {
        let start = *self.station_map.get(from_id)?;
        let end = *self.station_map.get(to_id)?;
        let edge = self.graph.find_edge(start, end)?;
        Some(self.graph.edge_weight(edge)?.0.clone())
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
    pub trips: HashMap<i64, Vec<GtfsStopTime>>,
    pub stops: HashMap<i64, GtfsStop>,
    pub transfers: Vec<GtfsTransfer>,
    pub calendars: HashMap<String, GtfsCalendar>,
    pub calendar_dates: Vec<GtfsCalendarDate>,
    pub fleet: HashMap<i64, crate::domain::RollingStockProfile>,
    
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
            trips: HashMap::new(),
            stops: HashMap::new(),
            transfers: Vec::new(),
            calendars: HashMap::new(),
            calendar_dates: Vec::new(),
            fleet: HashMap::new(),
            interner: Rodeo::default(),
            trip_id_map: HashMap::new(),
            eos_buffer: Vec::with_capacity(1_000_000),
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
                self.physical.graph.add_edge(macro_idx, micro_idx, (vec![], 0.1));
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

        // Then build edges from ways
        for way in ways {
            if way.nodes.len() < 2 { continue; }
            for window in way.nodes.windows(2) {
                let u_id = window[0];
                let v_id = window[1];
                
                if let (Some(u_idx), Some(v_idx)) = (self.micro.node_map.get(&u_id), self.micro.node_map.get(&v_id)) {
                    if let (Some(u_coords), Some(v_coords)) = (self.micro.node_coords.get(&u_id), self.micro.node_coords.get(&v_id)) {
                        let distance = haversine_distance(u_coords.0, u_coords.1, v_coords.0, v_coords.1);
                        self.micro.graph.add_edge(*u_idx, *v_idx, distance);
                        
                        // Phase 12I: Inject edges into Unified Physical Network
                        let p_u_id = format!("OSM-{}", u_id);
                        let p_v_id = format!("OSM-{}", v_id);
                        let a = self.physical.add_station(&p_u_id);
                        let b = self.physical.add_station(&p_v_id);
                        
                        let safe_dist = if distance <= 0.0 { 1.0 } else { distance };
                        self.physical.graph.add_edge(a, b, (vec![*u_coords, *v_coords], safe_dist));
                        
                        // Add to spatial index for snapping
                        let track_idx = self.physical.all_tracks.len();
                        let _ = self.physical.spatial_index.add([u_coords.0, u_coords.1], track_idx);
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

    pub fn load_tracks(&mut self, tracks: Vec<TrackSegment>) {
        for track in tracks {
            let start_id = track.properties.get("bp_anfang").cloned().unwrap_or_default();
            let end_id = track.properties.get("bp_ende").cloned().unwrap_or_default();
            
            if !start_id.is_empty() && !end_id.is_empty() {
                let a = self.physical.add_station(&start_id);
                let b = self.physical.add_station(&end_id);
                self.physical.add_track(a, b, track.coordinates.clone());
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
            self.trips.entry(st.trip_id).or_default().push(st);
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

    pub fn load_fleet(&mut self, profiles: HashMap<i64, crate::domain::RollingStockProfile>) {
        self.fleet.extend(profiles);
    }

    pub fn finalize_temporal_graph(&mut self) -> usize {
        use petgraph::algo::astar;
        use petgraph::visit::EdgeRef;

        // Cache paths but include a 'congestion factor' to allow dynamic alternative routing
        let mut path_cache: HashMap<(NodeIndex, NodeIndex), Option<Vec<NodeIndex>>> = HashMap::new();
        let mut edge_usage: HashMap<petgraph::graph::EdgeIndex, u32> = HashMap::new();

        for events in self.trips.values_mut() {
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
                        // We use a dynamic A* that considers the physical distance and current edge usage.
                        let path = path_cache.entry((start_idx, end_idx)).or_insert_with(|| {
                            astar(
                                &self.physical.graph, 
                                start_idx, 
                                |finish| finish == end_idx, 
                                |e| {
                                    let base_dist = e.weight().1;
                                    let usage = edge_usage.get(&e.id()).unwrap_or(&0);
                                    // Increase cost by 1% for every train already routed this way
                                    base_dist * (1.0 + (f64::from(*usage) * 0.01))
                                }, 
                                |_| 0.0
                            ).map(|(_, p)| p)
                        });
                        
                        if let Some(node_path) = path {
                            let num_segments = node_path.len() - 1;
                            if num_segments > 0 {
                                // Track usage for future routing to prevent parallel track starvation
                                for window in node_path.windows(2) {
                                    if let Some(edge) = self.physical.graph.find_edge(window[0], window[1]) {
                                        *edge_usage.entry(edge).or_insert(0) += 1;
                                    }
                                }

                                // Calculate total path distance
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
                                
                                // Phase 12H: Kinematic Velocity Curves (v=at)
                                // We simulate a simple velocity profile: lower speed at ends (acceleration/deceleration)
                                // Time spent on a segment is proportional to (distance / average_velocity).
                                // We approximate the velocity curve as an inverted parabola: v(x) = 4 * v_max * (x/D) * (1 - x/D)
                                // To avoid div by zero, v_min = 0.1 * v_max.
                                let mut segment_times = Vec::with_capacity(num_segments);
                                if total_dist > 0.0 {
                                    let mut accumulated_dist = 0.0;
                                    let mut raw_times = Vec::with_capacity(num_segments);
                                    let mut total_raw_time = 0.0;
                                    
                                    for &dist in &edge_dists {
                                        let mid_x = accumulated_dist + (dist / 2.0);
                                        let normalized_x = mid_x / total_dist;
                                        // Simple kinematic velocity envelope (parabola)
                                        let mut relative_v = 4.0 * normalized_x * (1.0 - normalized_x);
                                        if relative_v < 0.1 { relative_v = 0.1; } // Minimum speed
                                        
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

                                // Phase 15: Exact Physical Composition (Rolling Stock)
                                let profile = self.fleet.get(&from.trip_id);
                                let train_len = profile.map_or(200.0, |p| p.length_meters);
                                let avg_speed_ms = profile.map_or(80.0, |p| (p.max_speed_kmh / 3.6) * 0.7);
                                let tail_clearance_s = (train_len / avg_speed_ms).round() as i32; 

                                let next_trip_idx = u32::try_from(self.trip_id_map.len()).unwrap_or(0);
                                let trip_idx = *self.trip_id_map.entry(from.trip_id).or_insert(next_trip_idx);

                                for (i, window) in node_path.windows(2).enumerate() {
                                    let u = window[0];
                                    let v = window[1];
                                    let segment_time = segment_times[i];

                                    // Get edge index directly, fallback to a combined hash if not found
                                    let track_idx = if let Some(edge) = self.physical.graph.find_edge(u, v) {
                                        edge.index() as u32
                                    } else {
                                        let min_node = std::cmp::min(u.index(), v.index()) as u32;
                                        let max_node = std::cmp::max(u.index(), v.index()) as u32;
                                        // Offset by 30M to avoid collision with real edges
                                        30_000_000 + min_node * 1000 + max_node
                                    };

                                    let eos_end = current_time + segment_time;

                                    self.eos_buffer.push(CompactEOS {
                                        trip_idx,
                                        track_idx,
                                        start_time: current_time as u32,
                                        end_time: (eos_end + tail_clearance_s) as u32,
                                    });

                                    // Lock the entry node (route locking)
                                    let node_idx = u.index() as u32 + 10_000_000;
                                    self.eos_buffer.push(CompactEOS {
                                        trip_idx,
                                        track_idx: node_idx,
                                        start_time: current_time.saturating_sub(10) as u32,
                                        end_time: (current_time + 10) as u32,
                                    });

                                    current_time = eos_end;
                                }

                                // Lock the final node in the path
                                if let Some(&last_node) = node_path.last() {
                                    let node_idx = last_node.index() as u32 + 10_000_000;
                                    self.eos_buffer.push(CompactEOS {
                                        trip_idx,
                                        track_idx: node_idx,
                                        start_time: current_time.saturating_sub(10) as u32,
                                        end_time: (current_time + tail_clearance_s) as u32, 
                                    });
                                }

                                // Prevent opposing trains from entering the single-track section
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
                        let track_str = if let Some(spur) = lasso::Spur::try_from_usize(track_idx as usize) {
                            self.interner.resolve(&spur).to_string()
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
    pub fn get_active_positions(&self, time: i32) -> Vec<(i64, f64, f64)> {
        use rayon::prelude::*;
        
        // Parallel map over all trips to find active ones
        self.trips
            .par_iter()
            .filter_map(|(&trip_id, events)| {
                if events.is_empty() { return None; }
                let first = events.first()?;
                let last = events.last()?;

                if time < first.departure_time || time > last.arrival_time {
                    return None;
                }

                if let Some((lon, lat)) = self.get_position(trip_id, time) {
                    // Prevent Rustler ArgumentError by stripping out any NaN or Infinity that might have leaked from Bad Data
                    if lon.is_nan() || lat.is_nan() || lon.is_infinite() || lat.is_infinite() {
                        None
                    } else {
                        Some((trip_id, lon, lat))
                    }
                } else {
                    None
                }
            })
            .collect()
    }

    #[must_use]
    pub fn get_position(&self, trip_id: i64, time: i32) -> Option<(f64, f64)> {
        let events = self.trips.get(&trip_id)?;
        if events.is_empty() { return None; }

        for i in 0..events.len() - 1 {
            let from = &events[i];
            let to = &events[i+1];

            if time >= from.departure_time && time <= to.arrival_time {
                let from_stop = self.stops.get(&from.stop_id)?;
                let to_stop = self.stops.get(&to.stop_id)?;

                let from_abbr = from_stop.abbreviation.as_ref().unwrap_or(&from_stop.original_stop_id);
                let to_abbr = to_stop.abbreviation.as_ref().unwrap_or(&to_stop.original_stop_id);

                if let Some(coords) = self.physical.find_path_coordinates(from_abbr, to_abbr) {
                    let progress = f64::from(time - from.departure_time) / f64::from(to.arrival_time - from.departure_time);
                    return Some(Self::interpolate_on_curve(&coords, progress));
                }

                // Fallback to KD-Tree Snapping to guarantee rail-following
                let duration = to.arrival_time - from.departure_time;
                if duration <= 0 { return Some(from_stop.location.coordinates); }
                let progress = f64::from(time - from.departure_time) / f64::from(duration);
                
                let lon = from_stop.location.coordinates.0 + (to_stop.location.coordinates.0 - from_stop.location.coordinates.0) * progress;
                let lat = from_stop.location.coordinates.1 + (to_stop.location.coordinates.1 - from_stop.location.coordinates.1) * progress;
                
                if let Ok(nearest) = self.physical.spatial_index.nearest(&[lon, lat], 1, &squared_euclidean) {
                    if let Some(&(_, &track_idx)) = nearest.first() {
                        if let Some(track) = self.physical.all_tracks.get(track_idx) {
                            return Some(Self::interpolate_on_curve(&track.coordinates, progress));
                        }
                    }
                }
                
                return Some((lon, lat));
            }
        }

        for event in events {
            if time >= event.arrival_time && time <= event.departure_time {
                let stop = self.stops.get(&event.stop_id)?;
                return Some(stop.location.coordinates);
            }
        }
        None
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
        let state = (&self.trips, &self.eos_buffer);
        bincode::serialize_into(writer, &state).map_err(|e| e.to_string())?;
        Ok(())
    }

    pub fn thaw_state(&mut self, path: &str) -> Result<(), String> {
        let file = File::open(path).map_err(|e| e.to_string())?;
        let reader = BufReader::new(file);
        let (trips, eos_buffer): (HashMap<i64, Vec<GtfsStopTime>>, Vec<CompactEOS>) = bincode::deserialize_from(reader).map_err(|e| e.to_string())?;
        self.trips = trips;
        self.eos_buffer = eos_buffer;
        Ok(())
    }
    pub fn inject_delay(&mut self, trip_id: i64, delay_seconds: i32) -> Result<(), String> {
        if let Some(events) = self.trips.get_mut(&trip_id) {
            for event in events.iter_mut() {
                event.arrival_time += delay_seconds;
                event.departure_time += delay_seconds;
            }
            Ok(())
        } else {
            Err(format!("Trip {} not found", trip_id))
        }
    }

    pub fn resolve_conflict_greedy(&mut self) -> crate::domain::ResolutionMetrics {
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
            
            // Rebuild STIG based on current self.trips
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
                            if let Some(events) = self.trips.get_mut(&trip_id) {
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

        crate::domain::ResolutionMetrics {
            status: "success".to_string(),
            trains_impacted: trains_impacted.len(),
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

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_network_graph_creation() {
        let mut network = PhysicalNetwork::new();
        let bern = network.add_station("BN");
        let zurich = network.add_station("ZUE");
        network.add_track(bern, zurich, vec![(7.4, 46.9), (8.5, 47.3)]); 
        assert_eq!(network.station_count(), 2);
    }
}
