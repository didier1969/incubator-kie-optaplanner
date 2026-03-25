# HexaRail Phase 3 Implementation Plan: The Rust Data Plane

> **For Claude/Gemini:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Implement the Rust Data Plane to receive the Elixir structs (`Problem`, `Job`, `Resource`) via Rustler, and calculate a hard-coded constraint score. This establishes the foundation for the Incremental Score Calculation.

**Architecture:** Elixir Structs -> Rustler NIF (ETF Decoding) -> Rust Native Structs -> Score Calculation.

**Tech Stack:** Elixir, Rust, Rustler.

---

### Task 1: Replicate Domain Entities in Rust

**Files:**
- Modify: `hexarail/native/hexa_solver/src/lib.rs`
- Create: `hexarail/native/hexa_solver/src/domain.rs`

**Step 1: Write the failing test (Rust side)**

```rust
// hexarail/native/hexa_solver/src/domain.rs
#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_problem_instantiation() {
        let r1 = Resource { id: 1, name: "Machine".to_string(), capacity: 1 };
        let j1 = Job { id: 100, duration: 60, required_resources: vec![1], start_time: None };
        let problem = Problem { id: "sim_1".to_string(), resources: vec![r1], jobs: vec![j1] };
        
        assert_eq!(problem.jobs.len(), 1);
    }
}
```

**Step 2: Run test to verify it fails**

Run: `nix develop -c bash -c "cd hexarail/native/hexa_solver && cargo test"`
Expected: FAIL (Undefined structs)

**Step 3: Write minimal implementation**

1. Create `hexarail/native/hexa_solver/src/domain.rs` with strict Rustler mapping:
```rust
use rustler::NifStruct;

#[derive(Debug, NifStruct)]
#[module = "HexaRail.Domain.Resource"]
pub struct Resource {
    pub id: i64,
    pub name: String,
    pub capacity: i64,
}

#[derive(Debug, NifStruct)]
#[module = "HexaRail.Domain.Job"]
pub struct Job {
    pub id: i64,
    pub duration: i64,
    pub required_resources: Vec<i64>,
    pub start_time: Option<i64>,
}

#[derive(Debug, NifStruct)]
#[module = "HexaRail.Domain.Problem"]
pub struct Problem {
    pub id: String,
    pub resources: Vec<Resource>,
    pub jobs: Vec<Job>,
}
```
2. Link the module in `hexarail/native/hexa_solver/src/lib.rs`:
```rust
#![deny(warnings)]
#![deny(clippy::all)]
#![deny(clippy::pedantic)]

pub mod domain;

#[rustler::nif]
fn add(a: i64, b: i64) -> i64 {
    a + b
}

rustler::init!("Elixir.HexaRail.SolverNif", [add]);
```

**Step 4: Run test to verify it passes**

Run: `nix develop -c bash -c "cd hexarail/native/hexa_solver && cargo test && cargo clippy -- -D warnings"`
Expected: PASS

**Step 5: Commit**

```bash
git add hexarail/native/hexa_solver/
git commit -m "feat(domain): replicate immutable digital twin domain entities in rust"
```

---

### Task 2: Implement the Rust Score Calculator (First Constraint)

**Files:**
- Create: `hexarail/native/hexa_solver/src/score.rs`
- Modify: `hexarail/native/hexa_solver/src/lib.rs`

**Step 1: Write the failing test**

```rust
// hexarail/native/hexa_solver/src/score.rs
use crate::domain::{Job, Problem, Resource};

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_unassigned_job_penalty() {
        let j1 = Job { id: 1, duration: 10, required_resources: vec![], start_time: None }; // Unassigned
        let problem = Problem { id: "1".to_string(), resources: vec![], jobs: vec![j1] };
        
        let score = calculate_score(&problem);
        assert_eq!(score, -100); // Hard penalty for unassigned jobs
    }
}
```

**Step 2: Run test to verify it fails**

Run: `nix develop -c bash -c "cd hexarail/native/hexa_solver && cargo test"`
Expected: FAIL (Function `calculate_score` not found)

**Step 3: Write minimal implementation**

1. Create `hexarail/native/hexa_solver/src/score.rs`:
```rust
use crate::domain::Problem;

#[must_use]
pub fn calculate_score(problem: &Problem) -> i64 {
    let mut score = 0;

    // Constraint 1: Unassigned Job Penalty
    for job in &problem.jobs {
        if job.start_time.is_none() {
            score -= 100;
        }
    }

    score
}
```
2. Expose it in `hexarail/native/hexa_solver/src/lib.rs`:
```rust
#![deny(warnings)]
#![deny(clippy::all)]
#![deny(clippy::pedantic)]

pub mod domain;
pub mod score;

#[rustler::nif]
fn evaluate_problem(problem: domain::Problem) -> i64 {
    score::calculate_score(&problem)
}

#[rustler::nif]
fn add(a: i64, b: i64) -> i64 {
    a + b
}

rustler::init!("Elixir.HexaRail.SolverNif", [add, evaluate_problem]);
```

**Step 4: Run test to verify it passes**

Run: `nix develop -c bash -c "cd hexarail/native/hexa_solver && cargo test && cargo clippy -- -D warnings"`
Expected: PASS

**Step 5: Commit**

```bash
git add hexarail/native/hexa_solver/
git commit -m "feat(solver): implement base score calculation in pure rust"
```

---

### Task 3: Bridge the Scoring Engine to Elixir

**Files:**
- Modify: `hexarail/lib/hexarail/solver_nif.ex`
- Create: `hexarail/test/solver_integration_test.exs`

**Step 1: Write the failing test**

```elixir
# hexarail/test/solver_integration_test.exs
defmodule HexaRail.SolverIntegrationTest do
  use ExUnit.Case
  alias HexaRail.Domain.{Problem, Job}
  alias HexaRail.SolverNif

  test "rust nif calculates penalty for unassigned jobs" do
    problem = %Problem{
      id: "sim_1",
      resources: [],
      jobs: [
        %Job{id: 1, duration: 10, required_resources: [], start_time: nil},
        %Job{id: 2, duration: 10, required_resources: [], start_time: 50}
      ]
    }

    # Should be -100 because 1 job is unassigned
    assert SolverNif.evaluate_problem(problem) == -100
  end
end
```

**Step 2: Run test to verify it fails**

Run: `nix develop -c bash -c "cd hexarail && mix test test/solver_integration_test.exs"`
Expected: FAIL (Undefined function `evaluate_problem/1`)

**Step 3: Write minimal implementation**

1. Update `hexarail/lib/hexarail/solver_nif.ex`:
```elixir
defmodule HexaRail.SolverNif do
  @moduledoc false
  use Rustler, otp_app: :hexarail, crate: "hexa_solver"

  def add(_a, _b), do: :erlang.nif_error(:nif_not_loaded)
  
  @spec evaluate_problem(HexaRail.Domain.Problem.t()) :: integer()
  def evaluate_problem(_problem), do: :erlang.nif_error(:nif_not_loaded)
end
```

**Step 4: Run test to verify it passes**

Run: `nix develop -c bash -c "cd hexarail && mix test test/solver_integration_test.exs"`
Expected: PASS

Run Quality Gates: `nix develop -c bash -c "cd hexarail && mix credo --strict && mix dialyzer"`

**Step 5: Commit**

```bash
git add hexarail/
git commit -m "feat(bridge): connect elixir domain structures to rust scoring engine"
```