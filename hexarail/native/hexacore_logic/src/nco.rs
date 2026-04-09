// Copyright (c) Didier Stadelmann. All rights reserved.

use crate::domain::Problem;

#[derive(Debug, Clone, PartialEq)]
pub struct TensorData {
    pub node_features: Vec<Vec<f32>>,
    pub edge_index: Vec<(usize, usize)>,
}

#[must_use]
pub fn extract_features(problem: &Problem) -> TensorData {
    use std::collections::HashMap;

    let mut job_to_idx = HashMap::new();
    let mut node_features = Vec::with_capacity(problem.jobs.len());

    for (idx, job) in problem.jobs.iter().enumerate() {
        job_to_idx.insert(job.id, idx);

        let duration = job.duration as f32;
        let req_res_count = job.required_resources.len() as f32;
        let release_time = job.release_time.map_or(-1.0, |v| v as f32);
        let due_time = job.due_time.map_or(-1.0, |v| v as f32);

        node_features.push(vec![duration, req_res_count, release_time, due_time]);
    }

    let mut edge_index = Vec::with_capacity(problem.edges.len());
    for edge in &problem.edges {
        if let (Some(&from_idx), Some(&to_idx)) = (
            job_to_idx.get(&edge.from_job_id),
            job_to_idx.get(&edge.to_job_id),
        ) {
            edge_index.push((from_idx, to_idx));
        }
    }

    TensorData {
        node_features,
        edge_index,
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::domain::{Edge, Job};

    #[test]
    fn test_extract_features_translates_problem_to_tensor_data() {
        let problem = Problem {
            id: "p1".to_string(),
            resources: vec![],
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
                    batch_key: None,
                    start_time: None,
                },
            ],
            edges: vec![Edge {
                from_job_id: 10,
                to_job_id: 20,
                lag: 0,
                edge_type: "sequence".to_string(),
            }],
            score_components: vec![],
        };

        let tensor_data = extract_features(&problem);

        assert_eq!(tensor_data.node_features.len(), 2);
        // Node 0 features: [duration: 5.0, req_res_count: 1.0, release_time: 0.0, due_time: 100.0]
        assert_eq!(tensor_data.node_features[0], vec![5.0, 1.0, 0.0, 100.0]);
        // Node 1 features: [duration: 8.0, req_res_count: 1.0, release_time: -1.0, due_time: -1.0] (defaults for None)
        assert_eq!(tensor_data.node_features[1], vec![8.0, 1.0, -1.0, -1.0]);

        assert_eq!(tensor_data.edge_index.len(), 1);
        // Edge maps job 10 to 20 -> internal indices 0 to 1
        assert_eq!(tensor_data.edge_index[0], (0, 1));
    }
}
