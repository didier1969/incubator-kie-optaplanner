use crate::domain::Problem;
use crate::score::calculate_score;
use crate::incremental_score::{ScoreDatabase, ScoreEngine};
use crate::topology::NetworkManager;

#[must_use]
pub fn optimize(mut current_problem: Problem, manager: &NetworkManager, iterations: i32) -> Problem {
    let mut current_score = calculate_score(&current_problem, manager);
    
    // Initialize Salsa Database
    let mut db = ScoreDatabase::default();
    db.set_get_base_score(0);
    db.set_job_ids(current_problem.jobs.iter().map(|j| j.id).collect());
    for job in &current_problem.jobs {
        db.set_job_assigned(job.id, job.start_time.is_some());
    }

    for i in 0..iterations {
        // Create a neighbor (mutation)
        let mut neighbor = current_problem.clone();
        
        // Very basic mutation: assign a start time to the first unassigned job
        if let Some(job) = neighbor.jobs.iter_mut().find(|j| j.start_time.is_none()) {
            job.start_time = Some(i64::from(i) * 10);
            
            // Sync mutation to Salsa DB
            db.set_job_assigned(job.id, true);
        }

        // We still use calculate_score for the core loop logic to keep tests green 
        // while we transition fully to Salsa. We compute salsa score alongside it.
        let neighbor_score = calculate_score(&neighbor, manager);
        let _salsa_score = db.get_total_score();

        // Hill Climbing: Accept if strictly better
        if neighbor_score > current_score {
            current_problem = neighbor;
            current_score = neighbor_score;
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
    fn test_hill_climbing_assigns_jobs() {
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
