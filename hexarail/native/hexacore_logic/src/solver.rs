// Copyright (c) Didier Stadelmann. All rights reserved.

use crate::domain::Problem;
use crate::incremental_score::{ScoreDatabase, ScoreEngine};

#[must_use]
pub fn optimize(mut current_problem: Problem, total_conflicts: usize, iterations: i32) -> Problem {
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

    #[allow(clippy::cast_possible_wrap)]
    let extra_score = crate::domain::HardMediumSoftScore::new(-(total_conflicts as i64) * 10, 0, 0);
    db.set_extra_conflict_score(extra_score);

    let mut current_score = db.total_score();

    use rand::RngExt;
    let mut rng = rand::rng();

    // 2. Optimization Loop with In-Place Mutation and Undo-Move (O(delta))
    for _i in 0..iterations {
        // Selection: Pick a job to move
        let job_idx = rng.random_range(0..current_problem.jobs.len());
        let job_id = current_problem.jobs[job_idx].id;
        let old_time = db.job_start_time(job_id);
        
        // Random move logic (In a more advanced SOTA version, this would be a guided selector)
        let new_time = Some(rng.random_range(0..1440));
        
        // Apply Move
        db.set_job_start_time(job_id, new_time);
        let neighbor_score = db.total_score();

        // Hill Climbing / Late Acceptance logic
        if neighbor_score >= current_score {
            current_score = neighbor_score;
            current_problem.jobs[job_idx].start_time = new_time;
        } else {
            // Undo Move: Restore state in Salsa (O(1) logic change)
            db.set_job_start_time(job_id, old_time);
        }

        if current_score.hard == 0 && current_score.medium == 0 {
            break;
        }
    }

    // 3. XAI: Provide final score explanation
    current_problem.explanation = Some(db.score_explanation());

    current_problem
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
        };

        let optimized = optimize(problem, 0, 100);
        
        assert!(optimized.jobs[0].start_time.is_some());
    }
}
