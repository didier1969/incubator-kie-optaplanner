#![deny(warnings)]
#![deny(clippy::all)]
#![deny(clippy::pedantic)]

pub mod domain;
pub mod score;
pub mod solver;
pub mod incremental_score;
pub mod topology;

#[rustler::nif]
#[allow(clippy::needless_pass_by_value)]
fn evaluate_problem(problem: domain::Problem) -> i64 {
    score::calculate_score(&problem)
}

#[rustler::nif]
fn add(a: i64, b: i64) -> i64 {
    a + b
}

#[rustler::nif]
#[allow(clippy::needless_pass_by_value)]
fn optimize_problem(problem: domain::Problem, iterations: i32) -> domain::Problem {
    solver::optimize(problem, iterations)
}

rustler::init!("Elixir.HexaPlanner.SolverNif");