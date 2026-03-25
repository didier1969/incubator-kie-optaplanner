# HexaRail Phase 4 Implementation Plan: The Rust Heuristic Engine

> **For Claude/Gemini:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Implement a basic Local Search (Hill Climbing) algorithm in Rust. The engine will take a `Problem`, mutate job start times, evaluate the score, and return the optimized `Problem` back to Elixir. This completely replaces OptaPlanner's Local Search phase.

**Architecture:** Elixir Problem -> Rustler -> Rust Clone (O(1) concept) -> Rust Hill Climbing Loop -> Optimized Rust Problem -> Rustler -> Elixir.

**Tech Stack:** Rust, Rustler.

---

### Task 1: Enable Mutation and Cloning on Domain Entities

To perform Local Search, Rust needs to clone the state to test new moves without destroying the current best known state.

**Files:**
- Modify: `hexarail/native/hexa_solver/src/domain.rs`

**Step 1: Write the failing test**

```rust
// hexarail/native/hexa_solver/src/domain.rs
#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_domain_clone() {
        let j1 = Job { id: 1, duration: 10, required_resources: vec![], start_time: None };
        let j2 = j1.clone();
        assert_eq!(j1.id, j2.id);
    }
}
```

**Step 2: Run test to verify it fails**

Run: `nix develop -c bash -c "cd hexarail/native/hexa_solver && cargo test"`
Expected: FAIL (method `clone` not found for `Job`)

**Step 3: Write minimal implementation**

Update `hexarail/native/hexa_solver/src/domain.rs` to derive `Clone` for all structs:

```rust
use rustler::NifStruct;

#[derive(Debug, Clone, NifStruct)]
#[module = "HexaRail.Domain.Resource"]
pub struct Resource {
    pub id: i64,
    pub name: String,
    pub capacity: i64,
}

#[derive(Debug, Clone, NifStruct)]
#[module = "HexaRail.Domain.Job"]
pub struct Job {
    pub id: i64,
    pub duration: i64,
    pub required_resources: Vec<i64>,
    pub start_time: Option<i64>,
}

#[derive(Debug, Clone, NifStruct)]
#[module = "HexaRail.Domain.Problem"]
pub struct Problem {
    pub id: String,
    pub resources: Vec<Resource>,
    pub jobs: Vec<Job>,
}
```

**Step 4: Run test to verify it passes**

Run: `nix develop -c bash -c "cd hexarail/native/hexa_solver && cargo test && cargo clippy -- -D warnings"`
Expected: PASS

**Step 5: Commit**

```bash
git add hexarail/native/hexa_solver/
git commit -m "feat(domain): derive clone for rust entities to support local search mutations"
```

---

### Task 2: Implement the Hill Climbing Solver Loop in Rust

**Files:**
- Create: `hexarail/native/hexa_solver/src/solver.rs`
- Modify: `hexarail/native/hexa_solver/src/lib.rs`

**Step 1: Write the failing test**

```rust
// hexarail/native/hexa_solver/src/solver.rs
use crate::domain::{Job, Problem};

#[cfg(test)]
mod tests {
    use super::*;
    use crate::score;

    #[test]
    fn test_hill_climbing_assigns_jobs() {
        let problem = Problem {
            id: "sim_1".to_string(),
            resources: vec![],
            jobs: vec![Job { id: 1, duration: 10, required_resources: vec![], start_time: None }],
        };

        // Initially score is -100
        assert_eq!(score::calculate_score(&problem), -100);

        let optimized = optimize(problem, 10);
        
        // After optimization, the job should have a start_time, making score 0
        assert_eq!(score::calculate_score(&optimized), 0);
        assert!(optimized.jobs[0].start_time.is_some());
    }
}
```

**Step 2: Run test to verify it fails**

Run: `nix develop -c bash -c "cd hexarail/native/hexa_solver && cargo test"`
Expected: FAIL (Function `optimize` not found)

**Step 3: Write minimal implementation**

