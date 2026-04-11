// Copyright (c) Didier Stadelmann. All rights reserved.

use crate::domain::Problem;
use std::collections::HashMap;
use std::sync::RwLock;
use serde::{Serialize, Deserialize, Serializer, Deserializer};

#[derive(Debug, Clone, PartialEq, rustler::NifMap)]
pub struct TensorData {
    pub job_features: Vec<Vec<f32>>,
    pub resource_features: Vec<Vec<f32>>,
    pub job_to_job_edge_src: Vec<usize>,
    pub job_to_job_edge_dst: Vec<usize>,
    pub job_to_job_edge_features: Vec<Vec<f32>>,
    pub job_to_resource_edge_src: Vec<usize>,
    pub job_to_resource_edge_dst: Vec<usize>,
    pub global_features: Vec<f32>,
    pub scalars: Vec<f32>,
}

pub const TIME_BUCKETS: usize = 24;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct StrictDictionaryData {
    pub mapping: HashMap<String, usize>,
    pub frozen: bool,
}

impl Default for StrictDictionaryData {
    fn default() -> Self {
        let mut mapping = HashMap::new();
        mapping.insert("<UNK>".to_string(), 0); // ID 0 is always Unknown
        Self {
            mapping,
            frozen: false,
        }
    }
}

#[derive(Debug, Default)]
pub struct StrictDictionary {
    inner: RwLock<StrictDictionaryData>,
}

impl Serialize for StrictDictionary {
    fn serialize<S>(&self, serializer: S) -> Result<S::Ok, S::Error>
    where
        S: Serializer,
    {
        let inner = self.inner.read().unwrap();
        inner.serialize(serializer)
    }
}

impl<'de> Deserialize<'de> for StrictDictionary {
    fn deserialize<D>(deserializer: D) -> Result<Self, D::Error>
    where
        D: Deserializer<'de>,
    {
        let inner = StrictDictionaryData::deserialize(deserializer)?;
        Ok(StrictDictionary {
            inner: RwLock::new(inner),
        })
    }
}

impl StrictDictionary {
    /// # Panics
    ///
    /// Panics if the internal `RwLock` is poisoned.
    pub fn get_or_insert(&self, key: &str) -> usize {
        if let Some(&id) = self.inner.read().unwrap().mapping.get(key) {
            return id;
        }
        let mut inner = self.inner.write().unwrap();
        if inner.frozen {
            return 0;
        }
        if let Some(&id) = inner.mapping.get(key) {
            return id;
        }
        let next_id = inner.mapping.len();
        inner.mapping.insert(key.to_string(), next_id);
        next_id
    }

    /// # Panics
    ///
    /// Panics if the internal `RwLock` is poisoned.
    pub fn freeze(&self) {
        self.inner.write().unwrap().frozen = true;
    }

    /// # Panics
    ///
    /// Panics if the internal `RwLock` is poisoned.
    #[must_use]
    pub fn len(&self) -> usize {
        self.inner.read().unwrap().mapping.len()
    }

    /// # Panics
    ///
    /// Panics if the internal `RwLock` is poisoned.
    #[must_use]
    pub fn is_empty(&self) -> bool {
        self.len() == 0
    }
}

pub const MAX_SCORE_COMPONENTS: usize = 16;

#[allow(
    clippy::cast_precision_loss,
    clippy::cast_possible_truncation,
    clippy::cast_sign_loss,
    clippy::too_many_lines,
    clippy::float_cmp
)]
#[derive(Debug, Default, Serialize, Deserialize)]
pub struct FeatureEncoder {
    pub group_id_dict: StrictDictionary,
    pub edge_type_dict: StrictDictionary,
    pub resource_name_dict: StrictDictionary,
    pub score_name_dict: StrictDictionary,
}

impl FeatureEncoder {
    #[must_use]
    pub fn new() -> Self {
        Self::default()
    }
    
    pub fn freeze_vocabularies(&self) {
        self.group_id_dict.freeze();
        self.edge_type_dict.freeze();
        self.resource_name_dict.freeze();
        self.score_name_dict.freeze();
    }

    #[must_use]
    pub fn export_json(&self) -> String {
        serde_json::to_string(self).unwrap_or_else(|_| "{}".to_string())
    }

