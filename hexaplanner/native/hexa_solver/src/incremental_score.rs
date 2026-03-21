#[salsa::query_group(ScoreStorage)]
pub trait ScoreEngine: salsa::Database {
    #[salsa::input]
    fn get_base_score(&self) -> i32;

    fn get_total_score(&self) -> i32;
}

fn get_total_score(db: &dyn ScoreEngine) -> i32 {
    db.get_base_score()
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
        assert_eq!(db.get_total_score(), 10);
    }
}
