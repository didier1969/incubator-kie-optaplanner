// Copyright (c) Didier Stadelmann. All rights reserved.

#![deny(warnings)]
#![deny(clippy::all)]
#![deny(clippy::pedantic)]
#![allow(non_local_definitions)]
#![allow(clippy::needless_pass_by_value)]
#![allow(clippy::type_complexity)]

pub mod domain;
pub mod incremental_score;
pub mod score;
pub mod solver;

mod atoms {
    rustler::atoms! {
        ok,
        error,
    }
}


pub fn evaluate_problem_core(problem: domain::Problem) -> i64 {
    score::calculate_score(&problem)
}


pub fn add(a: i64, b: i64) -> i64 {
    a + b
}


#[allow(clippy::needless_pass_by_value)]
pub fn optimize_problem_core(problem: domain::Problem, iterations: i32) -> domain::Problem {
    solver::optimize(problem, 0, iterations)
}

// No rustler::init here
