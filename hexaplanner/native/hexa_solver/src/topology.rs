use petgraph::graph::{NodeIndex, UnGraph, DiGraph};
use std::collections::HashMap;
use crate::domain::{GtfsStop, GtfsStopTime, TrackSegment, GtfsTransfer, GtfsCalendar, GtfsCalendarDate, Conflict, ConflictSummary, CompactEOS};
use lasso::Rodeo;
use rayon::prelude::*;
use kdtree::KdTree;
use kdtree::distance::squared_euclidean;

/// Represents the physical layer: rails and stations.
pub struct PhysicalNetwork {
    pub graph: UnGraph<String, (Vec<(f64, f64)>, f64)>, // Node: Station ID, Edge: (Curve Coordinates, Length in meters)
    pub station_map: HashMap<String, NodeIndex>,
    pub all_tracks: Vec<TrackSegment>,
    pub spatial_index: KdTree<f64, usize, [f64; 2]>, // Maps [lon, lat] -> Index in all_tracks
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
    pub temporal: TemporalNetwork,
    pub trips: HashMap<i64, Vec<GtfsStopTime>>,
    pub stops: HashMap<i64, GtfsStop>,
    pub transfers: Vec<GtfsTransfer>,
    pub calendars: HashMap<String, GtfsCalendar>,
    pub calendar_dates: Vec<GtfsCalendarDate>,
    
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
            temporal: TemporalNetwork::new(),
            trips: HashMap::new(),
            stops: HashMap::new(),
            transfers: Vec::new(),
            calendars: HashMap::new(),
            calendar_dates: Vec::new(),
            interner: Rodeo::default(),
            trip_id_map: HashMap::new(),
            eos_buffer: Vec::with_capacity(1_000_000),
        }
    }

    pub fn load_stops(&mut self, stops: Vec<GtfsStop>) {
        for stop in stops {
            let physical_id = stop.abbreviation.clone().unwrap_or_else(|| stop.original_stop_id.clone());
            self.physical.add_station(&physical_id);
            self.temporal.get_or_create_node(stop.id);
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

    pub fn finalize_temporal_graph(&mut self) -> usize {
        use petgraph::algo::astar;
        use lasso::Key;
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
                    let from_abbr = fs.abbreviation.as_ref().unwrap_or(&fs.original_stop_id);
                    let to_abbr = ts.abbreviation.as_ref().unwrap_or(&ts.original_stop_id);

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
                                        segment_times.push(travel_time / num_segments as i32);
                                    }
                                }

                                // We don't have rolling stock yet, assume 120s base headway + gradient penalty in future
                                let tail_clearance_s = 20; 
                                let next_trip_idx = self.trip_id_map.len() as u32;
                                let trip_idx = *self.trip_id_map.entry(from.trip_id).or_insert(next_trip_idx);

                                for (i, window) in node_path.windows(2).enumerate() {
                                    let u_id = &self.physical.graph[window[0]];
                                    let v_id = &self.physical.graph[window[1]];
                                    let track_str = if u_id < v_id { format!("{}-{}", u_id, v_id) } else { format!("{}-{}", v_id, u_id) };
                                    
                                    let segment_time = segment_times[i];

                                    let key = self.interner.get_or_intern(&track_str);
                                    let track_idx = key.into_usize() as u32;

                                    let eos_end = current_time + segment_time;

                                    self.eos_buffer.push(CompactEOS {
                                        trip_idx,
                                        track_idx,
                                        start_time: current_time as u32,
                                        end_time: (eos_end + tail_clearance_s) as u32,
                                    });

                                    // Lock the entry node (route locking)
                                    let node_idx = self.interner.get_or_intern(u_id).into_usize() as u32;
                                    self.eos_buffer.push(CompactEOS {
                                        trip_idx,
                                        track_idx: node_idx,
                                        start_time: current_time.saturating_sub(10) as u32, // 10s pre-locking
                                        end_time: (current_time + 10) as u32, // clear switch
                                    });

                                    current_time = eos_end;
                                }

                                // Lock the final node in the path
                                if let Some(&last_node) = node_path.last() {
                                    let last_id = &self.physical.graph[last_node];
                                    let node_idx = self.interner.get_or_intern(last_id).into_usize() as u32;
                                    self.eos_buffer.push(CompactEOS {
                                        trip_idx,
                                        track_idx: node_idx,
                                        start_time: current_time.saturating_sub(10) as u32,
                                        end_time: (current_time + tail_clearance_s) as u32, 
                                    });
                                }

                                // Prevent opposing trains from entering the single-track section
                                let macro_track_str = if from_abbr < to_abbr {
                                    format!("MACRO-{}-{}", from_abbr, to_abbr)
                                } else {
                                    format!("MACRO-{}-{}", to_abbr, from_abbr)
                                };
                                let macro_idx = self.interner.get_or_intern(&macro_track_str).into_usize() as u32;
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
                    return Some(self.interpolate_on_curve(&coords, progress));
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
                            return Some(self.interpolate_on_curve(&track.coordinates, progress));
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

    fn interpolate_on_curve(&self, coords: &[(f64, f64)], progress: f64) -> (f64, f64) {
        if coords.is_empty() { return (0.0, 0.0); }
        if coords.len() == 1 { return coords[0]; }
        let target_idx_float = progress * (coords.len() - 1) as f64;
        let idx = target_idx_float.floor() as usize;
        let local_progress = target_idx_float - idx as f64;
        if idx >= coords.len() - 1 { return coords[coords.len() - 1]; }
        let p1 = coords[idx];
        let p2 = coords[idx + 1];
        (p1.0 + (p2.0 - p1.0) * local_progress, p1.1 + (p2.1 - p1.1) * local_progress)
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
