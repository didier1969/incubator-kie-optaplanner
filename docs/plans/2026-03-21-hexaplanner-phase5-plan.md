# HexaPlanner Phase 5 Implementation Plan: The Metaprogramming DSL (Elixir -> Rust)

> **For Claude/Gemini:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Implement the MVP of the Metaprogramming Transpiler. We will create an Elixir DSL (`defconstraint`) that captures business rules as an Abstract Syntax Tree (AST), and a Transpiler that converts this AST into highly optimized, hard-coded Rust iterators written to the Rust project before compilation.

**Architecture:** Elixir Macro (DSL) -> Elixir Rule Structs -> Rust String Generator -> File Emitter -> Rustler Compile.

**Tech Stack:** Elixir (Macros), Rust.

---

### Task 1: Create the Elixir DSL Front-End

**Files:**
- Create: `hexaplanner/lib/hexaplanner/dsl/rule.ex`
- Create: `hexaplanner/lib/hexaplanner/dsl.ex`
- Test: `hexaplanner/test/dsl_test.exs`

**Step 1: Write the failing test**

```elixir
# hexaplanner/test/dsl_test.exs
defmodule HexaPlanner.DSLTest do
  use ExUnit.Case

  defmodule MyRules do
    use HexaPlanner.DSL

    defconstraint "unassigned_job" do
      match(:job, :start_time, :is_nil)
      penalize(:hard, 100)
    end
  end

  test "DSL parses constraints into AST structs" do
    rules = MyRules.__rules__()
    assert length(rules) == 1
    rule = hd(rules)
    
    assert rule.name == "unassigned_job"
    assert rule.entity == :job
    assert rule.field == :start_time
    assert rule.condition == :is_nil
    assert rule.penalty_type == :hard
    assert rule.penalty_score == 100
  end
end
```

**Step 2: Run test to verify it fails**

Run: `nix develop -c bash -c "cd hexaplanner && mix test test/dsl_test.exs"`
Expected: FAIL (Undefined module HexaPlanner.DSL)

**Step 3: Write minimal implementation**

1. Create `hexaplanner/lib/hexaplanner/dsl/rule.ex`:
```elixir
defmodule HexaPlanner.DSL.Rule do
  @moduledoc "Represents a parsed business rule constraint."
  @type t :: %__MODULE__{
          name: String.t(),
          entity: atom(),
          field: atom(),
          condition: atom(),
          penalty_type: atom(),
          penalty_score: integer()
        }
  defstruct [:name, :entity, :field, :condition, :penalty_type, :penalty_score]
end
```

2. Create `hexaplanner/lib/hexaplanner/dsl.ex`:
```elixir
defmodule HexaPlanner.DSL do
  @moduledoc "Macros for defining Digital Twin constraints."
  alias HexaPlanner.DSL.Rule

  defmacro __using__(_opts) do
    quote do
      import HexaPlanner.DSL
      Module.register_attribute(__MODULE__, :rules, accumulate: true)
      @before_compile HexaPlanner.DSL
    end
  end

  defmacro __before_compile__(env) do
    rules = Module.get_attribute(env.module, :rules) |> Enum.reverse()
    quote do
      def __rules__, do: unquote(Macro.escape(rules))
    end
  end

  defmacro defconstraint(name, do: block) do
    # Extremely simplified parser for the MVP
    {:__block__, _, [match_ast, penalize_ast]} = block
    {:match, _, [entity, field, condition]} = match_ast
    {:penalize, _, [type, score]} = penalize_ast

    quote do
      @rules %Rule{
        name: unquote(name),
        entity: unquote(entity),
        field: unquote(field),
        condition: unquote(condition),
        penalty_type: unquote(type),
        penalty_score: unquote(score)
      }
    end
  end
end
```

**Step 4: Run test to verify it passes**

Run: `nix develop -c bash -c "cd hexaplanner && mix test test/dsl_test.exs"`
Expected: PASS

**Step 5: Commit**

```bash
git add hexaplanner/
git commit -m "feat(dsl): implement elixir macros to parse constraints into ast"
```

---

### Task 2: Implement the Rust Transpiler

**Files:**
- Create: `hexaplanner/lib/hexaplanner/transpiler/rust_generator.ex`
- Test: `hexaplanner/test/transpiler_test.exs`

