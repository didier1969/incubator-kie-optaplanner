// Copyright (c) Didier Stadelmann. All rights reserved.

#![deny(warnings)]
#![deny(clippy::all)]
#![deny(clippy::pedantic)]
#![allow(non_local_definitions)]
#![allow(clippy::needless_pass_by_value)]
#![allow(clippy::type_complexity)]

pub use hexacore_logic::{domain, score, solver};

pub mod railway_domain;
pub mod railway_nif;
pub mod railway_topology;

#[cfg(test)]
mod railway_domain_tests;
#[cfg(test)]
mod railway_topology_tests;

use rustler::{Env, Term};

mod atoms {
    rustler::atoms! {
        ok,
        error,
    }
}

fn load(env: Env, _info: Term) -> bool {
    let _ = rustler::resource!(railway_nif::NetworkResource, env);
    true
}

rustler::init!("Elixir.HexaRail.Native", load = load);
