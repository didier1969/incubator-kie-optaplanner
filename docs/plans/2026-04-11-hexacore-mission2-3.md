# Mission 2 & 3: SOTA Supremacy Protocol Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Eradicate the final hardcoded hyperparameters in the LAHC solver and implement a robust `.safetensors` model loader for the Candle GNN.

**Architecture:** 
1. Create a `SolverConfig` struct in Rust and Elixir to pass hyperparameters (LAHC history, move probabilities, shift window) dynamically through the NIF boundary.
2. Update the `NcoInferenceEngine` to attempt loading `nco_model.safetensors` using `VarBuilder::from_mmaped_safetensors`, falling back to random weights with a loud warning if the file is missing.

**Tech Stack:** Rust (`candle-core`, `rustler`), Elixir.

---

### Task 1: Create SolverConfig and Update NIF Boundary

**Files:**
- Modify: `hexarail/native/hexacore_logic/src/domain.rs`
- Modify: `hexarail/native/hexacore_logic/src/solver.rs`
- Modify: `hexarail/native/hexacore_logic/src/lib.rs`
- Modify: `hexarail/native/hexacore_engine/src/lib.rs`
- Create: `hexarail/lib/hexacore/domain/solver_config.ex`

**Step 1: Write the minimal implementation in Rust**

*In `hexacore_logic/src/domain.rs`:*
Add the struct:
```rust
#[derive(Debug, Clone, NifStruct)]
#[module = "HexaCore.Domain.SolverConfig"]
pub struct SolverConfig {
    pub lahc_history_size: usize,
    pub swap_move_prob: u8,
    pub shift_move_prob: u8,
    pub shift_window: i32,
}

impl Default for SolverConfig {
    fn default() -> Self {
        Self {
            lahc_history_size: 100,
            swap_move_prob: 20,
            shift_move_prob: 40,
            shift_window: 120,
        }
    }
}
```

*In `hexacore_logic/src/solver.rs`:*
Remove `const LAHC_HISTORY_SIZE: usize = 100;`.
Update `optimize` signature:
```rust
pub fn optimize(
    mut current_problem: Problem,
    _total_conflicts: usize,
    iterations: i32,
    guidance: Option<Vec<f32>>,
    config: &crate::domain::SolverConfig,
) -> Problem {
```
Replace hardcoded values with `config.lahc_history_size`, `config.swap_move_prob`, `config.shift_move_prob`, and `config.shift_window`.

*In `hexacore_logic/src/lib.rs`:*
Update `optimize_problem_core`:
```rust
pub fn optimize_problem_core(
    problem: domain::Problem, 
    iterations: i32, 
    guidance: Option<Vec<f32>>,
    config: &domain::SolverConfig,
) -> domain::Problem 
{
    solver::optimize(problem, 0, iterations, guidance, config)
}
```

*In `hexacore_engine/src/lib.rs`:*
Update the NIF signature and calls:
```rust
#[rustler::nif]
pub fn optimize_problem_core(
    problem: domain::Problem,
    strategy: String,
    iterations: i32,
    config: domain::SolverConfig,
) -> Result<domain::Problem, rustler::Error> {
    match strategy.as_str() {
        "metaheuristic" => Ok(hexacore_logic::optimize_problem_core(problem, iterations, None, &config)),
        "nco" => {
            // ...
            let optimized = hexacore_logic::optimize_problem_core(problem, iterations, guidance, &config);
            Ok(optimized)
        },
        _ => Err(rustler::Error::BadArg),
    }
}
```

*In `hexarail/lib/hexacore/domain/solver_config.ex`:*
```elixir
defmodule HexaCore.Domain.SolverConfig do
  defstruct lahc_history_size: 100, swap_move_prob: 20, shift_move_prob: 40, shift_window: 120
  @type t :: %__MODULE__{}
end
```

**Step 2: Run clippy to verify it compiles**
Run: `nix develop --command bash -c "cd hexarail && cargo clippy --manifest-path native/Cargo.toml --all-targets --all-features -- -D warnings"`

**Step 3: Commit**
```bash
git add hexarail/native/hexacore_logic/src/domain.rs hexarail/native/hexacore_logic/src/solver.rs hexarail/native/hexacore_logic/src/lib.rs hexarail/native/hexacore_engine/src/lib.rs hexarail/lib/hexacore/domain/solver_config.ex
git commit -m "feat(core): implement dynamic SolverConfig injection for hyperparameter tuning"
```

### Task 2: Update Elixir Tests and Facade to use SolverConfig

**Files:**
- Modify: `hexarail/lib/hexafactory/solver/facade.ex`
- Modify: `hexarail/test/hexacore/core_solver_test.exs`
- Modify: `hexarail/test/solver_integration_test.exs`

**Step 1: Write the minimal implementation**

*In `facade.ex`:*
```elixir
    config = %HexaCore.Domain.SolverConfig{}
    solved_problem =
      dataset
      |> ProblemProjection.build()
      |> Nif.optimize_problem_core("metaheuristic", iterations, config)
```
Update `Nif.optimize_problem_core` signature in `native.ex` if needed.

*In tests:*
Add `%HexaCore.Domain.SolverConfig{}` as the 4th argument to `Nif.optimize_problem_core`.

**Step 2: Run tests to verify**
Run: `nix develop --command bash -c "cd hexarail && mix test"`

**Step 3: Commit**
```bash
git add hexarail/lib/hexafactory/solver/facade.ex hexarail/test/
git commit -m "test: align Elixir tests and facade with new SolverConfig boundary"
```

### Task 3: The MLOps Reality Bridge (Safetensors)

**Files:**
- Modify: `hexarail/native/hexacore_logic/src/gnn.rs`

**Step 1: Write the minimal implementation**

*In `gnn.rs`:*
Update `NcoInferenceEngine::default`:
```rust
    fn default() -> Self {
        let device = Device::Cpu;
        
        let (varmap, vb) = if std::path::Path::new("nco_model.safetensors").exists() {
            let mut varmap = VarMap::new();
            varmap.load("nco_model.safetensors").unwrap();
            let vb = VarBuilder::from_varmap(&varmap, DType::F32, &device);
            (varmap, vb)
        } else {
            println!("WARNING: Running with uninitialized SOTA brain (random weights). Train a model and place 'nco_model.safetensors' in the working directory.");
            let varmap = VarMap::new();
            let vb = VarBuilder::from_varmap(&varmap, DType::F32, &device);
            (varmap, vb)
        };
        
        let model = NcoBrain::new(vb).expect("Failed to initialize NcoBrain");

        Self { device, model, _varmap: varmap }
    }
```

**Step 2: Run clippy and tests**
Run: `nix develop --command bash -c "cd hexarail && cargo clippy --manifest-path native/Cargo.toml --all-targets --all-features -- -D warnings && mix test"`

**Step 3: Commit**
```bash
git add hexarail/native/hexacore_logic/src/gnn.rs
git commit -m "feat(mlops): implement robust safetensors model loader with graceful fallback"
```