    /// # Errors
    ///
    /// Returns an error if the JSON string cannot be parsed.
    #[allow(
        clippy::cast_precision_loss,
        clippy::cast_possible_truncation,
        clippy::cast_sign_loss,
        clippy::too_many_lines,
        clippy::float_cmp
    )]
    pub fn import_json(json: &str) -> Result<Self, String> {
        serde_json::from_str(json).map_err(|e| e.to_string())
    }

    /// # Errors
    ///
    /// Returns an error if the number of score components exceeds `MAX_SCORE_COMPONENTS`.
    #[allow(
        clippy::cast_precision_loss,
        clippy::cast_possible_truncation,
        clippy::cast_sign_loss,
        clippy::too_many_lines,
        clippy::float_cmp
    )]
    pub fn encode(&self, problem: &Problem, current_time: f32) -> Result<TensorData, String> {
        fn get_remaining_ops(idx: usize, adj: &[Vec<usize>], memo: &mut [Option<usize>]) -> usize {
            if let Some(val) = memo[idx] {
                return val;
            }
            let mut max_child_ops = 0;
            for &child in &adj[idx] {
                max_child_ops = max_child_ops.max(get_remaining_ops(child, adj, memo) + 1);
            }
            memo[idx] = Some(max_child_ops);
            max_child_ops
        }

        let sum_durations: i64 = problem.jobs.iter().map(|j| j.duration).sum();
        let sum_lags: i64 = problem.edges.iter().map(|e| e.lag).sum();
        let theoretical_worst_case = (sum_durations + sum_lags) as f32;

        let mut max_time = theoretical_worst_case.max(current_time).max(1.0_f32);
        for job in &problem.jobs {
            if let Some(due) = job.due_time {
                if due as f32 > max_time { max_time = due as f32; }
            }
            if let Some(release) = job.release_time {
                let end = release + job.duration;
                if end as f32 > max_time { max_time = end as f32; }
            }
            if let Some(start) = job.start_time {
                let end = start + job.duration;
                if end as f32 > max_time { max_time = end as f32; }
            }
        }
        
        let mut max_capacity = 1.0_f32;
        for res in &problem.resources {
            let cap = res.capacity as f32;
            if cap > max_capacity { max_capacity = cap; }
        }
        
        let bucket_size = max_time / (TIME_BUCKETS as f32);

        // Precompute DAG topological features: remaining operations
        let mut adj = vec![vec![]; problem.jobs.len()];
        let mut job_to_idx = HashMap::new();
        for (idx, job) in problem.jobs.iter().enumerate() {
            job_to_idx.insert(job.id, idx);
        }
        for edge in &problem.edges {
            if let (Some(&from), Some(&to)) = (job_to_idx.get(&edge.from_job_id), job_to_idx.get(&edge.to_job_id)) {
                adj[from].push(to);
            }
        }

        let mut memo = vec![None; problem.jobs.len()];
        let mut remaining_ops = vec![0usize; problem.jobs.len()];
        for (i, ops) in remaining_ops.iter_mut().enumerate().take(problem.jobs.len()) {
            *ops = get_remaining_ops(i, &adj, &mut memo);
        }

        // Pre-pass to populate dictionaries
        for job in &problem.jobs {
            if let Some(key) = &job.group_id {
                self.group_id_dict.get_or_insert(key);
            }
        }
        for res in &problem.resources {
            self.resource_name_dict.get_or_insert(&res.name);
        }
        for edge in &problem.edges {
            self.edge_type_dict.get_or_insert(&edge.edge_type);
        }

        let mut job_features = Vec::with_capacity(problem.jobs.len());
        let group_id_dict_size = self.group_id_dict.len() as f32;
        for (idx, job) in problem.jobs.iter().enumerate() {
            let duration = (job.duration as f32) / max_time;
            let release_time = job.release_time.map_or(0.0, |v| (v as f32) / max_time);
            let due_time = job.due_time.map_or(1.0, |v| (v as f32) / max_time);
            let start_time = job.start_time.map_or(0.0, |v| (v as f32) / max_time);
            let is_scheduled = if job.start_time.is_some() { 1.0 } else { 0.0 };
            
            let group_id_id = match &job.group_id {
                Some(key) => {
                    let id = self.group_id_dict.get_or_insert(key) as f32;
                    id / (group_id_dict_size + 1.0).max(1.0)
                },
                None => 0.0,
            };

            // SOTA Features
            let wait_time = (current_time - job.release_time.unwrap_or(0) as f32).max(0.0) / max_time;
            let remaining_time_to_due = job.due_time.map_or(1.0, |due| (due as f32 - current_time).max(0.0) / max_time);
            let rem_ops = (remaining_ops[idx] as f32) / (problem.jobs.len() as f32).max(1.0);

            job_features.push(vec![
                duration, release_time, due_time, start_time, is_scheduled,
                group_id_id, wait_time, remaining_time_to_due, rem_ops
            ]);
        }

        let mut res_to_idx = HashMap::new();
        for (idx, res) in problem.resources.iter().enumerate() {
            res_to_idx.insert(res.id, idx);
        }

        // Machine Occupancy State (SOTA)
        let mut resource_scheduled_duration = vec![0.0f32; problem.resources.len()];
        let mut resource_is_busy = vec![0.0f32; problem.resources.len()];
        let mut resource_current_task_end = vec![0.0f32; problem.resources.len()];

        for job in &problem.jobs {
            if let Some(start) = job.start_time {
                let start_f = start as f32;
                let duration_f = job.duration as f32;
                let end_f = start_f + duration_f;
                
                for res_id in &job.required_resources {
                    if let Some(&res_idx) = res_to_idx.get(res_id) {
                        // Sum of durations of tasks that have at least started (scheduled or in-progress)
                        if start_f < current_time {
                            resource_scheduled_duration[res_idx] += duration_f;
                        }

                        // Check if any task is running at current_time
                        if current_time >= start_f && current_time < end_f {
                            resource_is_busy[res_idx] = 1.0;
                            resource_current_task_end[res_idx] = resource_current_task_end[res_idx].max(end_f);
                        }
                    }
                }
            }
        }

        let mut resource_features = Vec::with_capacity(problem.resources.len());
        let resource_name_dict_size = self.resource_name_dict.len() as f32;
        for (idx, res) in problem.resources.iter().enumerate() {
            let capacity = (res.capacity as f32) / max_capacity; 
            let type_id = (self.resource_name_dict.get_or_insert(&res.name) as f32) / (resource_name_dict_size + 1.0).max(1.0);
            
            // SOTA Dynamic Occupancy Features
            let utilization_ratio = if current_time > 0.0 {
                (resource_scheduled_duration[idx] / (res.capacity as f32 * current_time)).min(1.0)
            } else {
                0.0
            };
            let is_busy = resource_is_busy[idx];
            let remaining_busy_time = if is_busy > 0.5 {
                ((resource_current_task_end[idx] - current_time) / max_time).clamp(0.0, 1.0)
            } else {
                0.0
            };

            let mut res_feat = vec![capacity, type_id, utilization_ratio, is_busy, remaining_busy_time];
            
            let mut time_grid = vec![1.0; TIME_BUCKETS];
            if bucket_size > 0.0 {
                for window in &res.availability_windows {
                    let start_f = window.start_at as f32;
                    let end_f = window.end_at as f32;
                    let start_bucket = (start_f / bucket_size).floor() as usize;
                    let end_bucket = (end_f / bucket_size).floor() as usize;
                    for (b, time_grid_b) in time_grid.iter_mut().enumerate().take(end_bucket + 1).skip(start_bucket) {
                        if b < TIME_BUCKETS {
                            let bucket_start = (b as f32) * bucket_size;
                            let bucket_end = bucket_start + bucket_size;
                            let overlap_start = start_f.max(bucket_start);
                            let overlap_end = end_f.min(bucket_end);
                            if overlap_end > overlap_start {
                                let unavailable_fraction = (overlap_end - overlap_start) / bucket_size;
                                *time_grid_b = (*time_grid_b - unavailable_fraction).max(0.0);
                            }
                        }
                    }
                }
            }
            res_feat.extend(time_grid);
            resource_features.push(res_feat);
        }

        // COO Format for edges
        let mut job_to_job_edge_src = Vec::with_capacity(problem.edges.len());
        let mut job_to_job_edge_dst = Vec::with_capacity(problem.edges.len());
        let mut job_to_job_edge_features = Vec::with_capacity(problem.edges.len());
        let edge_type_dict_size = self.edge_type_dict.len() as f32;
        for edge in &problem.edges {
            if let (Some(&from), Some(&to)) = (job_to_idx.get(&edge.from_job_id), job_to_idx.get(&edge.to_job_id)) {
                job_to_job_edge_src.push(from);
                job_to_job_edge_dst.push(to);
                let lag = (edge.lag as f32) / max_time;
                let type_id = (self.edge_type_dict.get_or_insert(&edge.edge_type) as f32) / (edge_type_dict_size + 1.0).max(1.0);
                job_to_job_edge_features.push(vec![lag, type_id]);
            }
        }

        let mut job_to_resource_edge_src = Vec::new();
        let mut job_to_resource_edge_dst = Vec::new();
        for (job_idx, job) in problem.jobs.iter().enumerate() {
            for req_res_id in &job.required_resources {
                if let Some(&res_idx) = res_to_idx.get(req_res_id) {
                    job_to_resource_edge_src.push(job_idx);
                    job_to_resource_edge_dst.push(res_idx);
                }
            }
        }

        // Global features: [t_normalized, scores...]
        let mut global_features = Vec::with_capacity(MAX_SCORE_COMPONENTS + 1);
        global_features.push(current_time / max_time);
        
        let mut scores = vec![0.5; MAX_SCORE_COMPONENTS]; // 0.5 is sigmoid(0), neutral
        for comp in &problem.score_components {
            let pos = self.score_name_dict.get_or_insert(&comp.name);
            if pos >= MAX_SCORE_COMPONENTS {
                return Err(format!("Exceeded MAX_SCORE_COMPONENTS limit of {} with metric '{}'", MAX_SCORE_COMPONENTS, comp.name));
            }
            let v = comp.value as f32;
            let log_v = v.signum() * (v.abs() + 1.0).ln();
            // Sigmoid normalization to [0, 1]
            scores[pos] = 1.0 / (1.0 + (-log_v).exp());
        }
        global_features.extend(scores);

        Ok(TensorData {
            job_features,
            resource_features,
            job_to_job_edge_src,
            job_to_job_edge_dst,
            job_to_job_edge_features,
            job_to_resource_edge_src,
            job_to_resource_edge_dst,
            global_features,
            scalars: vec![max_time, max_capacity],
        })
    }
}

