// Copyright (c) Didier Stadelmann. All rights reserved.

use crate::domain::Problem;
use std::collections::hash_map::DefaultHasher;
use std::hash::{Hash, Hasher};

#[derive(Debug, Clone, PartialEq)]
pub struct TensorData {
    pub job_features: Vec<Vec<f32>>,
    pub resource_features: Vec<Vec<f32>>,
    pub job_to_job_edges: Vec<(usize, usize)>,
    pub job_to_job_edge_features: Vec<Vec<f32>>,
    pub job_to_resource_edges: Vec<(usize, usize)>,
}

fn hash_string_to_f32(s: &str) -> f32 {
    let mut hasher = DefaultHasher::new();
    s.hash(&mut hasher);
    // Normalize hash to a somewhat reasonable float range (e.g., modulo 10000)
    (hasher.finish() % 10000) as f32
}

#[must_use]
pub fn extract_features(problem: &Problem) -> TensorData {
    use std::collections::HashMap;

    let mut job_to_idx = HashMap::new();
    let mut job_features = Vec::with_capacity(problem.jobs.len());

    for (idx, job) in problem.jobs.iter().enumerate() {
        job_to_idx.insert(job.id, idx);

        let duration = job.duration as f32;
        let release_time = job.release_time.map_or(-1.0, |v| v as f32);
        let due_time = job.due_time.map_or(-1.0, |v| v as f32);
        
        let batch_key_hash = match &job.batch_key {
            Some(key) => hash_string_to_f32(key),
            None => -1.0,
        };

        job_features.push(vec![duration, release_time, due_time, batch_key_hash]);
    }

    let mut res_to_idx = HashMap::new();
    let mut resource_features = Vec::with_capacity(problem.resources.len());

    for (idx, res) in problem.resources.iter().enumerate() {
        res_to_idx.insert(res.id, idx);
        
        let capacity = res.capacity as f32;
        let window_count = res.availability_windows.len() as f32;
        
        let mut total_window_duration = 0.0;
        for window in &res.availability_windows {
            if window.end_at > window.start_at {
                total_window_duration += (window.end_at - window.start_at) as f32;
            }
        }

        resource_features.push(vec![capacity, window_count, total_window_duration]);
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
            let type_hash = hash_string_to_f32(&edge.edge_type);
            job_to_job_edge_features.push(vec![lag, type_hash]);
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

    TensorData {
        job_features,
        resource_features,
        job_to_job_edges,
        job_to_job_edge_features,
        job_to_resource_edges,
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::domain::{Edge, Job, Resource, Window};

    #[test]
    fn test_extract_features_translates_problem_to_rich_heterogeneous_tensor_data() {
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
                    start_time: None,
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
            ],
            edges: vec![Edge {
                from_job_id: 10,
                to_job_id: 20,
                lag: 15,
                edge_type: "sequence".to_string(),
            }],
            score_components: vec![],
        };

        let tensor_data = extract_features(&problem);

        assert_eq!(tensor_data.job_features.len(), 2);
        assert_eq!(tensor_data.resource_features.len(), 2);

        // Job 0: batch_key is None -> hash is -1.0
        assert_eq!(tensor_data.job_features[0], vec![5.0, 0.0, 100.0, -1.0]);
        // Job 1: batch_key is "HOT" -> hash is a positive float
        let hot_hash = hash_string_to_f32("HOT");
        assert_eq!(tensor_data.job_features[1], vec![8.0, -1.0, -1.0, hot_hash]);

        // Resource 0: capacity 1, 0 windows, 0 total duration
        assert_eq!(tensor_data.resource_features[0], vec![1.0, 0.0, 0.0]);
        // Resource 1: capacity 2, 2 windows, 200 total duration
        assert_eq!(tensor_data.resource_features[1], vec![2.0, 2.0, 200.0]);

        assert_eq!(tensor_data.job_to_job_edges.len(), 1);
        assert_eq!(tensor_data.job_to_job_edges[0], (0, 1));

        assert_eq!(tensor_data.job_to_job_edge_features.len(), 1);
        // Edge features: lag is 15.0, type is "sequence" hash
        let seq_hash = hash_string_to_f32("sequence");
        assert_eq!(tensor_data.job_to_job_edge_features[0], vec![15.0, seq_hash]);

        assert_eq!(tensor_data.job_to_resource_edges.len(), 2);
        assert!(tensor_data.job_to_resource_edges.contains(&(0, 0)));
        assert!(tensor_data.job_to_resource_edges.contains(&(1, 1)));
    }
}
