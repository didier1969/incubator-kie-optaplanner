#![deny(warnings)]
#![deny(clippy::all)]
#![deny(clippy::pedantic)]

pub mod domain;

#[rustler::nif]
fn add(a: i64, b: i64) -> i64 {
    a + b
}

rustler::init!("Elixir.HexaPlanner.SolverNif");