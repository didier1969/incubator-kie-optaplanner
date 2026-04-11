# Mission 1: Annihilation of the "Fail-Silent" Anti-Pattern Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Eradicate all `unwrap_or_else` silent failures in the `gnn.rs` tensor operations and propagate them as `Result<Vec<f32>, String>` back across the NIF boundary to Elixir.

**Architecture:** We will change the return type of `NcoInferenceEngine::forward_pass` and `forward` to use `candle_core::Result`. Any tensor mismatch will return an `Err`. The NIF `optimize_problem_core` will catch this `Err` and return it as an `{:error, reason}` tuple to Elixir, halting the execution safely instead of optimizing on zeroed tensors.

**Tech Stack:** Rust (`candle-core`, `rustler`), Elixir.

---

### Task 1: Refactor `gnn.rs` to propagate Candle Errors

**Files:**
- Modify: `hexarail/native/hexacore_logic/src/gnn.rs`

**Step 1: Write the minimal implementation (Rust compiler acts as the test)**

*In `gnn.rs`:*
Change `forward_pass` signature:
```rust
pub fn forward_pass(&self, tensor_data: &TensorData) -> candle_core::Result<Vec<f32>> {
    // ...
```

Inside `forward_pass`, replace all `unwrap_or_else(|_| Tensor::zeros(...).unwrap())` with `?`. For instance:
```rust
let x_jobs = Tensor::from_vec(job_features_flat, (num_jobs, 9), &self.device)?;
// ...
let output_tensor = self.model.forward(&input_tensor)?;
// ...
output_tensor.flatten_all()?.to_vec1::<f32>()
```
Also handle empty vectors properly by returning `Ok(vec![])`.

**Step 2: Run clippy to verify it fails in the engine/solver (because they expect Vec<f32>)**

Run: `nix develop --command bash -c "cd hexarail && cargo clippy --manifest-path native/Cargo.toml --all-targets --all-features -- -D warnings"`
Expected: FAIL in `solver.rs` and `hexacore_engine/src/lib.rs` where `forward_pass` is called.

**Step 3: Commit**
```bash
git add hexarail/native/hexacore_logic/src/gnn.rs
git commit -m "refactor(mlops): propagate candle tensor errors in GNN forward pass"
```

### Task 2: Update Solver and Engine to handle GNN Errors

**Files:**
- Modify: `hexarail/native/hexacore_engine/src/lib.rs`
- Modify: `hexarail/native/hexacore_logic/src/solver.rs` (if necessary, though the engine handles the extraction)

**Step 1: Write the minimal implementation**

*In `hexacore_engine/src/lib.rs`:*
```rust
        "nco" => {
            let encoder = hexacore_logic::nco::FeatureEncoder::new();
            let brain = hexacore_logic::gnn::NcoInferenceEngine::new();

            let guidance = if let Ok(tensor_data) = encoder.encode(&problem, 0.0) {
                // SOTA: Catch the error and propagate to Elixir
                match brain.forward_pass(&tensor_data) {
                    Ok(probs) => Some(probs),
                    Err(e) => return Err(rustler::Error::RaiseTerm(Box::new(e.to_string()))),
                }
            } else {
                None
            };

            let optimized = hexacore_logic::optimize_problem_core(problem, iterations, guidance);

            Ok(optimized)
        },
```

**Step 2: Run clippy to verify it passes**

Run: `nix develop --command bash -c "cd hexarail && cargo clippy --manifest-path native/Cargo.toml --all-targets --all-features -- -D warnings"`
Expected: PASS

**Step 3: Commit**
```bash
git add hexarail/native/hexacore_engine/src/lib.rs
git commit -m "fix(mlops): halt optimization and return error to Elixir on GNN failure"
```