// Copyright (c) Didier Stadelmann. All rights reserved.

use crate::domain::Problem;

const UNASSIGNED_JOB_PENALTY: i64 = 100;
const RELEASE_VIOLATION_PENALTY: i64 = 150;
const DUE_DATE_VIOLATION_PENALTY: i64 = 200;
const PRECEDENCE_VIOLATION_PENALTY: i64 = 250;
const AVAILABILITY_VIOLATION_PENALTY: i64 = 175;
const CONFLICT_PENALTY: i64 = 1_000;

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
pub fn calculate_score(problem: &Problem) -> i64 {
    let mut score = 0;

    // Constraint 1: Unassigned job penalty.
    for job in &problem.jobs {
        if job.start_time.is_none() {
            score -= UNASSIGNED_JOB_PENALTY;
        }
    }

    // Constraint 2: Generic release and due-date violations.
    for job in &problem.jobs {
        if let Some((interval_start, interval_end)) = job_interval(job) {
            if job.release_time.is_some_and(|release_time| interval_start < release_time) {
                score -= RELEASE_VIOLATION_PENALTY;
            }

            if job.due_time.is_some_and(|due_time| interval_end > due_time) {
                score -= DUE_DATE_VIOLATION_PENALTY;
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
                    score -= AVAILABILITY_VIOLATION_PENALTY;
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
            score -= PRECEDENCE_VIOLATION_PENALTY;
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
    use crate::domain::{Edge, Job, Resource, Window};

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
        };
        let score = calculate_score(&problem);
        assert_eq!(score, -100); 
    }

    #[test]
    fn test_conflict_penalty_is_added_without_topology_dependency() {
        let problem = Problem {
            id: "1".to_string(),
            resources: vec![],
            jobs: vec![],
            edges: vec![],
            score_components: vec![],
        };
        let score = calculate_score_with_conflicts(&problem, 2);
        assert_eq!(score, -2_000);
    }

    #[test]
    fn test_generic_penalties_are_applied_without_vertical_semantics() {
        let resource = Resource {
            id: 1,
            name: "machine-1".to_string(),
            capacity: 1,
            availability_windows: vec![Window { start_at: 0, end_at: 60 }],
        };
        let jobs = vec![
            Job {
                id: 1,
                duration: 50,
                required_resources: vec![1],
                release_time: Some(0),
                due_time: Some(40),
                batch_key: None,
                start_time: Some(30),
            },
            Job {
                id: 2,
                duration: 10,
                required_resources: vec![1],
                release_time: Some(0),
                due_time: Some(20),
                batch_key: None,
                start_time: Some(0),
            },
        ];
        let problem = Problem {
            id: "1".to_string(),
            resources: vec![resource],
            jobs,
            edges: vec![Edge {
                from_job_id: 1,
                to_job_id: 2,
                lag: 0,
                edge_type: "finish_to_start".to_string(),
            }],
            score_components: vec![],
        };

        assert!(calculate_score(&problem) < 0);
    }
}
