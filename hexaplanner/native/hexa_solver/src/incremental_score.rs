#[salsa::query_group(ScoreStorage)]
pub trait ScoreEngine: salsa::Database {
    #[salsa::input]
    fn get_base_score(&self) -> i32;

    #[salsa::input]
    fn job_assigned(&self, job_id: u32) -> bool;

    fn get_total_score(&self) -> i32;
    fn unassigned_penalty(&self, job_id: u32) -> i32;
    fn calculate_penalties(&self) -> i32;
}

fn get_total_score(db: &dyn ScoreEngine) -> i32 {
    db.get_base_score() + db.calculate_penalties()
}

fn unassigned_penalty(db: &dyn ScoreEngine, job_id: u32) -> i32 {
    if !db.job_assigned(job_id) {
        -100
    } else {
        0
    }
}

fn calculate_penalties(db: &dyn ScoreEngine) -> i32 {
    // In a real system, we'd iterate over known jobs. For MVP, hardcode job 1.
    db.unassigned_penalty(1)
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

    #[test]
    fn test_salsa_database_initialization() {
        let mut db = ScoreDatabase::default();
        db.set_get_base_score(10);
        db.set_job_assigned(1, true); // Prevent panic on uninitialized input
        assert_eq!(db.get_total_score(), 10);
    }

    #[test]
    fn test_incremental_constraint_evaluation() {
        let mut db = ScoreDatabase::default();
        // Assume Job 1 is unassigned
        db.set_job_assigned(1, false);
        assert_eq!(db.calculate_penalties(), -100); // Penalty for unassigned

        // Assign Job 1
        db.set_job_assigned(1, true);
        assert_eq!(db.calculate_penalties(), 0);
    }
}
