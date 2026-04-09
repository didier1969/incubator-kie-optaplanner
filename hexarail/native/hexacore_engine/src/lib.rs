// Copyright (c) Didier Stadelmann. All rights reserved.

#![deny(warnings)]
#![deny(clippy::all)]
#![deny(clippy::pedantic)]
#![allow(clippy::needless_pass_by_value)]

use hexacore_logic::domain;

#[rustler::nif]
pub fn evaluate_problem_core(problem: domain::Problem) -> i64 {
    hexacore_logic::evaluate_problem_core(problem)
}

#[rustler::nif]
pub fn add(a: i64, b: i64) -> i64 {
    hexacore_logic::add(a, b)
}

#[rustler::nif]
pub fn optimize_problem_core(problem: domain::Problem, iterations: i32) -> domain::Problem {
    hexacore_logic::optimize_problem_core(problem, iterations)
}

rustler::init!("Elixir.HexaCore.Native");
