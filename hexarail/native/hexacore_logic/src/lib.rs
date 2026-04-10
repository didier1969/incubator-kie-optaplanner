// Copyright (c) Didier Stadelmann. All rights reserved.

#![deny(warnings)]
#![deny(clippy::all)]
#![deny(clippy::pedantic)]
#![allow(non_local_definitions)]
#![allow(clippy::needless_pass_by_value)]
#![allow(clippy::type_complexity)]

pub mod domain;
pub mod incremental_score;
pub mod nco;
pub mod score;
pub mod solver;
pub mod gnn;

mod atoms {
    rustler::atoms! {
        ok,
        error,
    }
}


pub fn evaluate_problem_core(problem: domain::Problem) -> domain::HardMediumSoftScore {
    score::calculate_score(&problem)
}


pub fn add(a: i64, b: i64) -> i64 {
    a + b
}


#[allow(clippy::needless_pass_by_value)]
pub fn optimize_problem_core<F>(
    problem: domain::Problem, 
    iterations: i32, 
    guidance_fn: Option<F>
) -> domain::Problem 
where
    F: FnMut(&domain::Problem) -> Vec<f32>,
{
    solver::optimize(problem, 0, iterations, guidance_fn)
}

// No rustler::init here
