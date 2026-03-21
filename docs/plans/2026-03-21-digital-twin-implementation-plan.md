# HexaPlanner Phase 1 Implementation Plan

> **For Claude/Gemini:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Scaffold the core Elixir application (Control Plane) and establish the native bridge to the Rust environment (Data Plane) via Rustler, implementing a pure Elixir/Rust architecture without Java.

**Architecture:** We are creating an umbrella Elixir application or a standard Phoenix application that includes a native Rust NIF (Native Implemented Function). Rust will handle both score calculation and the multi-stage heuristic/genetic search.

**Tech Stack:** Elixir, Erlang/BEAM, Rust, Rustler, Phoenix LiveView (for benchmarking).

---

### Task 0: Scaffold the Reproductible Development Environment (Nix)

**Files:**
- Create: `flake.nix`
- Create: `.envrc`

**Step 1: Write the failing check**

We expect the environment to lack a reproducible Nix flake.
Run: `nix flake check`
Expected: FAIL (No flake.nix found)

**Step 2: Write minimal implementation**

1. Create a `flake.nix` file that locks specific versions of Erlang, Elixir, and Rust (Cargo) using nixpkgs from early 2026 (or a stable channel). This guarantees all developers use the exact same compilers.
```nix
{
  description = "HexaPlanner Development Environment";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
      in
      {
        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            erlang_26
            elixir_1_16
            cargo
            rustc
            rustfmt
            clippy
            # Required for Rustler C FFI compilation
            gcc
          ];

          shellHook = ''
            echo "HexaPlanner Dev Environment loaded."
            echo "Elixir $(elixir --version | grep Elixir)"
            echo "Rust $(cargo --version)"
          '';
        };
      }
    );
}
```
2. Create `.envrc` for direnv integration:
```bash
use flake
```

**Step 3: Run check to verify it passes**

Run: `nix flake check` and optionally `nix develop --command bash -c "elixir --version && cargo --version"`
Expected: PASS (Compilers are available)

**Step 4: Commit**

```bash
git add flake.nix .envrc
git commit -m "chore(env): enforce reproducible compiler environment via nix flakes"
```

---

### Task 1: Scaffold the Elixir Control Plane

**Files:**
- Create: `hexaplanner/mix.exs`
- Create: `hexaplanner/lib/hexaplanner.ex`
- Test: `hexaplanner/test/hexaplanner_test.exs`

**Step 1: Write the failing test (Behavior Check)**

```elixir
# hexaplanner/test/hexaplanner_test.exs
defmodule HexaPlannerTest do
  use ExUnit.Case
  doctest HexaPlanner

  test "control plane application starts" do
    assert {:ok, _pid} = Application.ensure_all_started(:hexaplanner)
  end
end
```

**Step 2: Run test to verify it fails**

Run: `mix test` (in a temporary directory to verify lack of project)
Expected: FAIL (No mix.exs found)

**Step 3: Write minimal implementation**

Run the mix generator to scaffold the application:
```bash
mix new hexaplanner --sup
```
Ensure the `mix.exs` and `lib/hexaplanner.ex` exist.

**Step 4: Run test to verify it passes**

Run: `cd hexaplanner && mix test`
Expected: PASS

**Step 5: Commit**

```bash
git add hexaplanner/
git commit -m "chore(nexus): scaffold base elixir control plane application"
```

---

### Task 2: Integrate Rustler and Scaffold the Pure Rust Data Plane

**Files:**
- Modify: `hexaplanner/mix.exs`
- Create: `hexaplanner/native/hexa_solver/Cargo.toml`
- Create: `hexaplanner/native/hexa_solver/src/lib.rs`
- Create: `hexaplanner/lib/hexaplanner/solver_nif.ex`
- Test: `hexaplanner/test/solver_nif_test.exs`

**Step 1: Write the failing test**

```elixir
# hexaplanner/test/solver_nif_test.exs
defmodule HexaPlanner.SolverNifTest do
  use ExUnit.Case

  test "rustler bridge can add two numbers via pure rust solver" do
    assert HexaPlanner.SolverNif.add(2, 3) == 5
  end
end
```

**Step 2: Run test to verify it fails**

Run: `cd hexaplanner && mix test test/solver_nif_test.exs`
Expected: FAIL (Undefined module HexaPlanner.SolverNif)

**Step 3: Write minimal implementation**

1. Add `:rustler` to `mix.exs` dependencies (Strictly locked):
```elixir
# in mix.exs deps()
{:rustler, "== 0.35.0"}
```
2. Download deps: `mix deps.get`
3. Generate Rustler NIF: `mix rustler.new --name hexa_solver --module HexaPlanner.SolverNif`
4. Update `lib/hexaplanner/solver_nif.ex` to load the NIF:
```elixir
defmodule HexaPlanner.SolverNif do
  use Rustler, otp_app: :hexaplanner, crate: "hexa_solver"

  # When your NIF is loaded, it will override this function.
  def add(_a, _b), do: :erlang.nif_error(:nif_not_loaded)
end
```
5. Implement the addition in Rust (`native/hexa_solver/src/lib.rs`):
```rust
#[rustler::nif]
fn add(a: i64, b: i64) -> i64 {
    a + b
}

rustler::init!("Elixir.HexaPlanner.SolverNif", [add]);
```
6. Add optimization dependencies to `Cargo.toml` (e.g. `rayon`, `localsearch`, genetic algorithms). Strict versioning is mandated:
```toml
[dependencies]
rustler = "=0.35.0"
rayon = "=1.11.0"
localsearch = "=0.24.0" # State-of-the-art for parallel Tabu Search & Simulated Annealing
metaheuristics-nature = "=0.16.0" # For Genetic Algorithms & Swarm
```

