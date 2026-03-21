use crate::domain::Problem;

#[must_use]
pub fn calculate_score(problem: &Problem) -> i64 {
    let mut score = 0;

    // Constraint 1: Unassigned Job Penalty
    for job in &problem.jobs {
        if job.start_time.is_none() {
            score -= 100;
        }
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
        assert_eq!(score, -100); // Hard penalty for unassigned jobs
    }
}