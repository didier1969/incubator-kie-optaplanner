use rustler::NifStruct;
use serde::{Serialize, Deserialize};

#[derive(Debug, Clone, rustler::NifStruct)]
#[module = "HexaCore.Domain.ActivePosition"]
pub struct ActivePosition {
    pub trip_id: i64,
    pub head_lon: f64,
    pub head_lat: f64,
    pub tail_lon: f64,
    pub tail_lat: f64,
    pub alt: f64,
    pub heading: f64,
    pub pitch: f64,
    pub roll: f64,
    pub velocity: f64,
}

#[derive(Debug, Clone, Serialize, Deserialize, rustler::NifStruct)]
#[module = "HexaCore.Domain.DemGrid"]
pub struct DemGrid {
    pub lat_min: f64,
    pub lat_max: f64,
    pub lon_min: f64,
    pub lon_max: f64,
    pub lat_steps: usize,
    pub lon_steps: usize,
    pub elevations: Vec<f32>,
}

impl DemGrid {
    pub fn get_elevation(&self, lon: f64, lat: f64) -> f64 {
        if lon < self.lon_min || lon > self.lon_max || lat < self.lat_min || lat > self.lat_max {
            return 400.0; // Default off-grid
        }
        
        let lon_progress = (lon - self.lon_min) / (self.lon_max - self.lon_min);
        let lat_progress = (lat - self.lat_min) / (self.lat_max - self.lat_min);
        
        let x_float = lon_progress * self.lon_steps as f64;
        let y_float = lat_progress * self.lat_steps as f64;
        
        let x0 = (x_float.floor() as usize).min(self.lon_steps - 1);
        let x1 = (x0 + 1).min(self.lon_steps);
        let y0 = (y_float.floor() as usize).min(self.lat_steps - 1);
        let y1 = (y0 + 1).min(self.lat_steps);
        
        let dx = x_float - x0 as f64;
        let dy = y_float - y0 as f64;
        
        let cols = self.lon_steps + 1;
        
        // Bilinear interpolation
        let e00 = self.elevations[y0 * cols + x0] as f64;
        let e10 = self.elevations[y0 * cols + x1] as f64;
        let e01 = self.elevations[y1 * cols + x0] as f64;
        let e11 = self.elevations[y1 * cols + x1] as f64;
        
        let e0 = e00 * (1.0 - dx) + e10 * dx;
        let e1 = e01 * (1.0 - dx) + e11 * dx;
        
        e0 * (1.0 - dy) + e1 * dy
    }
}

#[derive(Debug, Clone, NifStruct)]
#[module = "HexaCore.Domain.Resource"]
pub struct Resource {
    pub id: i64,
    pub name: String,
    pub capacity: i64,
}

#[derive(Debug, Clone, NifStruct)]
#[module = "HexaCore.Domain.Job"]
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
#[module = "HexaRail.GTFS.Stop"]
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
#[module = "HexaRail.GTFS.Trip"]
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
#[module = "HexaRail.GTFS.StopTime"]
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
#[module = "HexaRail.GTFS.Transfer"]
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
#[module = "HexaRail.GTFS.Calendar"]
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
#[module = "HexaRail.GTFS.CalendarDate"]
pub struct GtfsCalendarDate {
    pub service_id: String,
    pub date: i32,
    pub exception_type: i32,
}

#[derive(Debug, Clone, NifStruct)]
#[module = "HexaRail.Data.Parser.TrackSegment"]
pub struct TrackSegment {
    pub line_id: String,
    pub coordinates: Vec<(f64, f64)>,
    pub properties: std::collections::HashMap<String, String>,
}

#[derive(Debug, Clone, NifStruct)]
#[module = "HexaCore.Domain.EOS"]
pub struct ElementaryOccupationSegment {
    pub trip_id: i64,
    pub track_id: String,
    pub start_time: i32,
    pub end_time: i32,
}

#[derive(Debug, Clone, NifStruct)]
#[module = "HexaCore.Domain.Conflict"]
pub struct Conflict {
    pub trip_a: i64,
    pub trip_b: i64,
    pub track_id: String,
    pub start_time: i32,
    pub end_time: i32,
}

#[derive(Debug, Clone, NifStruct)]
#[module = "HexaCore.Domain.ConflictSummary"]
pub struct ConflictSummary {
    pub total_conflicts: usize,
    pub sample_conflicts: Vec<Conflict>,
}

#[derive(Debug, Clone, NifStruct)]
#[module = "HexaCore.Domain.ResolutionMetrics"]
pub struct ResolutionMetrics {
    pub status: String,
    pub trains_impacted: usize,
    pub total_delay_added: u32,
    pub computation_time_ms: u32,
}

#[derive(Debug, Clone, NifStruct, Serialize, Deserialize)]
#[module = "HexaCore.Domain.CompactEOS"]
pub struct CompactEOS {
    pub trip_idx: u32,
    pub track_idx: u32,
    pub start_time: u32,
    pub end_time: u32,
}

#[derive(Debug, Clone, NifStruct)]
#[module = "HexaRail.Fleet.RollingStockProfile"]
pub struct RollingStockProfile {
    pub model: String,
    pub length_meters: f64,
    pub mass_tonnes: f64,
    pub max_speed_kmh: f64,
    pub acceleration_ms2: f64,
}

#[derive(Debug, Clone, NifStruct)]
#[module = "HexaRail.Domain.OsmNode"]
pub struct OsmNode {
    pub id: i64,
    pub lat: f64,
    pub lon: f64,
    pub tags: std::collections::HashMap<String, String>,
}

#[derive(Debug, Clone, NifStruct)]
#[module = "HexaRail.Domain.OsmWay"]
pub struct OsmWay {
    pub id: i64,
    pub nodes: Vec<i64>,
    pub tags: std::collections::HashMap<String, String>,
}

#[derive(Debug, Clone, NifStruct)]
#[module = "HexaCore.Domain.Problem"]
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