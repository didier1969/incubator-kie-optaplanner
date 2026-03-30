// Copyright (c) Didier Stadelmann. All rights reserved.

use crate::domain::Problem;

const UNASSIGNED_JOB_PENALTY: i64 = 100;
const CONFLICT_PENALTY: i64 = 1_000;

#[must_use]
pub fn calculate_score(problem: &Problem) -> i64 {
    let mut score = 0;

    // Constraint 1: Unassigned Job Penalty
    for job in &problem.jobs {
        if job.start_time.is_none() {
            score -= UNASSIGNED_JOB_PENALTY;
        }
    }

    score
}

#[must_use]
pub fn calculate_score_with_conflicts(problem: &Problem, total_conflicts: usize) -> i64 {
    let mut score = calculate_score(problem);

    #[allow(clippy::cast_possible_wrap)]
    {
        score -= (total_conflicts as i64) * CONFLICT_PENALTY;
    }

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
        let score = calculate_score(&problem);
        assert_eq!(score, -100); 
    }

    #[test]
    fn test_conflict_penalty_is_added_without_topology_dependency() {
        let problem = Problem { id: "1".to_string(), resources: vec![], jobs: vec![] };
        let score = calculate_score_with_conflicts(&problem, 2);
        assert_eq!(score, -2_000);
    }
}
