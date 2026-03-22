use petgraph::graph::{NodeIndex, UnGraph, DiGraph};
use std::collections::HashMap;
use crate::domain::{GtfsStop, GtfsStopTime, TrackSegment, GtfsTransfer, GtfsCalendar, GtfsCalendarDate};

/// Represents the physical layer: rails and stations.
pub struct PhysicalNetwork {
    pub graph: UnGraph<String, Vec<(f64, f64)>>, // Node: Station ID, Edge: Curve Coordinates
    pub station_map: HashMap<String, NodeIndex>,
    pub all_tracks: Vec<TrackSegment>,
}

/// Represents the temporal layer: schedule and service occurrences.
pub struct TemporalNetwork {
    pub graph: DiGraph<i64, i32>, // Node: Stop ID, Edge: Travel Time (seconds)
    pub stop_map: HashMap<i64, NodeIndex>,
}

pub struct NetworkManager {
    pub physical: PhysicalNetwork,
    pub temporal: TemporalNetwork,
    pub trips: HashMap<i64, Vec<GtfsStopTime>>,
    pub stops: HashMap<i64, GtfsStop>,
    pub transfers: Vec<GtfsTransfer>,
    pub calendars: HashMap<String, GtfsCalendar>,
    pub calendar_dates: Vec<GtfsCalendarDate>,
}

impl PhysicalNetwork {
    #[must_use]
    pub fn new() -> Self {
        Self {
            graph: UnGraph::new_undirected(),
            station_map: HashMap::new(),
            all_tracks: Vec::new(),
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
        self.graph.add_edge(a, b, coords);
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

        // Simple direct edge lookup for now
        let edge = self.graph.find_edge(start, end)?;
        Some(self.graph.edge_weight(edge)?.clone())
    }
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
        }
    }

    pub fn load_stops(&mut self, stops: Vec<GtfsStop>) {
        for stop in stops {
            // High-fidelity: use official abbreviation if present for physical linkage
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
        for events in self.trips.values_mut() {
            events.sort_by_key(|e| e.stop_sequence);
            for pair in events.windows(2) {
                let from = &pair[0];
                let to = &pair[1];
                
                let from_node = self.temporal.get_or_create_node(from.stop_id);
                let to_node = self.temporal.get_or_create_node(to.stop_id);
                
                let travel_time = to.arrival_time - from.departure_time;
                self.temporal.graph.add_edge(from_node, to_node, travel_time);
            }
        }

        // Add Transfer Edges
        for transfer in &self.transfers {
            let from_node = self.temporal.get_or_create_node(transfer.from_stop_id);
            let to_node = self.temporal.get_or_create_node(transfer.to_stop_id);
            let time = transfer.min_transfer_time.unwrap_or(120); // Default 2 mins
            self.temporal.graph.add_edge(from_node, to_node, time);
        }

        self.temporal.graph.edge_count()
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

                // HIGH-FIDELITY POSITIONING:
                // Use abbreviations to look up the physical curve
                let from_abbr = from_stop.abbreviation.as_ref().unwrap_or(&from_stop.original_stop_id);
                let to_abbr = to_stop.abbreviation.as_ref().unwrap_or(&to_stop.original_stop_id);

                if let Some(coords) = self.physical.find_path_coordinates(from_abbr, to_abbr) {
                    let progress = f64::from(time - from.departure_time) / f64::from(to.arrival_time - from.departure_time);
                    return Some(self.interpolate_on_curve(&coords, progress));
                }

                // Fallback to linear
                let duration = to.arrival_time - from.departure_time;
                if duration <= 0 { return Some(from_stop.location.coordinates); }
                let progress = f64::from(time - from.departure_time) / f64::from(duration);
                let lon = from_stop.location.coordinates.0 + (to_stop.location.coordinates.0 - from_stop.location.coordinates.0) * progress;
                let lat = from_stop.location.coordinates.1 + (to_stop.location.coordinates.1 - from_stop.location.coordinates.1) * progress;
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
        
        let lon = p1.0 + (p2.0 - p1.0) * local_progress;
        let lat = p1.1 + (p2.1 - p1.1) * local_progress;
        (lon, lat)
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
        let bern = network.add_station("8507000");
        let zurich = network.add_station("8503000");
        
        network.add_track(bern, zurich, vec![(7.4, 46.9), (8.5, 47.3)]); 
        
        assert_eq!(network.station_count(), 2);
    }
}
