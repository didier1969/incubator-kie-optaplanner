# HexaCore API Boundary Slice Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Prove a first real `HexaCore` execution path that scores and optimizes a generic problem without any railway resource or GTFS/OSM types.

**Architecture:** Keep the current NIF crate in place, but cut the first reusable seam inside the solver path. `HexaCore` gets explicit core-only NIF entrypoints for evaluation and optimization, while the existing resource-backed railway path continues to source conflict data from the rail topology manager. This makes the core solver callable without `HexaRail` while avoiding a premature crate split.

**Tech Stack:** Elixir, Rustler NIF, Rust, ExUnit, Cargo tests

---

### Task 1: Add the failing proof test

**Files:**
- Create: `hexarail/test/hexacore/core_solver_test.exs`

**Step 1: Write the failing test**

Create an ExUnit test that:
- aliases only `HexaCore.Domain.{Job, Problem}` and `HexaCore.Nif`
- builds a generic scheduling problem with one unassigned job
- asserts `HexaCore.Nif.evaluate_problem_core/1 == -100`
- asserts `HexaCore.Nif.optimize_problem_core/2` returns a problem with assigned start time and score `0`

**Step 2: Run test to verify it fails**

Run:

```bash
bash -lc 'export HOME=/tmp/codex-nix-home; export XDG_CACHE_HOME=/tmp/codex-xdg-cache; mkdir -p "$HOME" "$XDG_CACHE_HOME"; nix develop -c bash -lc "cd hexarail && mix test test/hexacore/core_solver_test.exs"'
```

Expected: `UndefinedFunctionError` or compile error because the core-only NIF entrypoints do not exist yet.

### Task 2: Add core-only NIF entrypoints

**Files:**
- Modify: `hexarail/lib/hexacore/nif.ex`
- Modify: `hexarail/native/hexacore_engine/src/lib.rs`

**Step 1: Add Elixir stubs**

Declare:
- `evaluate_problem_core/1`
- `optimize_problem_core/2`

**Step 2: Add Rust NIF functions**

Implement:
- `evaluate_problem_core(problem)`
- `optimize_problem_core(problem, iterations)`

These functions must not depend on railway resource state.

### Task 3: Decouple the generic solver kernel from railway topology

**Files:**
- Modify: `hexarail/native/hexacore_engine/src/score.rs`
- Modify: `hexarail/native/hexacore_engine/src/solver.rs`

**Step 1: Introduce a generic score seam**

Refactor score calculation so the generic job penalty path no longer requires `NetworkManager`.

**Step 2: Preserve railway-backed scoring**

Keep the existing resource-backed NIF functions working by passing conflict count from the railway manager into the generic score/solver path.

**Step 3: Update Rust unit tests**

Adjust or add Rust tests so the generic kernel is tested without importing railway topology code.

### Task 4: Validate both core and railway paths

**Files:**
- Test: `hexarail/test/hexacore/core_solver_test.exs`
- Test: existing railway integration tests

**Step 1: Run the new core proof test**

Run:

```bash
bash -lc 'export HOME=/tmp/codex-nix-home; export XDG_CACHE_HOME=/tmp/codex-xdg-cache; mkdir -p "$HOME" "$XDG_CACHE_HOME"; nix develop -c bash -lc "cd hexarail && mix test test/hexacore/core_solver_test.exs"'
```

Expected: PASS

**Step 2: Run targeted regression tests**

Run:

```bash
bash -lc 'export HOME=/tmp/codex-nix-home; export XDG_CACHE_HOME=/tmp/codex-xdg-cache; mkdir -p "$HOME" "$XDG_CACHE_HOME"; nix develop -c bash -lc "cd hexarail && mix test test/solver_integration_test.exs test/solver_nif_test.exs"'
```

and

```bash
bash -lc 'export HOME=/tmp/codex-nix-home; export XDG_CACHE_HOME=/tmp/codex-xdg-cache; mkdir -p "$HOME" "$XDG_CACHE_HOME"; nix develop -c bash -lc "cd hexarail && cargo test --manifest-path native/hexacore_engine/Cargo.toml score solver -- --nocapture"'
```

Expected: PASS

### Task 5: Document the architectural slice and prepare commit

**Files:**
- Modify: `docs/plans/2026-03-25-core-agnostic-refactoring-plan.md`

**Step 1: Record the slice**

Add a note that the first proven API-boundary slice is the core-only score/optimize path without railway resource dependency.

**Step 2: Prepare commit**

Use a focused conventional commit covering only the files touched by this slice.
