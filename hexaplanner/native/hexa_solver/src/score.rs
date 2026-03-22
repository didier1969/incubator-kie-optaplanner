use crate::domain::Problem;
use crate::topology::NetworkManager;

#[must_use]
pub fn calculate_score(problem: &Problem, manager: &NetworkManager) -> i64 {
    let mut score = 0;

    // Constraint 1: Unassigned Job Penalty
    for job in &problem.jobs {
        if job.start_time.is_none() {
            score -= 100;
        }
    }

    // Constraint 2: Spatio-Temporal Conflicts (STIG)
    // Absolute fidelity: every physical collision is heavily penalized
    let conflict_summary = manager.detect_conflicts();
    score -= (conflict_summary.total_conflicts as i64) * 1000;

    score
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::domain::Job;

    #[test]
    fn test_unassigned_job_penalty() {
        let j1 = Job { id: 1, duration: 10, required_resources: vec![], start_time: None }; // Unassigned
        let problem = Problem { id: "1".to_string(), resources: vec![], jobs: vec![j1] };
        let manager = NetworkManager::new();
        let score = calculate_score(&problem, &manager);
        assert_eq!(score, -100); 
    }
}