#[cfg(test)]
#[allow(clippy::float_cmp)]
mod tests {
    use super::*;
    use crate::domain::{Edge, Job, Resource, ScoreComponent, Window};

    #[test]
    fn test_extract_features_translates_problem_to_normalized_markov_state_tensor() {
        let problem = Problem {
            id: "p1".to_string(),
            resources: vec![
                Resource { id: 1, name: "M1".to_string(), capacity: 1, availability_windows: vec![] },
                Resource {
                    id: 2, name: "M2".to_string(), capacity: 2,
                    availability_windows: vec![Window { start_at: 0, end_at: 10 }],
                },
            ],
            jobs: vec![
                Job { id: 10, duration: 60, required_resources: vec![1], release_time: Some(0), due_time: Some(120), start_time: Some(60), group_id: None },
                Job { id: 20, duration: 30, required_resources: vec![2], release_time: None, due_time: None, start_time: None, group_id: Some("HOT".to_string()) },
                Job { id: 30, duration: 30, required_resources: vec![2], release_time: None, due_time: None, start_time: None, group_id: Some("HOT".to_string()) },
            ],
            edges: vec![Edge { from_job_id: 10, to_job_id: 20, lag: 12, edge_type: "sequence".to_string() }],
            setup_transitions: vec![],
            score_components: vec![
                ScoreComponent { name: "tardiness".to_string(), value: 500 },
                ScoreComponent { name: "setup".to_string(), value: 20 },
                ScoreComponent { name: "unknown_metric".to_string(), value: 999 },
            ],
            explanation: None,
        };

        let encoder = FeatureEncoder::new();
        let tensor = encoder.encode(&problem, 60.0).unwrap();

        assert_eq!(tensor.job_features.len(), 3);
        assert_eq!(tensor.job_features[0].len(), 9);
        assert_eq!(tensor.resource_features.len(), 2);
        assert_eq!(tensor.resource_features[0].len(), 29); // 5 + 24
        assert_eq!(tensor.global_features.len(), 17); // 1 + 16
        assert_eq!(tensor.scalars.len(), 2);
        assert!((tensor.scalars[0] - 132.0).abs() < 0.01);

        // Job 0: remaining_ops = 1 (job 20 follows), so 1/3 = 0.333
        assert!((tensor.job_features[0][8] - 0.3333).abs() < 0.01);
        // Wait time: (60 - 0) / 132 = 0.4545
        assert!((tensor.job_features[0][6] - 0.4545).abs() < 0.01);

        // Machine occupancy: M1 (id 1) has job 10 (start 60, dur 60). At t=60, it's busy.
        // is_busy (idx 3) should be 1.0
        assert_eq!(tensor.resource_features[0][3], 1.0);
        // remaining_busy_time (idx 4): (120 - 60) / 132 = 0.4545
        assert!((tensor.resource_features[0][4] - 0.4545).abs() < 0.01);

        assert_eq!(tensor.job_to_job_edge_src, vec![0]);
        assert_eq!(tensor.job_to_job_edge_dst, vec![1]);
        assert_eq!(tensor.job_to_resource_edge_src, vec![0, 1, 2]);
        assert_eq!(tensor.job_to_resource_edge_dst, vec![0, 1, 1]);

        encoder.freeze_vocabularies();
        let problem_2 = Problem {
            id: "p2".to_string(),
            resources: vec![],
            jobs: vec![Job { id: 40, duration: 1, required_resources: vec![], release_time: None, due_time: None, group_id: Some("COLD".to_string()), start_time: None }],
            edges: vec![],
            setup_transitions: vec![],
            score_components: vec![],
            explanation: None,
        };
        let tensor_2 = encoder.encode(&problem_2, 0.0).unwrap();
        // group_id_id is at index 5. HOT was 0 (mapped to 0/<size+1>), COLD is now mapped to 0 as it's frozen?
        // Wait, COLD was added after freeze, so it should be UNK (0).
        assert_eq!(tensor_2.job_features[0][5], 0.0); 
    }
}
