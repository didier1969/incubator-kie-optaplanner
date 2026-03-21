#![deny(warnings)]
#![deny(clippy::all)]
#![deny(clippy::pedantic)]

pub mod domain;
pub mod score;

#[rustler::nif]
#[allow(clippy::needless_pass_by_value)]
fn evaluate_problem(problem: domain::Problem) -> i64 {
    score::calculate_score(&problem)
}

#[rustler::nif]
fn add(a: i64, b: i64) -> i64 {
    a + b
}

rustler::init!("Elixir.HexaPlanner.SolverNif");