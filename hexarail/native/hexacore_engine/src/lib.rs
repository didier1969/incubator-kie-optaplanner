// Copyright (c) Didier Stadelmann. All rights reserved.

#![deny(warnings)]
#![deny(clippy::all)]
#![deny(clippy::pedantic)]
#![allow(non_local_definitions)]
#![allow(clippy::needless_pass_by_value)]
#![allow(clippy::type_complexity)]

pub mod domain;
pub mod incremental_score;
pub mod railway_domain;
pub mod railway_nif;
pub mod score;
pub mod solver;
pub mod topology;

use rustler::{Env, Term};
use std::sync::RwLock;
use crate::topology::NetworkManager;

mod atoms {
    rustler::atoms! {
        ok,
        error,
    }
}

pub struct NetworkResource {
    pub manager: RwLock<NetworkManager>,
}

#[rustler::nif]
fn evaluate_problem_core(problem: domain::Problem) -> i64 {
    score::calculate_score(&problem)
}

#[rustler::nif]
fn add(a: i64, b: i64) -> i64 {
    a + b
}

#[rustler::nif]
#[allow(clippy::needless_pass_by_value)]
fn optimize_problem_core(problem: domain::Problem, iterations: i32) -> domain::Problem {
    solver::optimize(problem, 0, iterations)
}

fn load(env: Env, _info: Term) -> bool {
    let _ = rustler::resource!(NetworkResource, env);
    true
}

rustler::init!("Elixir.HexaRail.Native", load = load);
