use rustler::NifStruct;
use serde::{Serialize, Deserialize};

#[derive(Debug, Clone, NifStruct)]
#[module = "HexaPlanner.Domain.Resource"]
pub struct Resource {
    pub id: i64,
    pub name: String,
    pub capacity: i64,
}

#[derive(Debug, Clone, NifStruct)]
#[module = "HexaPlanner.Domain.Job"]
pub struct Job {
    pub id: i64,
    pub duration: i64,
    pub required_resources: Vec<i64>,
    pub start_time: Option<i64>,
}

#[derive(Debug, Clone, NifStruct)]
#[module = "Geo.Point"]
pub struct GeoPoint {
    pub coordinates: (f64, f64),
    pub srid: Option<i32>,
}

#[derive(Debug, Clone, NifStruct)]
#[module = "HexaPlanner.GTFS.Stop"]
pub struct GtfsStop {
    pub id: i64,
    pub original_stop_id: String,
    pub stop_name: String,
    pub abbreviation: Option<String>,
    pub location_type: Option<i32>,
    pub parent_station: Option<String>,
    pub platform_code: Option<String>,
    pub location: GeoPoint,
}

#[derive(Debug, Clone, NifStruct)]
#[module = "HexaPlanner.GTFS.Trip"]
pub struct GtfsTrip {
    pub id: i64,
    pub original_trip_id: String,
    pub route_id: String,
    pub service_id: String,
    pub trip_headsign: Option<String>,
    pub trip_short_name: Option<String>,
    pub direction_id: Option<i32>,
    pub block_id: Option<String>,
}

#[derive(Debug, Clone, NifStruct, Serialize, Deserialize)]
#[module = "HexaPlanner.GTFS.StopTime"]
pub struct GtfsStopTime {
    pub trip_id: i64,
    pub stop_id: i64,
    pub arrival_time: i32,
    pub departure_time: i32,
    pub stop_sequence: i32,
    pub pickup_type: Option<i32>,
    pub drop_off_type: Option<i32>,
}

#[derive(Debug, Clone, NifStruct)]
#[module = "HexaPlanner.GTFS.Transfer"]
pub struct GtfsTransfer {
    pub from_stop_id: i64,
    pub to_stop_id: i64,
    pub transfer_type: i32,
    pub min_transfer_time: Option<i32>,
    pub from_trip_id: Option<i64>,
    pub to_trip_id: Option<i64>,
    pub from_route_id: Option<i64>,
    pub to_route_id: Option<i64>,
}

#[derive(Debug, Clone, NifStruct)]
#[module = "HexaPlanner.GTFS.Calendar"]
pub struct GtfsCalendar {
    pub service_id: String,
    pub monday: i32,
    pub tuesday: i32,
    pub wednesday: i32,
    pub thursday: i32,
    pub friday: i32,
    pub saturday: i32,
    pub sunday: i32,
    pub start_date: i32,
    pub end_date: i32,
}

#[derive(Debug, Clone, NifStruct)]
#[module = "HexaPlanner.GTFS.CalendarDate"]
pub struct GtfsCalendarDate {
    pub service_id: String,
    pub date: i32,
    pub exception_type: i32,
}

#[derive(Debug, Clone, NifStruct)]
#[module = "HexaPlanner.Data.Parser.TrackSegment"]
pub struct TrackSegment {
    pub line_id: String,
    pub coordinates: Vec<(f64, f64)>,
    pub properties: std::collections::HashMap<String, String>,
}

#[derive(Debug, Clone, NifStruct)]
#[module = "HexaPlanner.Domain.EOS"]
pub struct ElementaryOccupationSegment {
    pub trip_id: i64,
    pub track_id: String,
    pub start_time: i32,
    pub end_time: i32,
}

#[derive(Debug, Clone, NifStruct)]
#[module = "HexaPlanner.Domain.Conflict"]
pub struct Conflict {
    pub trip_a: i64,
    pub trip_b: i64,
    pub track_id: String,
    pub start_time: i32,
    pub end_time: i32,
}

#[derive(Debug, Clone, NifStruct)]
#[module = "HexaPlanner.Domain.ConflictSummary"]
pub struct ConflictSummary {
    pub total_conflicts: usize,
    pub sample_conflicts: Vec<Conflict>,
}

#[derive(Debug, Clone, NifStruct)]
#[module = "HexaPlanner.Domain.ResolutionMetrics"]
pub struct ResolutionMetrics {
    pub status: String,
    pub trains_impacted: usize,
    pub total_delay_added: u32,
    pub computation_time_ms: u32,
}

#[derive(Debug, Clone, NifStruct, Serialize, Deserialize)]
#[module = "HexaPlanner.Domain.CompactEOS"]
pub struct CompactEOS {
    pub trip_idx: u32,
    pub track_idx: u32,
    pub start_time: u32,
    pub end_time: u32,
}

#[derive(Debug, Clone, NifStruct)]
#[module = "HexaPlanner.Fleet.RollingStockProfile"]
pub struct RollingStockProfile {
    pub model: String,
    pub length_meters: f64,
    pub mass_tonnes: f64,
    pub max_speed_kmh: f64,
    pub acceleration_ms2: f64,
}

#[derive(Debug, Clone, NifStruct)]
#[module = "HexaPlanner.Domain.OsmNode"]
pub struct OsmNode {
    pub id: i64,
    pub lat: f64,
    pub lon: f64,
    pub tags: std::collections::HashMap<String, String>,
}

#[derive(Debug, Clone, NifStruct)]
#[module = "HexaPlanner.Domain.OsmWay"]
pub struct OsmWay {
    pub id: i64,
    pub nodes: Vec<i64>,
    pub tags: std::collections::HashMap<String, String>,
}

#[derive(Debug, Clone, NifStruct)]
#[module = "HexaPlanner.Domain.Problem"]
pub struct Problem {
    pub id: String,
    pub resources: Vec<Resource>,
    pub jobs: Vec<Job>,
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_domain_clone() {
        let j1 = Job { id: 1, duration: 10, required_resources: vec![], start_time: None };
        let j2 = j1.clone();
        assert_eq!(j1.id, j2.id);
    }

    #[test]
    fn test_problem_instantiation() {
        let r1 = Resource { id: 1, name: "Machine".to_string(), capacity: 1 };
        let j1 = Job { id: 100, duration: 60, required_resources: vec![1], start_time: None };
        let problem = Problem { id: "sim_1".to_string(), resources: vec![r1], jobs: vec![j1] };
        
        assert_eq!(problem.jobs.len(), 1);
    }

    #[test]
    fn test_gtfs_stop_struct() {
        let stop = GtfsStop {
            id: 1,
            original_stop_id: "8500010".to_string(),
            stop_name: "Basel SBB".to_string(),
            abbreviation: Some("BS".to_string()),
            location_type: Some(1),
            parent_station: None,
            platform_code: Some("4".to_string()),
            location: GeoPoint {
                coordinates: (7.589, 47.547),
                srid: Some(4326),
            },
        };
        assert_eq!(stop.stop_name, "Basel SBB");
    }
}