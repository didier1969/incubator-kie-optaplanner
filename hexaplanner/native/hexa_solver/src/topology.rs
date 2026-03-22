use petgraph::graph::{NodeIndex, UnGraph, DiGraph};
use std::collections::HashMap;
use crate::domain::{GtfsStop, GtfsStopTime, TrackSegment, GtfsTransfer, GtfsCalendar, GtfsCalendarDate};

/// Represents the physical layer: rails and stations.
pub struct PhysicalNetwork {
    pub graph: UnGraph<String, Vec<(f64, f64)>>, // Node: Station ID, Edge: Curve Coordinates
    pub station_map: HashMap<String, NodeIndex>,
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
            self.physical.add_station(&stop.original_stop_id);
            self.temporal.get_or_create_node(stop.id);
            self.stops.insert(stop.id, stop);
        }
    }

    pub fn load_tracks(&mut self, _tracks: Vec<TrackSegment>) {
        // Implementation for spatial matching goes here in Phase 12B
    }

    /// Fast accumulation of stop times. Does NOT build edges yet.
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

    /// Finalizes the temporal graph in a single O(N) pass.
    /// Should be called after all stop times are loaded.
    pub fn finalize_temporal_graph(&mut self) -> usize {
        // Use add_edge instead of update_edge to allow multiple trips between same stations
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
        self.temporal.graph.edge_count()
    }

    #[must_use]
    pub fn get_position(&self, trip_id: i64, time: i32) -> Option<(f64, f64)> {
        let events = self.trips.get(&trip_id)?;
        if events.is_empty() { return None; }

        // 1. Find the segment the train is currently in
        for i in 0..events.len() - 1 {
            let from = &events[i];
            let to = &events[i+1];

            if time >= from.departure_time && time <= to.arrival_time {
                let from_stop = self.stops.get(&from.stop_id)?;
                let to_stop = self.stops.get(&to.stop_id)?;

                let duration = to.arrival_time - from.departure_time;
                if duration <= 0 { return Some(from_stop.location.coordinates); }
                
                let progress = f64::from(time - from.departure_time) / f64::from(duration);
                
                // HIGH-FIDELITY: In Phase 12B, we lookup the PhysicalNetwork edge 
                // between from_stop and to_stop to get the CURVE.
                // For now, we perform high-precision linear interpolation.
                let lon = from_stop.location.coordinates.0 + (to_stop.location.coordinates.0 - from_stop.location.coordinates.0) * progress;
                let lat = from_stop.location.coordinates.1 + (to_stop.location.coordinates.1 - from_stop.location.coordinates.1) * progress;
                
                return Some((lon, lat));
            }
        }

        // 2. Handle cases where train is stopped at a station
        for event in events {
            if time >= event.arrival_time && time <= event.departure_time {
                let stop = self.stops.get(&event.stop_id)?;
                return Some(stop.location.coordinates);
            }
        }

        None
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
