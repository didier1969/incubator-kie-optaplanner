use crate::domain::{HardMediumSoftScore, Job, Resource, Edge, ConstraintViolation, ScoreExplanation};

#[salsa::query_group(ScoreStorage)]
pub trait ScoreEngine: salsa::Database {
    // --- Inputs ---
    #[salsa::input]
    fn job_ids(&self) -> Vec<i64>;
    #[salsa::input]
    fn job_data(&self, id: i64) -> Job;
    #[salsa::input]
    fn job_start_time(&self, id: i64) -> Option<i64>;

    #[salsa::input]
    fn resource_ids(&self) -> Vec<i64>;
    #[salsa::input]
    fn resource_data(&self, id: i64) -> Resource;

    #[salsa::input]
    fn edge_ids(&self) -> Vec<usize>;
    #[salsa::input]
    fn edge_data(&self, id: usize) -> Edge;

    // --- Derived Queries (Memoized) ---
    fn total_score(&self) -> HardMediumSoftScore;
    fn score_explanation(&self) -> ScoreExplanation;
    
    fn job_score(&self, id: i64) -> HardMediumSoftScore;
    fn job_violations(&self, id: i64) -> Vec<ConstraintViolation>;
    
    fn edge_score(&self, id: usize) -> HardMediumSoftScore;
    fn edge_violations(&self, id: usize) -> Vec<ConstraintViolation>;
    
    fn resource_score(&self, id: i64) -> HardMediumSoftScore;
    fn resource_violations(&self, id: i64) -> Vec<ConstraintViolation>;
    
    fn unassigned_penalty(&self, id: i64) -> HardMediumSoftScore;
    fn temporal_penalty(&self, id: i64) -> HardMediumSoftScore;
    fn availability_penalty(&self, id: i64) -> HardMediumSoftScore;
}

const UNASSIGNED_JOB_PENALTY: HardMediumSoftScore = HardMediumSoftScore { hard: 0, medium: -1, soft: 0 };
const RELEASE_VIOLATION_PENALTY: HardMediumSoftScore = HardMediumSoftScore { hard: 0, medium: 0, soft: -150 };
const DUE_DATE_VIOLATION_PENALTY: HardMediumSoftScore = HardMediumSoftScore { hard: 0, medium: 0, soft: -200 };
const PRECEDENCE_VIOLATION_PENALTY: HardMediumSoftScore = HardMediumSoftScore { hard: -1, medium: 0, soft: 0 };
const AVAILABILITY_VIOLATION_PENALTY: HardMediumSoftScore = HardMediumSoftScore { hard: -1, medium: 0, soft: 0 };
const OVERLAP_VIOLATION_PENALTY: HardMediumSoftScore = HardMediumSoftScore { hard: -10, medium: 0, soft: 0 };

fn total_score(db: &dyn ScoreEngine) -> HardMediumSoftScore {
    let mut total = HardMediumSoftScore::zero();
    
    // Aggregation of memoized job scores
    for &id in &db.job_ids() {
        total += db.job_score(id);
    }
    
    // Aggregation of memoized edge scores
    for &id in &db.edge_ids() {
        total += db.edge_score(id);
    }

    // Aggregation of memoized resource overlap scores
    for &id in &db.resource_ids() {
        total += db.resource_score(id);
    }

    total
}

fn score_explanation(db: &dyn ScoreEngine) -> ScoreExplanation {
    let mut violations = Vec::new();
    for &id in &db.job_ids() {
        violations.extend(db.job_violations(id));
    }
    for &id in &db.edge_ids() {
        violations.extend(db.edge_violations(id));
    }
    for &id in &db.resource_ids() {
        violations.extend(db.resource_violations(id));
    }
    ScoreExplanation {
        score: db.total_score(),
        violations,
    }
}

fn job_violations(db: &dyn ScoreEngine, id: i64) -> Vec<ConstraintViolation> {
    let mut violations = Vec::new();
    let job = db.job_data(id);
    
    if db.job_start_time(id).is_none() {
        violations.push(ConstraintViolation {
            name: "unassigned".to_string(),
            severity: "medium".to_string(),
            message: format!("Job {} is not assigned", id),
            job_id: Some(id),
            resource_id: None,
        });
    } else {
        let start = db.job_start_time(id).unwrap();
        if let Some(release) = job.release_time {
            if start < release {
                violations.push(ConstraintViolation {
                    name: "release_violation".to_string(),
                    severity: "soft".to_string(),
                    message: format!("Job {} starts at {} before release {}", id, start, release),
                    job_id: Some(id),
                    resource_id: None,
                });
            }
        }
        if let Some(due) = job.due_time {
            if start + job.duration > due {
                violations.push(ConstraintViolation {
                    name: "due_date_violation".to_string(),
                    severity: "soft".to_string(),
                    message: format!("Job {} ends at {} after due {}", id, start + job.duration, due),
                    job_id: Some(id),
                    resource_id: None,
                });
            }
        }
        
        let end = start + job.duration;
        for &res_id in &job.required_resources {
            let res = db.resource_data(res_id);
            if !res.availability_windows.is_empty() {
                let within_window = res.availability_windows.iter().any(|w| {
                    start >= w.start_at && end <= w.end_at
                });
                if !within_window {
                    violations.push(ConstraintViolation {
                        name: "availability_violation".to_string(),
                        severity: "hard".to_string(),
                        message: format!("Job {} on resource {} is outside availability windows", id, res_id),
                        job_id: Some(id),
                        resource_id: Some(res_id),
                    });
                }
            }
        }
    }
    violations
}

