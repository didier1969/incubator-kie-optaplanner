use localsearch::OptModel;
use localsearch::optim::{HillClimbingOptimizer, LocalSearchOptimizer};

pub struct BlastZoneModel {}

impl OptModel for BlastZoneModel {
    type SolutionType = i32;
    type TransitionType = i32;
    type ScoreType = i64;

    fn generate_random_solution<R: rand::Rng>(
        &self,
        _rng: &mut R,
    ) -> Result<(Self::SolutionType, Self::ScoreType), localsearch::LocalsearchError> {
        Ok((0, 0))
    }

    fn generate_trial_solution<R: rand::Rng>(
        &self,
        current_solution: Self::SolutionType,
        _current_score: Self::ScoreType,
        _rng: &mut R,
    ) -> (Self::SolutionType, Self::TransitionType, Self::ScoreType) {
        (current_solution, 0, 0)
    }
}

pub fn run() {
    let model = BlastZoneModel {};
    let mut rng = rand::thread_rng();
    let optimizer = HillClimbingOptimizer::new(1000, 10);
    // optimizer.optimize(&model, None, 1000, &mut rng);
}
