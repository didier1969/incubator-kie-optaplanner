// Copyright (c) Didier Stadelmann. All rights reserved.

use crate::domain::{HardMediumSoftScore, Problem};

const UNASSIGNED_JOB_PENALTY: HardMediumSoftScore = HardMediumSoftScore { hard: 0, medium: -1, soft: 0 };
const RELEASE_VIOLATION_PENALTY: HardMediumSoftScore = HardMediumSoftScore { hard: 0, medium: 0, soft: -150 };
const DUE_DATE_VIOLATION_PENALTY: HardMediumSoftScore = HardMediumSoftScore { hard: 0, medium: 0, soft: -200 };
const PRECEDENCE_VIOLATION_PENALTY: HardMediumSoftScore = HardMediumSoftScore { hard: -1, medium: 0, soft: 0 };
const AVAILABILITY_VIOLATION_PENALTY: HardMediumSoftScore = HardMediumSoftScore { hard: -1, medium: 0, soft: 0 };
const CONFLICT_PENALTY: HardMediumSoftScore = HardMediumSoftScore { hard: -10, medium: 0, soft: 0 };

fn job_interval(job: &crate::domain::Job) -> Option<(i64, i64)> {
    job.start_time.map(|start_time| (start_time, start_time + job.duration))
}

fn interval_within_any_window(
    interval_start: i64,
    interval_end: i64,
    windows: &[crate::domain::Window],
) -> bool {
    windows.iter().any(|window| {
        interval_start >= window.start_at && interval_end <= window.end_at
    })
}

#[must_use]
pub fn calculate_score(problem: &Problem) -> HardMediumSoftScore {
    let mut score = HardMediumSoftScore::zero();

    // Constraint 1: Unassigned job penalty.
    for job in &problem.jobs {
        if job.start_time.is_none() {
            score += UNASSIGNED_JOB_PENALTY;
        }
    }

    // Constraint 2: Generic release and due-date violations.
    for job in &problem.jobs {
        if let Some((interval_start, interval_end)) = job_interval(job) {
            if job.release_time.is_some_and(|release_time| interval_start < release_time) {
                score += RELEASE_VIOLATION_PENALTY;
            }

            if job.due_time.is_some_and(|due_time| interval_end > due_time) {
                score += DUE_DATE_VIOLATION_PENALTY;
            }
        }
    }

    // Constraint 3: Generic availability windows.
    for job in &problem.jobs {
        let Some((interval_start, interval_end)) = job_interval(job) else {
            continue;
        };

        for required_resource_id in &job.required_resources {
            if let Some(resource) = problem
                .resources
                .iter()
                .find(|resource| resource.id == *required_resource_id)
            {
                if !resource.availability_windows.is_empty()
                    && !interval_within_any_window(
                        interval_start,
                        interval_end,
                        &resource.availability_windows,
                    )
                {
                    score += AVAILABILITY_VIOLATION_PENALTY;
                }
            }
        }
    }

    // Constraint 4: Generic precedence edges.
    for edge in &problem.edges {
        let Some(from_job) = problem.jobs.iter().find(|job| job.id == edge.from_job_id) else {
            continue;
        };
        let Some(to_job) = problem.jobs.iter().find(|job| job.id == edge.to_job_id) else {
            continue;
        };

        let Some((from_start, from_end)) = job_interval(from_job) else {
            continue;
        };
        let Some((to_start, to_end)) = job_interval(to_job) else {
            continue;
        };

        let is_valid = match edge.edge_type.as_str() {
            "finish_to_start" => from_end + edge.lag <= to_start,
            "start_to_start" => from_start + edge.lag <= to_start,
            "finish_to_finish" => from_end + edge.lag <= to_end,
            "start_to_finish" => from_start + edge.lag <= to_end,
            _ => true,
        };

        if !is_valid {
            score += PRECEDENCE_VIOLATION_PENALTY;
        }
    }

    score
}

#[must_use]
pub fn calculate_score_with_conflicts(problem: &Problem, total_conflicts: usize) -> HardMediumSoftScore {
    let mut score = calculate_score(problem);

    #[allow(clippy::cast_possible_wrap)]
    {
        for _ in 0..total_conflicts {
            score += CONFLICT_PENALTY;
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
        let j1 = Job {
            id: 1,
            duration: 10,
            required_resources: vec![],
            release_time: None,
            due_time: None,
            batch_key: None,
            start_time: None,
        };
        let problem = Problem {
            id: "1".to_string(),
            resources: vec![],
            jobs: vec![j1],
            edges: vec![],
            score_components: vec![],
            explanation: None,
        };
        let score = calculate_score(&problem);
        assert_eq!(score.medium, -1); 
    }

    #[test]
    fn test_lexicographical_comparison() {
        let s1 = HardMediumSoftScore::new(-1, 0, 0);
        let s2 = HardMediumSoftScore::new(0, -100, -100);
        assert!(s2 > s1, "Score with 0 hard is better than score with -1 hard, even with poor medium/soft");
    }

    #[test]
    fn test_conflict_penalty_is_added_without_topology_dependency() {
        let problem = Problem {
            id: "1".to_string(),
            resources: vec![],
            jobs: vec![],
            edges: vec![],
            score_components: vec![],
            explanation: None,
        };
        let score = calculate_score_with_conflicts(&problem, 2);
        assert_eq!(score.hard, -20);
    }
}