fn edge_violations(db: &dyn ScoreEngine, id: usize) -> Vec<ConstraintViolation> {
    let mut violations = Vec::new();
    let edge = db.edge_data(id);
    let from_start = db.job_start_time(edge.from_job_id);
    let to_start = db.job_start_time(edge.to_job_id);

    if let (Some(fs), Some(ts)) = (from_start, to_start) {
        let from_job = db.job_data(edge.from_job_id);
        let to_job = db.job_data(edge.to_job_id);
        let from_end = fs + from_job.duration;
        let to_end = ts + to_job.duration;

        let is_valid = match edge.edge_type.as_str() {
            "finish_to_start" => from_end + edge.lag <= ts,
            "start_to_start" => fs + edge.lag <= ts,
            "finish_to_finish" => from_end + edge.lag <= to_end,
            "start_to_finish" => fs + edge.lag <= to_end,
            _ => true,
        };

        if !is_valid {
            violations.push(ConstraintViolation {
                name: "precedence_violation".to_string(),
                severity: "hard".to_string(),
                message: format!("Precedence violation between {} and {} (type: {})", edge.from_job_id, edge.to_job_id, edge.edge_type),
                job_id: Some(edge.to_job_id),
                resource_id: None,
            });
        }
    }
    violations
}

fn resource_score(db: &dyn ScoreEngine, id: i64) -> HardMediumSoftScore {
    let mut score = HardMediumSoftScore::zero();
    let res = db.resource_data(id);
    
    // Find all jobs using this resource that have a start time
    let mut assigned_intervals = Vec::new();
    for &j_id in &db.job_ids() {
        let job = db.job_data(j_id);
        if job.required_resources.contains(&id) {
            if let Some(start) = db.job_start_time(j_id) {
                assigned_intervals.push((start, start + job.duration));
            }
        }
    }

    if assigned_intervals.len() <= res.capacity as usize {
        return score; // Not enough jobs to exceed capacity
    }

    // Sort intervals by start time for overlap detection
    assigned_intervals.sort_by_key(|int| int.0);
    
    // Simple naive overlap counting (O(K^2) per resource, where K is jobs on this resource)
    // SOTA would use an Interval Tree for O(K log K)
    for i in 0..assigned_intervals.len() {
        let mut concurrent_count = 1;
        for j in (i + 1)..assigned_intervals.len() {
            if assigned_intervals[j].0 < assigned_intervals[i].1 {
                concurrent_count += 1;
                if concurrent_count > res.capacity as usize {
                    score += OVERLAP_VIOLATION_PENALTY;
                }
            } else {
                break; // Because it's sorted, no more overlaps with interval i
            }
        }
    }

    score
}

fn resource_violations(db: &dyn ScoreEngine, id: i64) -> Vec<ConstraintViolation> {
    let mut violations = Vec::new();
    let res = db.resource_data(id);
    
    let mut assigned_intervals = Vec::new();
    for &j_id in &db.job_ids() {
        let job = db.job_data(j_id);
        if job.required_resources.contains(&id) {
            if let Some(start) = db.job_start_time(j_id) {
                assigned_intervals.push((start, start + job.duration, j_id));
            }
        }
    }

    if assigned_intervals.len() <= res.capacity as usize {
        return violations;
    }

    assigned_intervals.sort_by_key(|int| int.0);
    
    for i in 0..assigned_intervals.len() {
        let mut concurrent_count = 1;
        for j in (i + 1)..assigned_intervals.len() {
            if assigned_intervals[j].0 < assigned_intervals[i].1 {
                concurrent_count += 1;
                if concurrent_count > res.capacity as usize {
                    violations.push(ConstraintViolation {
                        name: "resource_overlap".to_string(),
                        severity: "hard".to_string(),
                        message: format!("Capacity exceeded on resource {}", id),
                        job_id: Some(assigned_intervals[j].2),
                        resource_id: Some(id),
                    });
                }
            } else {
                break;
            }
        }
    }
    
    violations
}

fn job_score(db: &dyn ScoreEngine, id: i64) -> HardMediumSoftScore {
    let mut score = HardMediumSoftScore::zero();
    score += db.unassigned_penalty(id);
    score += db.temporal_penalty(id);
    score += db.availability_penalty(id);
    score
}

