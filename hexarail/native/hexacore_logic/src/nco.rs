// Copyright (c) Didier Stadelmann. All rights reserved.

use crate::domain::Problem;
use std::collections::HashMap;

#[derive(Debug, Clone, PartialEq)]
pub struct TensorData {
    pub job_features: Vec<Vec<f32>>,
    pub resource_features: Vec<Vec<f32>>,
    pub job_to_job_edges: Vec<(usize, usize)>,
    pub job_to_job_edge_features: Vec<Vec<f32>>,
    pub job_to_resource_edges: Vec<(usize, usize)>,
    pub global_features: Vec<f32>,
}

#[derive(Debug, Default)]
pub struct CategoricalDictionary {
    pub mapping: HashMap<String, usize>,
}

impl CategoricalDictionary {
    pub fn get_or_insert(&mut self, key: &str) -> usize {
        let next_id = self.mapping.len();
        *self.mapping.entry(key.to_string()).or_insert(next_id)
    }
}

pub const MAX_WINDOWS: usize = 4;

#[derive(Debug, Default)]
pub struct FeatureEncoder {
    pub batch_key_dict: CategoricalDictionary,
    pub edge_type_dict: CategoricalDictionary,
    pub resource_name_dict: CategoricalDictionary,
}

impl FeatureEncoder {
    #[must_use]
    pub fn new() -> Self {
        Self::default()
    }

    #[must_use]
    pub fn encode(&mut self, problem: &Problem) -> TensorData {
        let mut job_to_idx = HashMap::new();
        let mut job_features = Vec::with_capacity(problem.jobs.len());

        for (idx, job) in problem.jobs.iter().enumerate() {
            job_to_idx.insert(job.id, idx);

            let duration = job.duration as f32;
            let release_time = job.release_time.map_or(-1.0, |v| v as f32);
            let due_time = job.due_time.map_or(-1.0, |v| v as f32);
            let start_time = job.start_time.map_or(-1.0, |v| v as f32);

            let batch_key_id = match &job.batch_key {
                Some(key) => self.batch_key_dict.get_or_insert(key) as f32,
                None => -1.0,
            };

            job_features.push(vec![duration, release_time, due_time, start_time, batch_key_id]);
        }

        let mut res_to_idx = HashMap::new();
        let mut resource_features = Vec::with_capacity(problem.resources.len());

        for (idx, res) in problem.resources.iter().enumerate() {
            res_to_idx.insert(res.id, idx);
            
            let capacity = res.capacity as f32;
            let type_id = self.resource_name_dict.get_or_insert(&res.name) as f32;
            
            let mut res_feat = vec![capacity, type_id];
            
            // Encode up to MAX_WINDOWS exact temporal bounds
            for i in 0..MAX_WINDOWS {
                if i < res.availability_windows.len() {
                    res_feat.push(res.availability_windows[i].start_at as f32);
                    res_feat.push(res.availability_windows[i].end_at as f32);
                } else {
                    res_feat.push(-1.0); // Padding start
                    res_feat.push(-1.0); // Padding end
                }
            }

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
                let type_id = self.edge_type_dict.get_or_insert(&edge.edge_type) as f32;
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

        // Sort score components by name to ensure stable channel indexing
        let mut sorted_scores = problem.score_components.clone();
        sorted_scores.sort_by(|a, b| a.name.cmp(&b.name));

        let mut global_features = Vec::with_capacity(sorted_scores.len());
        for comp in &sorted_scores {
            global_features.push(comp.value as f32);
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
                        Window { start_at: 0, end_at: 100 },
                        Window { start_at: 200, end_at: 300 },
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
                    start_time: Some(50), // Dynamic state!
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
                    batch_key: Some("HOT".to_string()), // Should share the same ID in dictionary
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
                ScoreComponent { name: "tardiness".to_string(), value: 500 },
                ScoreComponent { name: "setup".to_string(), value: 20 },
            ],
        };

        let mut encoder = FeatureEncoder::new();
        let tensor = encoder.encode(&problem);

        assert_eq!(tensor.job_features.len(), 3);
        assert_eq!(tensor.resource_features.len(), 2);
        assert_eq!(tensor.global_features.len(), 2);

        // Job 0: no batch_key -> -1.0. start_time = 50.0
        assert_eq!(tensor.job_features[0], vec![5.0, 0.0, 100.0, 50.0, -1.0]);
        
        // Job 1: batch_key "HOT" -> assigned categorical id 0.0. start_time = -1.0
        assert_eq!(tensor.job_features[1], vec![8.0, -1.0, -1.0, -1.0, 0.0]);
        
        // Job 2: batch_key "HOT" -> MUST share the categorical id 0.0
        assert_eq!(tensor.job_features[2], vec![10.0, -1.0, -1.0, -1.0, 0.0]);

        // Resource 0: capacity 1, name "M1" -> id 0.0, padded 4 windows (-1.0)
        assert_eq!(tensor.resource_features[0], vec![
            1.0, 0.0,
            -1.0, -1.0, -1.0, -1.0, -1.0, -1.0, -1.0, -1.0
        ]);
        
        // Resource 1: capacity 2, name "M2" -> id 1.0, 2 actual windows, 2 padded windows
        assert_eq!(tensor.resource_features[1], vec![
            2.0, 1.0,
            0.0, 100.0, 200.0, 300.0, -1.0, -1.0, -1.0, -1.0
        ]);

        assert_eq!(tensor.job_to_job_edges.len(), 1);
        assert_eq!(tensor.job_to_job_edges[0], (0, 1));

        assert_eq!(tensor.job_to_job_edge_features.len(), 1);
        // Edge features: lag is 15.0, type is categorical id 0.0
        assert_eq!(tensor.job_to_job_edge_features[0], vec![15.0, 0.0]);

        assert_eq!(tensor.job_to_resource_edges.len(), 3);
        assert!(tensor.job_to_resource_edges.contains(&(0, 0))); // Job 10 -> Res 1
        assert!(tensor.job_to_resource_edges.contains(&(1, 1))); // Job 20 -> Res 2
        assert!(tensor.job_to_resource_edges.contains(&(2, 1))); // Job 30 -> Res 2
        
        // Global features: sorted alphabetically ("setup" before "tardiness")
        // "setup" = 20.0, "tardiness" = 500.0
        assert_eq!(tensor.global_features, vec![20.0, 500.0]);
        
        // Re-encode a second problem to test statefulness of the dictionary
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
                    batch_key: Some("COLD".to_string()), // New key, should get ID 1.0
                    start_time: None,
                },
            ],
            edges: vec![],
            score_components: vec![],
        };
        
        let tensor_2 = encoder.encode(&problem_2);
        assert_eq!(tensor_2.job_features[0][4], 1.0); // "COLD" is 1.0
    }
}
