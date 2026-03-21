use crate::domain::Problem;
use crate::score::calculate_score;

#[must_use]
pub fn optimize(mut current_problem: Problem, iterations: i32) -> Problem {
    let mut current_score = calculate_score(&current_problem);

    for i in 0..iterations {
        // Create a neighbor (mutation)
        let mut neighbor = current_problem.clone();
        
        // Very basic mutation: assign a dummy start time to the first unassigned job
        if let Some(job) = neighbor.jobs.iter_mut().find(|j| j.start_time.is_none()) {
            job.start_time = Some(i64::from(i) * 10);
        }

        let neighbor_score = calculate_score(&neighbor);

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

        // Initially score is -100
        assert_eq!(score::calculate_score(&problem), -100);

        let optimized = optimize(problem, 10);
        
        // After optimization, the job should have a start_time, making score 0
        assert_eq!(score::calculate_score(&optimized), 0);
        assert!(optimized.jobs[0].start_time.is_some());
    }
}