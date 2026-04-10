// Copyright (c) Didier Stadelmann. All rights reserved.

use crate::domain::Problem;
use crate::incremental_score::{ScoreDatabase, ScoreEngine};

const LAHC_HISTORY_SIZE: usize = 100;

#[must_use]
pub fn optimize<F>(
    mut current_problem: Problem,
    _total_conflicts: usize,
    iterations: i32,
    mut guidance_fn: Option<F>,
) -> Problem
where
    F: FnMut(&Problem) -> Vec<f32>,
{
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

    // 2. Optimization Loop with LAHC and In-Place Mutation
    for i in 0..iterations {
        let v = (i as usize) % LAHC_HISTORY_SIZE;

        // Dynamic State Evaluation: Call GNN inside the loop if available
        let probs = if let Some(ref mut g_fn) = guidance_fn {
            let p = g_fn(&current_problem);
            if p.len() == current_problem.jobs.len() { Some(p) } else { None }
        } else {
            None
        };

        // Selection: Pick a job to move, guided by GNN if available (Epsilon-Greedy)
        let job_idx = if let Some(ref p_vec) = probs {
            if rng.random_bool(0.8) {
                // SOTA: Stochastic Sampling (Weighted Random Choice) instead of greedy Argmax
                // Use Softmax probabilities to pick the next job
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
        
        // Random move logic (In a more advanced SOTA version, this would be a guided selector)
        let new_time = Some(rng.random_range(0..1440));
        
        // Apply Move
        db.set_job_start_time(job_id, new_time);
        let neighbor_score = db.total_score();

        // LAHC Acceptance criterion: Accept if better than or equal to current, 
        // OR better than or equal to the score in history L steps ago.
        if neighbor_score >= current_score || neighbor_score >= fitness_array[v] {
            // Accept move
            current_score = neighbor_score;
            current_problem.jobs[job_idx].start_time = new_time;

            if neighbor_score > best_score {
                best_score = neighbor_score;
                // Only clone when we find a new global best
                best_problem = current_problem.clone();
            }
        } else {
            // Reject: Undo Move in Salsa
            db.set_job_start_time(job_id, old_time);
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
                batch_key: None,
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