**Step 1: Write the failing test**

```elixir
# hexaplanner/test/transpiler_test.exs
defmodule HexaPlanner.TranspilerTest do
  use ExUnit.Case
  alias HexaPlanner.DSL.Rule
  alias HexaPlanner.Transpiler.RustGenerator

  test "generates valid rust iterator code from rule struct" do
    rule = %Rule{
      name: "unassigned_job",
      entity: :job,
      field: :start_time,
      condition: :is_nil,
      penalty_type: :hard,
      penalty_score: 100
    }

    rust_code = RustGenerator.generate([rule])
    
    assert rust_code =~ "pub fn calculate_generated_score"
    assert rust_code =~ "for job in &problem.jobs {"
    assert rust_code =~ "if job.start_time.is_none() {"
    assert rust_code =~ "score -= 100;"
  end
end
```

**Step 2: Run test to verify it fails**

Run: `nix develop -c bash -c "cd hexaplanner && mix test test/transpiler_test.exs"`
Expected: FAIL (Undefined module)

**Step 3: Write minimal implementation**

Create `hexaplanner/lib/hexaplanner/transpiler/rust_generator.ex`:
```elixir
defmodule HexaPlanner.Transpiler.RustGenerator do
  @moduledoc "Translates DSL Rule ASTs into pure Rust code."
  alias HexaPlanner.DSL.Rule

  @spec generate(list(Rule.t())) :: String.t()
  def generate(rules) do
    loops = Enum.map_join(rules, "\n", &generate_rule/1)

    """
    // AUTO-GENERATED BY HEXAPLANNER TRANSPILER
    // DO NOT EDIT MANUALLY

    use crate::domain::Problem;

    #[must_use]
    pub fn calculate_generated_score(problem: &Problem) -> i64 {
        let mut score = 0;

        #{loops}

        score
    }
    """
  end

  defp generate_rule(%Rule{entity: :job, field: :start_time, condition: :is_nil, penalty_score: score}) do
    """
        for job in &problem.jobs {
            if job.start_time.is_none() {
                score -= #{score};
            }
        }
    """
  end
  
  # Fallback for unsupported rules in MVP
  defp generate_rule(_), do: ""
end
```

**Step 4: Run test to verify it passes**

Run: `nix develop -c bash -c "cd hexaplanner && mix test test/transpiler_test.exs"`
Expected: PASS

**Step 5: Commit**

```bash
git add hexaplanner/
git commit -m "feat(transpiler): implement elixir to rust code generator for constraints"
```

---

### Task 3: The File Emitter and Quality Gates

**Files:**
- Create: `hexaplanner/lib/hexaplanner/transpiler/emitter.ex`

**Step 1: Write the failing check**

We need to ensure the emitter writes the file to the correct Rust directory.
Run: `nix develop -c bash -c "cd hexaplanner && mix run -e 'HexaPlanner.Transpiler.Emitter.emit([])'"`
Expected: FAIL (Undefined module)

**Step 2: Write minimal implementation**

Create `hexaplanner/lib/hexaplanner/transpiler/emitter.ex`:
```elixir
defmodule HexaPlanner.Transpiler.Emitter do
  @moduledoc "Writes the generated Rust code to the native file system."
  alias HexaPlanner.Transpiler.RustGenerator

  @target_path "native/hexa_solver/src/generated_score.rs"

  @spec emit(list(HexaPlanner.DSL.Rule.t())) :: :ok
  def emit(rules) do
    rust_code = RustGenerator.generate(rules)
    File.write!(@target_path, rust_code)
    :ok
  end
end
```

**Step 3: Run check to verify it passes**

Run: `nix develop -c bash -c "cd hexaplanner && mix run -e 'HexaPlanner.Transpiler.Emitter.emit([])'"`
Verify file exists: `cat hexaplanner/native/hexa_solver/src/generated_score.rs`
Expected: PASS (File contains AUTO-GENERATED header).

Run Quality Gates: `nix develop -c bash -c "cd hexaplanner && mix credo --strict && mix dialyzer"`

**Step 4: Commit**

```bash
git add hexaplanner/
git commit -m "feat(transpiler): implement file emitter to write generated rust code"
```