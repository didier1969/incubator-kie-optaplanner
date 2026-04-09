// Copyright (c) Didier Stadelmann. All rights reserved.

use crate::domain::Problem;
use std::collections::hash_map::DefaultHasher;
use std::collections::HashMap;
use std::hash::{Hash, Hasher};

#[derive(Debug, Clone, PartialEq)]
pub struct TensorData {
    pub job_features: Vec<Vec<f32>>,
    pub resource_features: Vec<Vec<f32>>,
    pub job_to_job_edges: Vec<(usize, usize)>,
    pub job_to_job_edge_features: Vec<Vec<f32>>,
    pub job_to_resource_edges: Vec<(usize, usize)>,
    pub global_features: Vec<f32>,
}

pub const HASH_BUCKETS: usize = 256;
pub const TIME_BUCKETS: usize = 24;
pub const BUCKET_SIZE: i64 = 60; // 60 minutes per bucket (1 day total)

// Feature Hashing trick: deterministically map strings to a bounded ID [0, HASH_BUCKETS - 1]
fn hash_to_bucket(key: &str) -> f32 {
    let mut hasher = DefaultHasher::new();
    key.hash(&mut hasher);
    (hasher.finish() % HASH_BUCKETS as u64) as f32
}

// Fixed schema for global score components to ensure static tensor dimension
const KNOWN_SCORE_COMPONENTS: [&str; 4] = [
    "tardiness",
    "setup",
    "makespan",
    "idle_time",
];

#[derive(Debug, Default)]
pub struct FeatureEncoder {}

impl FeatureEncoder {
    #[must_use]
    pub fn new() -> Self {
        Self::default()
    }

