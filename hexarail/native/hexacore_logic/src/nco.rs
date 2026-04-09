// Copyright (c) Didier Stadelmann. All rights reserved.

use crate::domain::Problem;
use std::collections::HashMap;
use serde::{Serialize, Deserialize};

#[derive(Debug, Clone, PartialEq, rustler::NifMap)]
pub struct TensorData {
    pub job_features: Vec<Vec<f32>>,
    pub resource_features: Vec<Vec<f32>>,
    pub job_to_job_edges: Vec<Vec<usize>>,
    pub job_to_job_edge_features: Vec<Vec<f32>>,
    pub job_to_resource_edges: Vec<Vec<usize>>,
    pub global_features: Vec<f32>,
}

pub const TIME_BUCKETS: usize = 24;

// Strict Vocabulary Dictionary to prevent infinite growth and collisions
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct StrictDictionary {
    pub mapping: HashMap<String, usize>,
    pub frozen: bool,
}

impl Default for StrictDictionary {
    fn default() -> Self {
        let mut mapping = HashMap::new();
        mapping.insert("<UNK>".to_string(), 0); // ID 0 is always Unknown
        Self {
            mapping,
            frozen: false,
        }
    }
}

impl StrictDictionary {
    pub fn get_or_insert(&mut self, key: &str) -> usize {
        if let Some(&id) = self.mapping.get(key) {
            return id;
        }
        if self.frozen {
            return 0; // Return <UNK> if dictionary is frozen
        }
        let next_id = self.mapping.len();
        self.mapping.insert(key.to_string(), next_id);
        next_id
    }

    pub fn freeze(&mut self) {
        self.frozen = true;
    }
}

pub const MAX_SCORE_COMPONENTS: usize = 16;

#[derive(Debug, Default, Clone, Serialize, Deserialize)]
pub struct FeatureEncoder {
    pub batch_key_dict: StrictDictionary,
    pub edge_type_dict: StrictDictionary,
    pub resource_name_dict: StrictDictionary,
    pub score_name_dict: StrictDictionary,
}

impl FeatureEncoder {
    #[must_use]
    pub fn new() -> Self {
        Self::default()
    }
    
    pub fn freeze_vocabularies(&mut self) {
        self.batch_key_dict.freeze();
        self.edge_type_dict.freeze();
        self.resource_name_dict.freeze();
        self.score_name_dict.freeze();
    }

    pub fn export_json(&self) -> String {
        serde_json::to_string(self).unwrap_or_else(|_| "{}".to_string())
    }

    pub fn import_json(json: &str) -> Result<Self, String> {
        serde_json::from_str(json).map_err(|e| e.to_string())
    }

