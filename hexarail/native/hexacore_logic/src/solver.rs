// Copyright (c) Didier Stadelmann. All rights reserved.

use crate::domain::Problem;
use crate::incremental_score::{ScoreDatabase, ScoreEngine};

const LAHC_HISTORY_SIZE: usize = 100;

#[must_use]
pub fn optimize(
    mut current_problem: Problem,
    _total_conflicts: usize,
    iterations: i32,
    guidance: Option<Vec<f32>>,
) -> Problem {
    // 1. Initialize Salsa Database with full problem state
    let mut db = ScoreDatabase::default();
    
    db.set_job_ids(current_problem.jobs.iter().map(|j| j.id).collect());
    for job in &current_problem.jobs {
        db.set_job_data(job.id, job.clone());
        db.set_job_start_time(job.id, job.start_time);
    }

    db.set_resource_ids(current_problem.resources.iter().map(|r| r.id).collect());
    for res in &current_problem.resources {
        db.set_resource_data(res.id, res.clone());
        
        // SOTA O(delta) optimization: Pre-compute which jobs use this resource
        let mut res_jobs = Vec::new();
        for job in &current_problem.jobs {
            if job.required_resources.contains(&res.id) {
                res_jobs.push(job.id);
            }
        }
        db.set_resource_jobs(res.id, res_jobs);
    }

    let edge_ids: Vec<usize> = (0..current_problem.edges.len()).collect();
    db.set_edge_ids(edge_ids.clone());
    for id in edge_ids {
        db.set_edge_data(id, current_problem.edges[id].clone());
    }

    let mut current_score = db.total_score();
    let mut best_score = current_score;
    let mut best_problem = current_problem.clone();

    // Late Acceptance Hill Climbing (LAHC) history array
    let mut fitness_array = vec![current_score; LAHC_HISTORY_SIZE];

    use rand::RngExt;
    let mut rng = rand::rng();

    // 2. Optimization Loop with LAHC and SOTA Move Selectors
    for i in 0..iterations {
        let v = (i as usize) % LAHC_HISTORY_SIZE;

        // Selection: Pick a primary job to move, guided by static GNN prior if available
        let job_idx = if let Some(ref p_vec) = guidance {
            if rng.random_bool(0.8) && p_vec.len() == current_problem.jobs.len() {
                // Stochastic Sampling (Weighted Random Choice)
                let sum: f32 = p_vec.iter().sum();
                if sum > 0.0 {
                    let mut cumulative = 0.0;
                    let target = rng.random_range(0.0..sum);
                    let mut selected = p_vec.len() - 1;
                    for (pi, &p) in p_vec.iter().enumerate() {
                        cumulative += p;
                        if cumulative >= target {
                            selected = pi;
                            break;
                        }
                    }
                    selected
                } else {
                    rng.random_range(0..current_problem.jobs.len())
                }
            } else {
                rng.random_range(0..current_problem.jobs.len())
            }
        } else {
            rng.random_range(0..current_problem.jobs.len())
        };
        
        let job_id = current_problem.jobs[job_idx].id;
        let old_time = db.job_start_time(job_id);

        // SOTA Local Search Move Selectors:
        // Instead of only doing "Earliest-Fit" (which is a Construction Heuristic),
        // we introduce a catalogue of moves to allow true exploration of the landscape.
        let move_type = rng.random_range(0..100);
        
        let mut second_job_id = None;
        let mut second_old_time = None;
        
        if move_type < 20 {
            // SWAP MOVE (20% chance)
            // Swap start times with another random job
            let target_idx = rng.random_range(0..current_problem.jobs.len());
            let target_id = current_problem.jobs[target_idx].id;
            if target_id != job_id {
                second_job_id = Some(target_id);
                second_old_time = db.job_start_time(target_id);
                
                db.set_job_start_time(job_id, second_old_time);
                db.set_job_start_time(target_id, old_time);
            }
        } else if move_type < 60 {
            // CHANGE MOVE / SHIFT (40% chance)
            // Shift the job's start time forward or backward randomly within a window
            if let Some(t) = old_time {
                // Shift by up to +/- 120 minutes
                let shift = rng.random_range(-120..120);
                let new_time = std::cmp::max(0, t + shift);
                db.set_job_start_time(job_id, Some(new_time));
            } else {
                // If unassigned, pick a completely random time to inject it into the schedule
                db.set_job_start_time(job_id, Some(rng.random_range(0..1440)));
            }
        } else {
            // EST SNAP MOVE (40% chance)
            // Original logic: Find the Earliest Start Time considering resources and precedences
            let mut topological_est = 0;
            if let Some(release) = current_problem.jobs[job_idx].release_time {
                topological_est = topological_est.max(release);
            }
            for edge in &current_problem.edges {
                if edge.to_job_id == job_id {
                    if let Some(pred_start) = db.job_start_time(edge.from_job_id) {
                        let pred_job = db.job_data(edge.from_job_id);
                        let pred_end = pred_start + pred_job.duration;
                        let required_start = match edge.edge_type.as_str() {
                            "finish_to_start" => pred_end + edge.lag,
                            "start_to_start" => pred_start + edge.lag,
                            "finish_to_finish" => pred_end + edge.lag - current_problem.jobs[job_idx].duration,
                            "start_to_finish" => pred_start + edge.lag - current_problem.jobs[job_idx].duration,
                            _ => pred_end,
                        };
                        topological_est = topological_est.max(required_start);
                    }
                }
            }
            
            let job_duration = current_problem.jobs[job_idx].duration;
            let mut est = topological_est;
            let mut found_valid_slot = false;
            let max_search_horizon = topological_est + 1440 * 7;
            
            while !found_valid_slot && est < max_search_horizon {
                let mut all_resources_free = true;
                let current_end = est + job_duration;
                for &res_id in &current_problem.jobs[job_idx].required_resources {
                    let res = db.resource_data(res_id);
                    let mut within_window = true;
                    if !res.availability_windows.is_empty() {
                        within_window = res.availability_windows.iter().any(|w| est >= w.start_at && current_end <= w.end_at);
                    }
                    if !within_window {
                        all_resources_free = false;
                        est += 1;
                        break;
                    }
                    let mut concurrent_count = 1;
                    let mut next_conflict_end = 0;
                    for &other_j_id in &db.job_ids() {
                        if other_j_id == job_id { continue; }
                        let other_job = db.job_data(other_j_id);
                        if other_job.required_resources.contains(&res_id) {
                            if let Some(other_start) = db.job_start_time(other_j_id) {
                                let other_end = other_start + other_job.duration;
                                if est < other_end && other_start < current_end {
                                    concurrent_count += 1;
                                    next_conflict_end = next_conflict_end.max(other_end);
                                }
                            }
                        }
                    }
                    if concurrent_count > res.capacity {
                        all_resources_free = false;
                        est = est.max(next_conflict_end);
                        break;
                    }
                }
                if all_resources_free { found_valid_slot = true; }
            }
            db.set_job_start_time(job_id, Some(est));
        }
        
        let neighbor_score = db.total_score();

        // LAHC Acceptance criterion
        if neighbor_score >= current_score || neighbor_score >= fitness_array[v] {
            // Accept move
            current_score = neighbor_score;
            
            // Sync the accepted move to the problem representation
            current_problem.jobs[job_idx].start_time = db.job_start_time(job_id);
            if let Some(s_id) = second_job_id {
                if let Some(s_job) = current_problem.jobs.iter_mut().find(|j| j.id == s_id) {
                    s_job.start_time = db.job_start_time(s_id);
                }
            }

            if neighbor_score > best_score {
                best_score = neighbor_score;
                best_problem = current_problem.clone();
            }
        } else {
            // Reject: Undo Move in Salsa
            db.set_job_start_time(job_id, old_time);
            if let Some(s_id) = second_job_id {
                db.set_job_start_time(s_id, second_old_time);
            }
        }

        // Update history
        if current_score > fitness_array[v] {
            fitness_array[v] = current_score;
        }

        if best_score.hard == 0 && best_score.medium == 0 {
            break;
        }
    }

    // 3. XAI: Provide final score explanation for the best solution found
    // We need to restore the Salsa state to the best problem to get its explanation
    for job in &best_problem.jobs {
        db.set_job_start_time(job.id, job.start_time);
    }
    best_problem.explanation = Some(db.score_explanation());

    best_problem
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::domain::Job;

    #[test]
    fn test_hill_climbing_assigns_jobs_with_sota_engine() {
        let problem = Problem {
            id: "sim_1".to_string(),
            resources: vec![],
            jobs: vec![Job {
                id: 1,
                duration: 10,
                required_resources: vec![],
                release_time: None,
                due_time: None,
                group_id: None,
                start_time: None,
            }],
            edges: vec![],
            score_components: vec![],
            explanation: None,
        };

        let optimized = optimize::<fn(&Problem) -> Vec<f32>>(problem, 0, 100, None);
        
        assert!(optimized.jobs[0].start_time.is_some());
    }
}
