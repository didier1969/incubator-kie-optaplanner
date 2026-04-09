// Copyright (c) Didier Stadelmann. All rights reserved.

use crate::domain::Problem;

#[derive(Debug, Clone, PartialEq)]
pub struct TensorData {
    pub job_features: Vec<Vec<f32>>,
    pub resource_features: Vec<Vec<f32>>,
    pub job_to_job_edges: Vec<(usize, usize)>,
    pub job_to_resource_edges: Vec<(usize, usize)>,
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
        let has_batch_key = if job.batch_key.is_some() { 1.0 } else { 0.0 };

        job_features.push(vec![duration, release_time, due_time, has_batch_key]);
    }

    let mut res_to_idx = HashMap::new();
    let mut resource_features = Vec::with_capacity(problem.resources.len());

    for (idx, res) in problem.resources.iter().enumerate() {
        res_to_idx.insert(res.id, idx);
        resource_features.push(vec![res.capacity as f32]);
    }

    let mut job_to_job_edges = Vec::with_capacity(problem.edges.len());
    for edge in &problem.edges {
        if let (Some(&from_idx), Some(&to_idx)) = (
            job_to_idx.get(&edge.from_job_id),
            job_to_idx.get(&edge.to_job_id),
        ) {
            job_to_job_edges.push((from_idx, to_idx));
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
        job_to_resource_edges,
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::domain::{Edge, Job, Resource};

    #[test]
    fn test_extract_features_translates_problem_to_heterogeneous_tensor_data() {
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
                    availability_windows: vec![],
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
                lag: 0,
                edge_type: "sequence".to_string(),
            }],
            score_components: vec![],
        };

        let tensor_data = extract_features(&problem);

        assert_eq!(tensor_data.job_features.len(), 2);
        assert_eq!(tensor_data.resource_features.len(), 2);

        // Job 0 features: [duration: 5.0, release_time: 0.0, due_time: 100.0, has_batch_key: 0.0]
        assert_eq!(tensor_data.job_features[0], vec![5.0, 0.0, 100.0, 0.0]);
        // Job 1 features: [duration: 8.0, release_time: -1.0, due_time: -1.0, has_batch_key: 1.0]
        assert_eq!(tensor_data.job_features[1], vec![8.0, -1.0, -1.0, 1.0]);

        // Resource 0 features: [capacity: 1.0]
        assert_eq!(tensor_data.resource_features[0], vec![1.0]);
        // Resource 1 features: [capacity: 2.0]
        assert_eq!(tensor_data.resource_features[1], vec![2.0]);

        assert_eq!(tensor_data.job_to_job_edges.len(), 1);
        // Edge maps job 10 to 20 -> internal indices 0 to 1
        assert_eq!(tensor_data.job_to_job_edges[0], (0, 1));

        assert_eq!(tensor_data.job_to_resource_edges.len(), 2);
        // Job 10 (idx 0) requires Resource 1 (idx 0)
        assert!(tensor_data.job_to_resource_edges.contains(&(0, 0)));
        // Job 20 (idx 1) requires Resource 2 (idx 1)
        assert!(tensor_data.job_to_resource_edges.contains(&(1, 1)));
    }
}