    #[must_use]
    pub fn encode(&mut self, problem: &Problem) -> TensorData {
        // 1. Calculate dynamic horizon (max_time) for normalization and bucketing
        // The theoretical worst-case makespan is the sum of all durations + sum of all lags
        let sum_durations: i64 = problem.jobs.iter().map(|j| j.duration).sum();
        let sum_lags: i64 = problem.edges.iter().map(|e| e.lag).sum();
        let theoretical_worst_case = (sum_durations + sum_lags) as f32;

        let mut max_time = theoretical_worst_case.max(1.0_f32); // Avoid division by zero

        for job in &problem.jobs {
            if let Some(due) = job.due_time {
                if due as f32 > max_time {
                    max_time = due as f32;
                }
            }
            if let Some(release) = job.release_time {
                let end = release + job.duration;
                if end as f32 > max_time {
                    max_time = end as f32;
                }
            }
        }
        
        let mut max_capacity = 1.0_f32;
        for res in &problem.resources {
            let cap = res.capacity as f32;
            if cap > max_capacity {
                max_capacity = cap;
            }
        }
        
        let bucket_size = max_time / (TIME_BUCKETS as f32);

        let mut job_to_idx = HashMap::new();
        let mut job_features = Vec::with_capacity(problem.jobs.len());

        for (idx, job) in problem.jobs.iter().enumerate() {
            job_to_idx.insert(job.id, idx);

            // Min-Max Scaling (Normalization) bounded to max_time
            let duration = (job.duration as f32) / max_time;
            let release_time = job.release_time.map_or(-1.0, |v| (v as f32) / max_time);
            let due_time = job.due_time.map_or(-1.0, |v| (v as f32) / max_time);
            let start_time = job.start_time.map_or(-1.0, |v| (v as f32) / max_time);

            let batch_key_id = match &job.batch_key {
                Some(key) => self.batch_key_dict.get_or_insert(key) as f32,
                None => -1.0, // Special value for no batch key
            };

            job_features.push(vec![duration, release_time, due_time, start_time, batch_key_id]);
        }

        let mut res_to_idx = HashMap::new();
        let mut resource_features = Vec::with_capacity(problem.resources.len());

        for (idx, res) in problem.resources.iter().enumerate() {
            res_to_idx.insert(res.id, idx);
            
            // Normalize capacity using dynamic max_capacity
            let capacity = (res.capacity as f32) / max_capacity; 
            let type_id = self.resource_name_dict.get_or_insert(&res.name) as f32;
            
            let mut res_feat = vec![capacity, type_id];
            
            // Discretize availability windows dynamically
            let mut time_grid = vec![1.0; TIME_BUCKETS];
            
            if bucket_size > 0.0 {
                for window in &res.availability_windows {
                    let start_f = window.start_at as f32;
                    let end_f = window.end_at as f32;
                    
                    let start_bucket = (start_f / bucket_size).floor() as usize;
                    let end_bucket = (end_f / bucket_size).floor() as usize;
                    
                    for b in start_bucket..=end_bucket {
                        if b < TIME_BUCKETS {
                            let bucket_start = (b as f32) * bucket_size;
                            let bucket_end = bucket_start + bucket_size;
                            
                            let overlap_start = start_f.max(bucket_start);
                            let overlap_end = end_f.min(bucket_end);
                            
                            if overlap_end > overlap_start {
                                let unavailable_fraction = (overlap_end - overlap_start) / bucket_size;
                                time_grid[b] = (time_grid[b] - unavailable_fraction).max(0.0);
                            }
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
                job_to_job_edges.push(vec![from_idx, to_idx]);
                
                // Normalize lag
                let lag = (edge.lag as f32) / max_time;
                let type_id = self.edge_type_dict.get_or_insert(&edge.edge_type) as f32;
                job_to_job_edge_features.push(vec![lag, type_id]);
            }
        }

        let mut job_to_resource_edges = Vec::new();
        for (job_idx, job) in problem.jobs.iter().enumerate() {
            for req_res_id in &job.required_resources {
                if let Some(&res_idx) = res_to_idx.get(req_res_id) {
                    job_to_resource_edges.push(vec![job_idx, res_idx]);
                }
            }
        }

        // Map score components into a fixed-size vector and normalize 
        // using a logarithmic or empirical scale to prevent exploding gradients.
        // Score = log1p(|value|) * sign(value)
        let mut global_features = vec![0.0; MAX_SCORE_COMPONENTS];
        for comp in &problem.score_components {
            let pos = self.score_name_dict.get_or_insert(&comp.name);
            if pos < MAX_SCORE_COMPONENTS {
                let v = comp.value as f32;
                global_features[pos] += v.signum() * (v.abs() + 1.0).ln();
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
    fn test_extract_features_translates_problem_to_normalized_markov_state_tensor() {
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
                        // Max time is 120 (due_time of Job 10). 120 / 24 buckets = 5 units per bucket.
                        // 0 to 10 covers buckets 0 and 1 (fully)
                        Window { start_at: 0, end_at: 10 },
                    ],
                },
            ],
            jobs: vec![
                Job {
                    id: 10,
                    duration: 60,
                    required_resources: vec![1],
                    release_time: Some(0),
                    due_time: Some(120), // Sets max_time to 120
                    batch_key: None,
                    start_time: Some(60),
                },
                Job {
                    id: 20,
                    duration: 30,
                    required_resources: vec![2],
                    release_time: None,
                    due_time: None,
                    batch_key: Some("HOT".to_string()),
                    start_time: None,
                },
                Job {
                    id: 30,
                    duration: 30,
                    required_resources: vec![2],
                    release_time: None,
                    due_time: None,
                    batch_key: Some("HOT".to_string()), // Should share the same ID in dictionary
                    start_time: None,
                },
            ],
            edges: vec![Edge {
                from_job_id: 10,
                to_job_id: 20,
                lag: 12,
                edge_type: "sequence".to_string(),
            }],
            score_components: vec![
                ScoreComponent { name: "tardiness".to_string(), value: 500 },
                ScoreComponent { name: "setup".to_string(), value: 20 },
                ScoreComponent { name: "unknown_metric".to_string(), value: 999 }, // Should be ignored
            ],
        };

        let mut encoder = FeatureEncoder::new();
        let tensor = encoder.encode(&problem);

        assert_eq!(tensor.job_features.len(), 3);
        assert_eq!(tensor.resource_features.len(), 2);
        
        // global_features should be exactly MAX_SCORE_COMPONENTS elements
        assert_eq!(tensor.global_features.len(), 16);

        // Job 0: max_time=132. duration=60->0.4545, release=0->0.0, due=120->0.909, start=60->0.4545
        assert!((tensor.job_features[0][0] - 0.4545).abs() < 0.01);
        assert!((tensor.job_features[0][1] - 0.0).abs() < 0.01);
        assert!((tensor.job_features[0][2] - 0.909).abs() < 0.01);
        assert!((tensor.job_features[0][3] - 0.4545).abs() < 0.01);
        assert_eq!(tensor.job_features[0][4], -1.0);
        
        // Job 1: duration=30->0.2272, "HOT" is added to dict (ID 1 since 0 is <UNK>)
        assert!((tensor.job_features[1][0] - 0.2272).abs() < 0.01);
        assert_eq!(tensor.job_features[1][1..5], vec![-1.0, -1.0, -1.0, 1.0][..]);
        
        // Job 2: duration=30->0.2272, "HOT" -> ID 1.0
        assert!((tensor.job_features[2][0] - 0.2272).abs() < 0.01);
        assert_eq!(tensor.job_features[2][1..5], vec![-1.0, -1.0, -1.0, 1.0][..]);

        // Resource 0: capacity 1/2 -> 0.5, name "M1" -> 1.0, and 24 fully available buckets (1.0)
        assert_eq!(tensor.resource_features[0][0], 0.5);
        assert_eq!(tensor.resource_features[0][1], 1.0); // ID 1
        assert_eq!(tensor.resource_features[0][2..], vec![1.0; 24][..]);
        
        // Resource 1: capacity 2/2 -> 1.0, name "M2" -> 2.0.
        assert_eq!(tensor.resource_features[1][0], 1.0);
        assert_eq!(tensor.resource_features[1][1], 2.0); // ID 2
        
        // Bucket size is 132 / 24 = 5.5.
        // Window 0-10 covers bucket 0 (0-5.5) fully, bucket 1 (5.5-11.0) partially (10-5.5=4.5 out of 5.5 => 0.818 unavailable -> 0.1818 available)
        assert_eq!(tensor.resource_features[1][2], 0.0); // bucket 0 unavailable
        assert!((tensor.resource_features[1][3] - 0.1818).abs() < 0.01); // bucket 1 partially available
        assert_eq!(tensor.resource_features[1][4], 1.0); // bucket 2 fully available

        assert_eq!(tensor.job_to_job_edges.len(), 1);
        assert_eq!(tensor.job_to_job_edges[0], vec![0, 1]);

        assert_eq!(tensor.job_to_job_edge_features.len(), 1);
        // Edge features: lag is 12 / 132 = 0.0909, type is ID 1.0
        assert!((tensor.job_to_job_edge_features[0][0] - 0.0909).abs() < 0.01);
        assert_eq!(tensor.job_to_job_edge_features[0][1], 1.0);

        // Global features: Logarithmic scaling
        // unknown_metric is now added because we dynamically register scores. 
        // ID 1: tardiness: ln(501) ≈ 6.216
        // ID 2: setup: ln(21) ≈ 3.044
        // ID 3: unknown_metric: ln(1000) ≈ 6.907
        assert!((tensor.global_features[1] - 6.216).abs() < 0.01);
        assert!((tensor.global_features[2] - 3.044).abs() < 0.01);
        assert!((tensor.global_features[3] - 6.907).abs() < 0.01);
        
        // Test frozen dictionary behavior
        encoder.freeze_vocabularies();
        
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
                    batch_key: Some("COLD".to_string()), // Unknown key
                    start_time: None,
                },
            ],
            edges: vec![],
            score_components: vec![],
        };
        
        let tensor_2 = encoder.encode(&problem_2);
        // "COLD" was not seen before freezing, should map to <UNK> which is ID 0.0
        assert_eq!(tensor_2.job_features[0][4], 0.0); 
    }
}