    #[must_use]
    pub fn encode(&self, problem: &Problem) -> TensorData {
        let mut job_to_idx = HashMap::new();
        let mut job_features = Vec::with_capacity(problem.jobs.len());

        for (idx, job) in problem.jobs.iter().enumerate() {
            job_to_idx.insert(job.id, idx);

            let duration = job.duration as f32;
            let release_time = job.release_time.map_or(-1.0, |v| v as f32);
            let due_time = job.due_time.map_or(-1.0, |v| v as f32);
            let start_time = job.start_time.map_or(-1.0, |v| v as f32);

            let batch_key_id = match &job.batch_key {
                Some(key) => hash_to_bucket(key),
                None => -1.0, // Special value for no batch key
            };

            job_features.push(vec![duration, release_time, due_time, start_time, batch_key_id]);
        }

        let mut res_to_idx = HashMap::new();
        let mut resource_features = Vec::with_capacity(problem.resources.len());

        for (idx, res) in problem.resources.iter().enumerate() {
            res_to_idx.insert(res.id, idx);
            
            let capacity = res.capacity as f32;
            let type_id = hash_to_bucket(&res.name);
            
            let mut res_feat = vec![capacity, type_id];
            
            // Discretize availability windows into fixed TIME_BUCKETS (e.g., 24 hours of 60 mins)
            // 1.0 means available for the whole bucket, 0.0 means completely unavailable
            let mut time_grid = vec![1.0; TIME_BUCKETS];
            
            for window in &res.availability_windows {
                let start_bucket = (window.start_at / BUCKET_SIZE).max(0) as usize;
                let end_bucket = (window.end_at / BUCKET_SIZE).max(0) as usize;
                
                for b in start_bucket..=end_bucket {
                    if b < TIME_BUCKETS {
                        let bucket_start = (b as i64) * BUCKET_SIZE;
                        let bucket_end = bucket_start + BUCKET_SIZE;
                        
                        let overlap_start = window.start_at.max(bucket_start);
                        let overlap_end = window.end_at.min(bucket_end);
                        
                        if overlap_end > overlap_start {
                            let unavailable_fraction = (overlap_end - overlap_start) as f32 / BUCKET_SIZE as f32;
                            time_grid[b] = (time_grid[b] - unavailable_fraction).max(0.0);
                        }
                    }
                }
            }

            res_feat.extend(time_grid);
            resource_features.push(res_feat);
        }

        let mut job_to_job_edges = Vec::with_capacity(problem.edges.len());
        let mut job_to_job_edge_features = Vec::with_capacity(problem.edges.len());
        
        for edge in &problem.edges {
            if let (Some(&from_idx), Some(&to_idx)) = (
                job_to_idx.get(&edge.from_job_id),
                job_to_idx.get(&edge.to_job_id),
            ) {
                job_to_job_edges.push((from_idx, to_idx));
                
                let lag = edge.lag as f32;
                let type_id = hash_to_bucket(&edge.edge_type);
                job_to_job_edge_features.push(vec![lag, type_id]);
            }
        }

        let mut job_to_resource_edges = Vec::new();
        for (job_idx, job) in problem.jobs.iter().enumerate() {
            for req_res_id in &job.required_resources {
                if let Some(&res_idx) = res_to_idx.get(req_res_id) {
                    job_to_resource_edges.push((job_idx, res_idx));
                }
            }
        }

        // Map score components into a fixed-size vector to guarantee static tensor shape
        let mut global_features = vec![0.0; KNOWN_SCORE_COMPONENTS.len()];
        for comp in &problem.score_components {
            if let Some(pos) = KNOWN_SCORE_COMPONENTS.iter().position(|&k| k == comp.name) {
                global_features[pos] += comp.value as f32;
            }
        }

        TensorData {
            job_features,
            resource_features,
            job_to_job_edges,
            job_to_job_edge_features,
            job_to_resource_edges,
            global_features,
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::domain::{Edge, Job, Resource, ScoreComponent, Window};

    #[test]
    fn test_extract_features_translates_problem_to_accurate_markov_state_tensor() {
        let problem = Problem {
            id: "p1".to_string(),
            resources: vec![
                Resource {
                    id: 1,
                    name: "M1".to_string(),
                    capacity: 1,
                    availability_windows: vec![],
                },
                Resource {
                    id: 2,
                    name: "M2".to_string(),
                    capacity: 2,
                    availability_windows: vec![
                        // From minute 0 to 60 -> bucket 0 is fully unavailable (0.0)
                        Window { start_at: 0, end_at: 60 },
                        // From minute 120 to 150 -> bucket 2 is half unavailable (0.5)
                        Window { start_at: 120, end_at: 150 },
                    ],
                },
            ],
            jobs: vec![
                Job {
                    id: 10,
                    duration: 5,
                    required_resources: vec![1],
                    release_time: Some(0),
                    due_time: Some(100),
                    batch_key: None,
                    start_time: Some(50),
                },
                Job {
                    id: 20,
                    duration: 8,
                    required_resources: vec![2],
                    release_time: None,
                    due_time: None,
                    batch_key: Some("HOT".to_string()),
                    start_time: None,
                },
                Job {
                    id: 30,
                    duration: 10,
                    required_resources: vec![2],
                    release_time: None,
                    due_time: None,
                    batch_key: Some("HOT".to_string()),
                    start_time: None,
                },
            ],
            edges: vec![Edge {
                from_job_id: 10,
                to_job_id: 20,
                lag: 15,
                edge_type: "sequence".to_string(),
            }],
            score_components: vec![
                // Will map to static indices: 0=tardiness, 1=setup
                ScoreComponent { name: "tardiness".to_string(), value: 500 },
                ScoreComponent { name: "setup".to_string(), value: 20 },
                ScoreComponent { name: "unknown_metric".to_string(), value: 999 }, // Should be ignored
            ],
        };

        let encoder = FeatureEncoder::new();
        let tensor = encoder.encode(&problem);

        assert_eq!(tensor.job_features.len(), 3);
        assert_eq!(tensor.resource_features.len(), 2);
        
        // global_features should be exactly 4 elements based on KNOWN_SCORE_COMPONENTS
        assert_eq!(tensor.global_features.len(), 4);

        // Job 0: no batch_key -> -1.0
        assert_eq!(tensor.job_features[0], vec![5.0, 0.0, 100.0, 50.0, -1.0]);
        
        // Job 1 & 2: "HOT" hash must be identical and bounded
        let hot_hash = hash_to_bucket("HOT");
        assert_eq!(tensor.job_features[1], vec![8.0, -1.0, -1.0, -1.0, hot_hash]);
        assert_eq!(tensor.job_features[2], vec![10.0, -1.0, -1.0, -1.0, hot_hash]);

        // Resource 0: capacity 1, name "M1" hash, and 24 fully available buckets (1.0)
        assert_eq!(tensor.resource_features[0][0], 1.0);
        assert_eq!(tensor.resource_features[0][1], hash_to_bucket("M1"));
        assert_eq!(tensor.resource_features[0][2..], vec![1.0; 24][..]);
        
        // Resource 1: capacity 2, name "M2" hash.
        assert_eq!(tensor.resource_features[1][0], 2.0);
        assert_eq!(tensor.resource_features[1][1], hash_to_bucket("M2"));
        
        // Bucket 0 (0-60) is fully unavailable -> 0.0
        assert_eq!(tensor.resource_features[1][2], 0.0);
        // Bucket 1 (60-120) is fully available -> 1.0
        assert_eq!(tensor.resource_features[1][3], 1.0);
        // Bucket 2 (120-180) is unavailable from 120-150 (30 mins) -> 0.5 available
        assert_eq!(tensor.resource_features[1][4], 0.5);
        // The rest should be 1.0
        assert_eq!(tensor.resource_features[1][5..], vec![1.0; 21][..]);

        assert_eq!(tensor.job_to_job_edges.len(), 1);
        assert_eq!(tensor.job_to_job_edges[0], (0, 1));

        assert_eq!(tensor.job_to_job_edge_features.len(), 1);
        // Edge features: lag is 15.0, type is hashed
        assert_eq!(tensor.job_to_job_edge_features[0], vec![15.0, hash_to_bucket("sequence")]);

        assert_eq!(tensor.job_to_resource_edges.len(), 3);
        assert!(tensor.job_to_resource_edges.contains(&(0, 0))); // Job 10 -> Res 1
        assert!(tensor.job_to_resource_edges.contains(&(1, 1))); // Job 20 -> Res 2
        assert!(tensor.job_to_resource_edges.contains(&(2, 1))); // Job 30 -> Res 2
        
        // Global features: fixed schema [tardiness, setup, makespan, idle_time]
        assert_eq!(tensor.global_features, vec![500.0, 20.0, 0.0, 0.0]);
        
        // Re-encode a second problem to test stateless determinism
        let problem_2 = Problem {
            id: "p2".to_string(),
            resources: vec![],
            jobs: vec![
                Job {
                    id: 40,
                    duration: 1,
                    required_resources: vec![],
                    release_time: None,
                    due_time: None,
                    batch_key: Some("COLD".to_string()),
                    start_time: None,
                },
            ],
            edges: vec![],
            score_components: vec![],
        };
        
        let tensor_2 = encoder.encode(&problem_2);
        assert_eq!(tensor_2.job_features[0][4], hash_to_bucket("COLD"));
    }
}
