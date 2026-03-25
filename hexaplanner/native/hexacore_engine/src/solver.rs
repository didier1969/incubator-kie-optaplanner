use crate::domain::Problem;
use crate::score::calculate_score;
use crate::incremental_score::{ScoreDatabase, ScoreEngine};
use crate::topology::NetworkManager;

#[must_use]
pub fn optimize(mut current_problem: Problem, manager: &NetworkManager, iterations: i32) -> Problem {
    // Initialize Salsa Database
    let mut db = ScoreDatabase::default();
    
    // Set all initial inputs safely
    db.set_job_ids(current_problem.jobs.iter().map(|j| j.id).collect());
    for job in &current_problem.jobs {
        db.set_job_assigned(job.id, job.start_time.is_some());
    }

    // We compute the heavy STIG collisions via the naive approach for now
    // and pass it as the "base score" to the incremental engine.
    let base_conflict_score = calculate_score(&current_problem, manager) - db.calculate_penalties();
    
    db.set_get_base_score(base_conflict_score);

    let mut current_score = db.get_total_score();

    for i in 0..iterations {
        // Create a neighbor (mutation)
        let mut neighbor = current_problem.clone();
        
        // Very basic mutation: assign a start time to the first unassigned job
        if let Some(job) = neighbor.jobs.iter_mut().find(|j| j.start_time.is_none()) {
            job.start_time = Some(i64::from(i) * 10);
            
            // Sync mutation to Salsa DB incrementally
            db.set_job_assigned(job.id, true);
        }

        // Now we only pull the score incrementally from Salsa!
        let neighbor_score = db.get_total_score();

        // Hill Climbing: Accept if strictly better
        if neighbor_score > current_score {
            current_problem = neighbor;
            current_score = neighbor_score;
        } else {
            // Revert the DB change if move is rejected
            // Find the job that was changed (simplified here)
            if let Some(job) = current_problem.jobs.iter().find(|j| j.start_time.is_none()) {
                db.set_job_assigned(job.id, false);
            }
        }

        // Fast exit if we reached perfect score (0 penalties)
        if current_score == 0 {
            break;
        }
    }

    current_problem
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::domain::Job;
    use crate::score;

    #[test]
    fn test_hill_climbing_assigns_jobs_with_salsa() {
        let problem = Problem {
            id: "sim_1".to_string(),
            resources: vec![],
            jobs: vec![Job { id: 1, duration: 10, required_resources: vec![], start_time: None }],
        };
        let manager = NetworkManager::new();

        // Initially score is -100
        assert_eq!(score::calculate_score(&problem, &manager), -100);

        let optimized = optimize(problem, &manager, 10);
        
        // After optimization, the job should have a start_time, making score 0
        assert_eq!(score::calculate_score(&optimized, &manager), 0);
        assert!(optimized.jobs[0].start_time.is_some());
    }
}
