// Copyright (c) Didier Stadelmann. All rights reserved.

use rustler::NifStruct;
use serde::{Serialize, Deserialize};

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
    #[must_use]
    #[allow(clippy::cast_precision_loss, clippy::cast_possible_truncation, clippy::cast_sign_loss)]
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
        let e00 = f64::from(self.elevations[y0 * cols + x0]);
        let e10 = f64::from(self.elevations[y0 * cols + x1]);
        let e01 = f64::from(self.elevations[y1 * cols + x0]);
        let e11 = f64::from(self.elevations[y1 * cols + x1]);
        
        let e0 = e00 * (1.0 - dx) + e10 * dx;
        let e1 = e01 * (1.0 - dx) + e11 * dx;
        
        e0 * (1.0 - dy) + e1 * dy
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, PartialOrd, Ord, NifStruct)]
#[module = "HexaCore.Domain.HardMediumSoftScore"]
pub struct HardMediumSoftScore {
    pub hard: i64,
    pub medium: i64,
    pub soft: i64,
}

impl HardMediumSoftScore {
    #[must_use]
    pub fn new(hard: i64, medium: i64, soft: i64) -> Self {
        Self {
            hard,
            medium,
            soft,
        }
    }

    #[must_use]
    pub fn zero() -> Self {
        Self::new(0, 0, 0)
    }
}

impl std::ops::AddAssign for HardMediumSoftScore {
    fn add_assign(&mut self, other: Self) {
        self.hard += other.hard;
        self.medium += other.medium;
        self.soft += other.soft;
    }
}

impl std::ops::Add for HardMediumSoftScore {
    type Output = Self;
    fn add(self, other: Self) -> Self {
        Self {
            hard: self.hard + other.hard,
            medium: self.medium + other.medium,
            soft: self.soft + other.soft,
        }
    }
}

impl std::ops::Sub for HardMediumSoftScore {
    type Output = Self;
    fn sub(self, other: Self) -> Self {
        Self {
            hard: self.hard - other.hard,
            medium: self.medium - other.medium,
            soft: self.soft - other.soft,
        }
    }
}

impl std::ops::SubAssign for HardMediumSoftScore {
    fn sub_assign(&mut self, other: Self) {
        self.hard -= other.hard;
        self.medium -= other.medium;
        self.soft -= other.soft;
    }
}

#[derive(Debug, Clone, NifStruct)]
#[module = "HexaCore.Domain.Resource"]
pub struct Resource {
    pub id: i64,
    pub name: String,
    pub capacity: i64,
    pub availability_windows: Vec<Window>,
}

#[derive(Debug, Clone, NifStruct)]
#[module = "HexaCore.Domain.Job"]
pub struct Job {
    pub id: i64,
    pub duration: i64,
    pub required_resources: Vec<i64>,
    pub release_time: Option<i64>,
    pub due_time: Option<i64>,
    pub group_id: Option<String>,
    pub start_time: Option<i64>,
}

#[derive(Debug, Clone, NifStruct)]
#[module = "HexaCore.Domain.Window"]
pub struct Window {
    pub start_at: i64,
    pub end_at: i64,
}

#[derive(Debug, Clone, NifStruct)]
#[module = "HexaCore.Domain.Edge"]
pub struct Edge {
    pub from_job_id: i64,
    pub to_job_id: i64,
    pub lag: i64,
    pub edge_type: String,
}

#[derive(Debug, Clone, NifStruct)]
#[module = "HexaCore.Domain.ScoreComponent"]
pub struct ScoreComponent {
    pub name: String,
    pub value: i64,
}

#[derive(Debug, Clone, NifStruct)]
#[module = "Geo.Point"]
pub struct GeoPoint {
    pub coordinates: (f64, f64),
    pub srid: Option<i32>,
}

#[derive(Debug, Clone, PartialEq, Eq, NifStruct)]
#[module = "HexaCore.Domain.ConstraintViolation"]
pub struct ConstraintViolation {
    pub name: String,
    pub severity: String, // "hard", "medium", "soft"
    pub message: String,
    pub job_id: Option<i64>,
    pub resource_id: Option<i64>,
}

#[derive(Debug, Clone, PartialEq, Eq, NifStruct)]
#[module = "HexaCore.Domain.ScoreExplanation"]
pub struct ScoreExplanation {
    pub score: HardMediumSoftScore,
    pub violations: Vec<ConstraintViolation>,
}

#[derive(Debug, Clone, NifStruct)]
#[module = "HexaCore.Domain.Problem"]
pub struct Problem {
    pub id: String,
    pub resources: Vec<Resource>,
    pub jobs: Vec<Job>,
    pub edges: Vec<Edge>,
    pub score_components: Vec<ScoreComponent>,
    pub explanation: Option<ScoreExplanation>,
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_domain_clone() {
        let j1 = Job {
            id: 1,
            duration: 10,
            required_resources: vec![],
            release_time: None,
            due_time: None,
            group_id: None,
            start_time: None,
        };
        let j2 = j1.clone();
        assert_eq!(j1.id, j2.id);
    }

    #[test]
    fn test_problem_instantiation() {
        let r1 = Resource {
            id: 1,
            name: "Machine".to_string(),
            capacity: 1,
            availability_windows: vec![],
        };
        let j1 = Job {
            id: 100,
            duration: 60,
            required_resources: vec![1],
            release_time: None,
            due_time: None,
            group_id: None,
            start_time: None,
        };
        let problem = Problem {
            id: "sim_1".to_string(),
            resources: vec![r1],
            jobs: vec![j1],
            edges: vec![],
            score_components: vec![],
            explanation: None,
        };
        
        assert_eq!(problem.jobs.len(), 1);
    }
}
