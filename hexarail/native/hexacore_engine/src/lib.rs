// Copyright (c) Didier Stadelmann. All rights reserved.

#![deny(warnings)]
#![deny(clippy::all)]
#![deny(clippy::pedantic)]
#![allow(non_local_definitions)]
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

use rustler::{Env, ResourceArc, Term};
use std::sync::RwLock;

pub struct EncoderResource {
    pub encoder: RwLock<hexacore_logic::nco::FeatureEncoder>,
}

mod atoms {
    rustler::atoms! {
        ok,
        error,
    }
}

#[rustler::nif]
pub fn init_feature_encoder() -> ResourceArc<EncoderResource> {
    ResourceArc::new(EncoderResource {
        encoder: RwLock::new(hexacore_logic::nco::FeatureEncoder::new()),
    })
}

#[rustler::nif]
pub fn freeze_feature_encoder(resource: ResourceArc<EncoderResource>) -> rustler::Atom {
    let mut encoder = resource.encoder.write().unwrap();
    encoder.freeze_vocabularies();
    atoms::ok()
}

#[rustler::nif]
pub fn extract_features_core(
    resource: ResourceArc<EncoderResource>,
    problem: domain::Problem,
) -> Result<hexacore_logic::nco::TensorData, rustler::Error> {
    let mut encoder = resource.encoder.write().unwrap();
    Ok(encoder.encode(&problem))
}

fn load(env: Env, _info: Term) -> bool {
    let _ = rustler::resource!(EncoderResource, env);
    true
}

rustler::init!("Elixir.HexaCore.Native", load = load);