1. Create `hexarail/native/hexa_solver/src/solver.rs`:
```rust
use crate::domain::Problem;
use crate::score::calculate_score;

#[must_use]
pub fn optimize(mut current_problem: Problem, iterations: i32) -> Problem {
    let mut current_score = calculate_score(&current_problem);

    for i in 0..iterations {
        // Create a neighbor (mutation)
        let mut neighbor = current_problem.clone();
        
        // Very basic mutation: assign a dummy start time to the first unassigned job
        if let Some(job) = neighbor.jobs.iter_mut().find(|j| j.start_time.is_none()) {
            job.start_time = Some(i as i64 * 10);
        }

        let neighbor_score = calculate_score(&neighbor);

        // Hill Climbing: Accept if strictly better
        if neighbor_score > current_score {
            current_problem = neighbor;
            current_score = neighbor_score;
        }

        // Fast exit if we reached perfect score (0 penalties)
        if current_score == 0 {
            break;
        }
    }

    current_problem
}
```

2. Expose it via NIF in `hexarail/native/hexa_solver/src/lib.rs`:
```rust
#![deny(warnings)]
#![deny(clippy::all)]
#![deny(clippy::pedantic)]

pub mod domain;
pub mod score;
pub mod solver; // Add this line

#[rustler::nif]
fn evaluate_problem(problem: domain::Problem) -> i64 {
    score::calculate_score(&problem)
}

#[rustler::nif]
fn optimize_problem(problem: domain::Problem, iterations: i32) -> domain::Problem {
    solver::optimize(problem, iterations)
}

#[rustler::nif]
fn add(a: i64, b: i64) -> i64 {
    a + b
}

rustler::init!("Elixir.HexaRail.SolverNif", [add, evaluate_problem, optimize_problem]);
```

**Step 4: Run test to verify it passes**

Run: `nix develop -c bash -c "cd hexarail/native/hexa_solver && cargo test && cargo clippy -- -D warnings"`
Expected: PASS

**Step 5: Commit**

```bash
git add hexarail/native/hexa_solver/
git commit -m "feat(solver): implement native rust hill climbing algorithm for problem optimization"
```

---

### Task 3: Bridge the Optimizer back to Elixir

**Files:**
- Modify: `hexarail/lib/hexarail/solver_nif.ex`
- Modify: `hexarail/test/solver_integration_test.exs`

**Step 1: Write the failing test**

```elixir
# In hexarail/test/solver_integration_test.exs, add:
  test "rust nif optimizes the problem and returns mutated state" do
    problem = %Problem{
      id: "sim_2",
      resources: [],
      jobs: [
        %Job{id: 1, duration: 10, required_resources: [], start_time: nil}
      ]
    }

    assert SolverNif.evaluate_problem(problem) == -100
    
    optimized_problem = SolverNif.optimize_problem(problem, 10)
    
    assert SolverNif.evaluate_problem(optimized_problem) == 0
    # Ensure the Rust engine actually mutated the struct and sent it back
    assert hd(optimized_problem.jobs).start_time != nil
  end
```

**Step 2: Run test to verify it fails**

Run: `nix develop -c bash -c "cd hexarail && mix test test/solver_integration_test.exs"`
Expected: FAIL (Undefined function `optimize_problem/2`)

**Step 3: Write minimal implementation**

Update `hexarail/lib/hexarail/solver_nif.ex`:
```elixir
defmodule HexaRail.SolverNif do
  @moduledoc false
  use Rustler, otp_app: :hexarail, crate: "hexa_solver"

  def add(_a, _b), do: :erlang.nif_error(:nif_not_loaded)
  
  @spec evaluate_problem(HexaRail.Domain.Problem.t()) :: integer()
  def evaluate_problem(_problem), do: :erlang.nif_error(:nif_not_loaded)

  @spec optimize_problem(HexaRail.Domain.Problem.t(), integer()) :: HexaRail.Domain.Problem.t()
  def optimize_problem(_problem, _iterations), do: :erlang.nif_error(:nif_not_loaded)
end
```

**Step 4: Run test to verify it passes**

Run: `nix develop -c bash -c "cd hexarail && mix test test/solver_integration_test.exs"`
Expected: PASS

Run Quality Gates: `nix develop -c bash -c "cd hexarail && mix credo --strict && mix dialyzer"`

**Step 5: Commit**

```bash
git add hexarail/
git commit -m "feat(bridge): expose rust optimization loop to elixir control plane"
```