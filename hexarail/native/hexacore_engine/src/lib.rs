// Copyright (c) Didier Stadelmann. All rights reserved.

#![deny(warnings)]
#![deny(clippy::all)]
#![deny(clippy::pedantic)]
#![allow(non_local_definitions)]
#![allow(clippy::needless_pass_by_value)]

use hexacore_logic::domain;

#[rustler::nif]
pub fn evaluate_problem_core(problem: domain::Problem) -> domain::HardMediumSoftScore {
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
        "metaheuristic" => Ok(hexacore_logic::optimize_problem_core(problem, iterations, None)),
        "nco" => {
            // 1. Instantiate the SOTA GNN Brain and a local encoder
            let encoder = hexacore_logic::nco::FeatureEncoder::new();
            let brain = hexacore_logic::gnn::NcoInferenceEngine::new();

            // 2. SOTA: Generate Heuristic Prior ONCE before the loop (Extracted from Hot Loop)
            // The GNN evaluates the initial factory state to rank jobs by criticality.
            // This frees up 100% of the CPU for the Salsa LAHC solver's raw speed.
            let guidance = if let Ok(tensor_data) = encoder.encode(&problem, 0.0) {
                Some(brain.forward_pass(&tensor_data))
            } else {
                None
            };

            // 3. Guided Search: Use LAHC guided by the static Heuristic Prior
            let optimized = hexacore_logic::optimize_problem_core(problem, iterations, guidance);

            Ok(optimized)
        },
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
    let encoder = resource.encoder.read().unwrap();
    encoder.freeze_vocabularies();
    atoms::ok()
}

#[rustler::nif]
pub fn extract_features_core(
    resource: ResourceArc<EncoderResource>,
    problem: domain::Problem,
    current_time: f32,
) -> Result<hexacore_logic::nco::TensorData, rustler::Error> {
    let encoder = resource.encoder.read().unwrap();
    encoder.encode(&problem, current_time).map_err(|e| rustler::Error::RaiseTerm(Box::new(e)))
}

#[rustler::nif]
pub fn export_feature_vocabularies(
    resource: ResourceArc<EncoderResource>,
) -> String {
    let encoder = resource.encoder.read().unwrap();
    encoder.export_json()
}

#[rustler::nif]
pub fn import_feature_vocabularies(json: String) -> Result<ResourceArc<EncoderResource>, rustler::Error> {
    match hexacore_logic::nco::FeatureEncoder::import_json(&json) {
        Ok(encoder) => Ok(ResourceArc::new(EncoderResource {
            encoder: RwLock::new(encoder),
        })),
        Err(_) => Err(rustler::Error::BadArg),
    }
}

fn load(env: Env, _info: Term) -> bool {
    let _ = rustler::resource!(EncoderResource, env);
    true
}

rustler::init!("Elixir.HexaCore.Native", load = load);
