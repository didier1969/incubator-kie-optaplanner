#[salsa::query_group(ScoreStorage)]
pub trait ScoreEngine: salsa::Database {
    #[salsa::input]
    fn get_base_score(&self) -> i64;

    #[salsa::input]
    fn job_assigned(&self, job_id: i64) -> bool;

    #[salsa::input]
    fn job_ids(&self) -> Vec<i64>;

    fn get_total_score(&self) -> i64;
    fn unassigned_penalty(&self, job_id: i64) -> i64;
    fn calculate_penalties(&self) -> i64;
}

fn get_total_score(db: &dyn ScoreEngine) -> i64 {
    db.get_base_score() + db.calculate_penalties()
}

fn unassigned_penalty(db: &dyn ScoreEngine, job_id: i64) -> i64 {
    if db.job_assigned(job_id) {
        0
    } else {
        -100
    }
}

fn calculate_penalties(db: &dyn ScoreEngine) -> i64 {
    db.job_ids().iter().map(|&id| db.unassigned_penalty(id)).sum()
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
        db.set_job_ids(vec![1]);
        db.set_job_assigned(1, true); // Prevent panic on uninitialized input
        assert_eq!(db.get_total_score(), 10);
    }

    #[test]
    fn test_incremental_constraint_evaluation() {
        let mut db = ScoreDatabase::default();
        db.set_get_base_score(0);
        db.set_job_ids(vec![1]);
        // Assume Job 1 is unassigned
        db.set_job_assigned(1, false);
        assert_eq!(db.calculate_penalties(), -100); // Penalty for unassigned

        // Assign Job 1
        db.set_job_assigned(1, true);
        assert_eq!(db.calculate_penalties(), 0);
    }
}