**Step 4: Run test to verify it passes**

Run: `cd hexaplanner && mix test test/solver_nif_test.exs`
Expected: PASS (Rust compiles, NIF loads, test passes)

**Step 5: Commit**

```bash
git add hexaplanner/
git commit -m "feat(nexus): integrate rustler and establish pure elixir-rust bridge for multi-stage solver"
```

---

### Task 3: Integrate Ecosystem Standards (Oban & Horde)

**Files:**
- Modify: `hexaplanner/mix.exs`
- Modify: `hexaplanner/lib/hexaplanner/application.ex`

**Step 1: Write the failing test**

```elixir
# hexaplanner/test/infrastructure_test.exs
defmodule HexaPlanner.InfrastructureTest do
  use ExUnit.Case

  test "Horde is running in the supervision tree" do
    assert Process.whereis(HexaPlanner.HordeRegistry) != nil
    assert Process.whereis(HexaPlanner.HordeSupervisor) != nil
  end
end
```

**Step 2: Run test to verify it fails**

Run: `cd hexaplanner && mix test test/infrastructure_test.exs`
Expected: FAIL (Undefined modules)

**Step 3: Write minimal implementation**

1. Add `:oban` and `:horde` to `mix.exs` dependencies (Strictly locked):
```elixir
# in mix.exs deps()
{:oban, "== 2.18.0"},
{:horde, "== 0.9.0"}
```
2. Download deps: `mix deps.get`
3. Update `lib/hexaplanner/application.ex` to start the supervisors:
```elixir
def start(_type, _args) do
  children = [
    {Horde.Registry, [name: HexaPlanner.HordeRegistry, keys: :unique]},
    {Horde.DynamicSupervisor, [name: HexaPlanner.HordeSupervisor, strategy: :one_for_one]}
    # Oban will be added to the children here in the DB setup phase.
  ]
  opts = [strategy: :one_for_one, name: HexaPlanner.Supervisor]
  Supervisor.start_link(children, opts)
end
```

**Step 4: Run test to verify it passes**

Run: `cd hexaplanner && mix test test/infrastructure_test.exs`
*(Note: Oban requires Ecto/Repo setup which will be done in a subsequent DB phase, but the dependencies are now locked in).*

**Step 5: Commit**

```bash
git add hexaplanner/
git commit -m "feat(nexus): add horde and oban following the ecosystem reuse principle"
```

---

### Task 4: Enforce Zero-Tolerance Quality Gates (Linters & Static Analysis)

**Files:**
- Modify: `hexaplanner/mix.exs`
- Create: `hexaplanner/.credo.exs`
- Create: `hexaplanner/native/hexa_solver/rustfmt.toml`

**Step 1: Write the failing check (Quality Gate)**

We expect the default generated Elixir code to lack type specifications (specs) or trigger strict linter rules.
Run: `cd hexaplanner && mix credo --strict` and `cargo clippy --manifest-path native/hexa_solver/Cargo.toml -- -D warnings`

**Step 2: Write minimal implementation (Configuration)**

1. Add `:credo` and `:dialyxir` to `mix.exs` dependencies for Elixir quality:
```elixir
# in mix.exs deps()
{:credo, "== 1.7.5", only: [:dev, :test], runtime: false},
{:dialyxir, "== 1.4.3", only: [:dev, :test], runtime: false}
```
2. Download deps: `mix deps.get`
3. Generate strict Credo config: `mix credo.gen.config`
4. Enforce zero-warning Rust in `native/hexa_solver/src/lib.rs` by adding at the top of the file:
```rust
#![deny(warnings)]
#![deny(clippy::all)]
#![deny(clippy::pedantic)]
```
5. Run Dialyzer to build the initial PLT (this takes time but is mandatory): `mix dialyzer`

**Step 3: Fix any generated warnings**

Ensure all generated files (like `hexaplanner.ex` and `application.ex`) have `@moduledoc` and `@spec` where required by Credo/Dialyzer.

**Step 4: Run tests to verify Zero Warnings**

Run: `cd hexaplanner && mix test && mix credo --strict && mix dialyzer && cargo clippy --manifest-path native/hexa_solver/Cargo.toml`
Expected: All commands exit with status 0 (Success, Zero Warnings).

**Step 5: Commit**

```bash
git add hexaplanner/
git commit -m "chore(quality): enforce zero-tolerance policy with credo, dialyzer, and clippy"
```