fn edge_score(db: &dyn ScoreEngine, id: usize) -> HardMediumSoftScore {
    let edge = db.edge_data(id);
    let from_start = db.job_start_time(edge.from_job_id);
    let to_start = db.job_start_time(edge.to_job_id);

    match (from_start, to_start) {
        (Some(fs), Some(ts)) => {
            let from_job = db.job_data(edge.from_job_id);
            let to_job = db.job_data(edge.to_job_id);
            let from_end = fs + from_job.duration;
            let to_end = ts + to_job.duration;

            let is_valid = match edge.edge_type.as_str() {
                "finish_to_start" => from_end + edge.lag <= ts,
                "start_to_start" => fs + edge.lag <= ts,
                "finish_to_finish" => from_end + edge.lag <= to_end,
                "start_to_finish" => fs + edge.lag <= to_end,
                _ => true,
            };

            if is_valid { HardMediumSoftScore::zero() } else { PRECEDENCE_VIOLATION_PENALTY }
        }
        _ => HardMediumSoftScore::zero(), // Penalty handled by unassigned_penalty
    }
}

fn unassigned_penalty(db: &dyn ScoreEngine, id: i64) -> HardMediumSoftScore {
    if db.job_start_time(id).is_some() {
        HardMediumSoftScore::zero()
    } else {
        UNASSIGNED_JOB_PENALTY
    }
}

fn temporal_penalty(db: &dyn ScoreEngine, id: i64) -> HardMediumSoftScore {
    let Some(start) = db.job_start_time(id) else { return HardMediumSoftScore::zero(); };
    let job = db.job_data(id);
    let mut score = HardMediumSoftScore::zero();

    if let Some(release) = job.release_time {
        if start < release { score += RELEASE_VIOLATION_PENALTY; }
    }

    if let Some(due) = job.due_time {
        if start + job.duration > due { score += DUE_DATE_VIOLATION_PENALTY; }
    }

    score
}

fn availability_penalty(db: &dyn ScoreEngine, id: i64) -> HardMediumSoftScore {
    let Some(start) = db.job_start_time(id) else { return HardMediumSoftScore::zero(); };
    let job = db.job_data(id);
    let end = start + job.duration;

    for &res_id in &job.required_resources {
        let res = db.resource_data(res_id);
        if res.availability_windows.is_empty() { continue; }

        let within_window = res.availability_windows.iter().any(|w| {
            start >= w.start_at && end <= w.end_at
        });

        if !within_window { return AVAILABILITY_VIOLATION_PENALTY; }
    }

    HardMediumSoftScore::zero()
}

#[salsa::database(ScoreStorage)]
#[derive(Default)]
pub struct ScoreDatabase {
    storage: salsa::Storage<Self>,
}

impl salsa::Database for ScoreDatabase {}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::domain::Window;

    #[test]
    fn test_sota_incremental_precedence() {
        let mut db = ScoreDatabase::default();
        let j1_id = 1;
        let j2_id = 2;
        let edge_id = 0;

        db.set_job_ids(vec![j1_id, j2_id]);
        db.set_job_data(j1_id, Job { id: j1_id, duration: 10, required_resources: vec![], release_time: None, due_time: None, batch_key: None, start_time: None });
        db.set_job_data(j2_id, Job { id: j2_id, duration: 10, required_resources: vec![], release_time: None, due_time: None, batch_key: None, start_time: None });
        
        db.set_edge_ids(vec![edge_id]);
        db.set_edge_data(edge_id, Edge { from_job_id: j1_id, to_job_id: j2_id, lag: 0, edge_type: "finish_to_start".to_string() });
        db.set_extra_conflict_score(HardMediumSoftScore::zero());

        // Assign with violation: J1 at 0, J2 at 5 (should be at least 10)
        db.set_job_start_time(j1_id, Some(0));
        db.set_job_start_time(j2_id, Some(5));
        
        assert_eq!(db.total_score().hard, -1); // Precedence violation

        // Fix violation: J2 at 10
        db.set_job_start_time(j2_id, Some(10));
        assert_eq!(db.total_score().hard, 0);
    }

    #[test]
    fn test_sota_incremental_availability() {
        let mut db = ScoreDatabase::default();
        let j1_id = 1;
        let r1_id = 1;

        db.set_job_ids(vec![j1_id]);
        db.set_job_data(j1_id, Job { id: j1_id, duration: 10, required_resources: vec![r1_id], release_time: None, due_time: None, batch_key: None, start_time: None });
        
        db.set_resource_ids(vec![r1_id]);
        db.set_resource_data(r1_id, Resource { id: r1_id, name: "M1".to_string(), capacity: 1, availability_windows: vec![Window { start_at: 0, end_at: 10 }] });
        db.set_edge_ids(vec![]);
        db.set_extra_conflict_score(HardMediumSoftScore::zero());

        // Valid assignment
        db.set_job_start_time(j1_id, Some(0));
        assert_eq!(db.total_score().hard, 0);

        // Invalid assignment (outside window)
        db.set_job_start_time(j1_id, Some(5));
        assert_eq!(db.total_score().hard, -1);
    }
}
