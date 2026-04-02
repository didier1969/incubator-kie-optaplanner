// Copyright (c) Didier Stadelmann. All rights reserved.

use crate::domain::GeoPoint;
use rustler::NifStruct;
use serde::{Deserialize, Serialize};
use std::collections::HashMap;

#[derive(Debug, Clone, Serialize, Deserialize, rustler::NifStruct)]
#[module = "HexaRail.Domain.Perturbation"]
pub struct Perturbation {
    pub id: String,
    pub perturbation_type: String,
    pub target_id: String,
    pub start_time: i32,
    pub duration: i32,
}

#[derive(Debug, Clone, Serialize, Deserialize, rustler::NifStruct)]
#[module = "HexaRail.Domain.SystemHealth"]
pub struct SystemHealth {
    pub total_delay_seconds: i64,
    pub active_conflicts: i32,
    pub broken_connections: i32,
    pub active_perturbations: i32,
}

#[derive(Debug, Clone, rustler::NifStruct)]
#[module = "HexaRail.Domain.ActivePosition"]
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
    pub properties: HashMap<String, String>,
}

#[derive(Debug, Clone, NifStruct)]
#[module = "HexaRail.Domain.EOS"]
pub struct ElementaryOccupationSegment {
    pub trip_id: i64,
    pub track_id: String,
    pub start_time: i32,
    pub end_time: i32,
}

#[derive(Debug, Clone, NifStruct)]
#[module = "HexaRail.Domain.Conflict"]
pub struct Conflict {
    pub trip_a: i64,
    pub trip_b: i64,
    pub track_id: String,
    pub start_time: i32,
    pub end_time: i32,
}

#[derive(Debug, Clone, NifStruct)]
#[module = "HexaRail.Domain.ConflictSummary"]
pub struct ConflictSummary {
    pub total_conflicts: usize,
    pub sample_conflicts: Vec<Conflict>,
}

#[derive(Debug, Clone, NifStruct)]
#[module = "HexaRail.Domain.ResolutionMetrics"]
pub struct ResolutionMetrics {
    pub status: String,
    pub trains_impacted: usize,
    pub total_delay_added: u32,
    pub computation_time_ms: u32,
}

#[derive(Debug, Clone, NifStruct, Serialize, Deserialize)]
#[module = "HexaRail.Domain.CompactEOS"]
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
    pub tags: HashMap<String, String>,
}

#[derive(Debug, Clone, NifStruct)]
#[module = "HexaRail.Domain.OsmWay"]
pub struct OsmWay {
    pub id: i64,
    pub nodes: Vec<i64>,
    pub tags: HashMap<String, String>,
}
