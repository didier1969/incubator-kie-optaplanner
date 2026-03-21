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

#[rustler::nif]
fn build_network_graph(edges: Vec<(String, String, f64)>) -> usize {
    let mut network = topology::PhysicalNetwork::new();
    for (station_a, station_b, weight) in edges {
        let node_a = network.add_station(&station_a);
        let node_b = network.add_station(&station_b);
        network.add_track(node_a, node_b, weight);
    }
    network.station_count()
}

rustler::init!("Elixir.HexaPlanner.SolverNif");