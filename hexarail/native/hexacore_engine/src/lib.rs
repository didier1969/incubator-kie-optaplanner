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
pub fn optimize_problem_core(
    problem: domain::Problem,
    strategy: String,
    iterations: i32,
) -> Result<domain::Problem, rustler::Error> {
    match strategy.as_str() {
        "metaheuristic" => Ok(hexacore_logic::optimize_problem_core(problem, iterations)),
        "nco" => Err(rustler::Error::RaiseAtom("not_implemented")),
        _ => Err(rustler::Error::BadArg),
    }
}

#[rustler::nif]
pub fn extract_features_core(
    problem: domain::Problem,
) -> Result<hexacore_logic::nco::TensorData, rustler::Error> {
    let mut encoder = hexacore_logic::nco::FeatureEncoder::new();
    Ok(encoder.encode(&problem))
}

rustler::init!("Elixir.HexaCore.Native");
