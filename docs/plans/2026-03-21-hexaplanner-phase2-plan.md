# HexaPlanner Phase 2 Implementation Plan: Core Domain & Database

> **For Claude/Gemini:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Configure PostgreSQL via Ecto and establish the core immutable data structures for the Digital Twin (Jobs, Resources, Constraints) that will be fed to the Rust solver. Finally, activate the Oban job queue.

**Architecture:** Elixir Ecto (Database) -> Immutable Elixir Structs -> (Future) Rustler ETF.

**Tech Stack:** Elixir, Ecto, PostgreSQL, Oban.

---

### Task 1: Setup Ecto and PostgreSQL Configuration

**Files:**
- Modify: `hexaplanner/mix.exs`
- Modify: `hexaplanner/lib/hexaplanner/application.ex`
- Create: `hexaplanner/config/config.exs`
- Create: `hexaplanner/config/dev.exs`
- Create: `hexaplanner/config/test.exs`
- Create: `hexaplanner/lib/hexaplanner/repo.ex`

**Step 1: Write the failing check**

Run: `nix develop -c bash -c "cd hexaplanner && mix ecto.create"`
Expected: FAIL (No mix.exs task for Ecto or missing Repo)

**Step 2: Write minimal implementation**

1. Add `:ecto_sql` and `:postgrex` to `mix.exs` deps:
```elixir
{:ecto_sql, "== 3.11.1"},
{:postgrex, "== 0.17.5"}
```
2. Download deps: `mix deps.get`
3. Create `lib/hexaplanner/repo.ex`:
```elixir
defmodule HexaPlanner.Repo do
  use Ecto.Repo,
    otp_app: :hexaplanner,
    adapter: Ecto.Adapters.Postgres
end
```
4. Add Ecto setup aliases in `mix.exs`:
```elixir
  defp aliases do
    [
      "ecto.setup": ["ecto.create", "ecto.migrate", "run priv/repo/seeds.exs"],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      test: ["ecto.create --quiet", "ecto.migrate --quiet", "test"]
    ]
  end
```
5. Setup `config/config.exs`:
```elixir
import Config
config :hexaplanner, ecto_repos: [HexaPlanner.Repo]
import_config "#{config_env()}.exs"
```
6. Setup `config/dev.exs`:
```elixir
import Config
config :hexaplanner, HexaPlanner.Repo,
  username: "postgres",
  password: "postgres_password",
  hostname: "localhost",
  database: "hexaplanner_dev",
  stacktrace: true,
  show_sensitive_data_on_connection_error: true,
  pool_size: 10
```
7. Setup `config/test.exs`:
```elixir
import Config
config :hexaplanner, HexaPlanner.Repo,
  username: "postgres",
  password: "postgres_password",
  hostname: "localhost",
  database: "hexaplanner_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: 10
```
8. Add `HexaPlanner.Repo` to the supervision tree in `lib/hexaplanner/application.ex` (put it FIRST in the children list).

**Step 3: Run check to verify it passes**
*(Note: Requires a running Postgres instance. We will assume standard local dev PG is running).*
Run: `nix develop -c bash -c "cd hexaplanner && mix ecto.create"`
Expected: PASS

**Step 4: Commit**

```bash
git add hexaplanner/
git commit -m "feat(db): configure ecto and postgres for immutable domain persistence"
```

---

### Task 2: Activate the Oban Distributed Queue

**Files:**
- Modify: `hexaplanner/lib/hexaplanner/application.ex`
- Modify: `hexaplanner/config/config.exs`

**Step 1: Write the failing check**

Run: `nix develop -c bash -c "cd hexaplanner && mix test"`
Expected: Pass for Horde, but we need a test for Oban now.

Add to `hexaplanner/test/infrastructure_test.exs`:
```elixir
  test "Oban is running in the supervision tree" do
    assert Process.whereis(Oban) != nil
  end
```
Run `mix test`. Expected: FAIL.

**Step 2: Write minimal implementation**

1. Generate Oban migration: `nix develop -c bash -c "cd hexaplanner && mix ecto.gen.migration add_oban_jobs_table"`
2. Modify the migration file to use `Oban.Migration.up/down`:
```elixir
defmodule HexaPlanner.Repo.Migrations.AddObanJobsTable do
  use Ecto.Migration
  def up, do: Oban.Migration.up(version: 12)
  def down, do: Oban.Migration.down(version: 1)
end
```
3. Add Oban config to `config.exs`:
```elixir
config :hexaplanner, Oban,
  repo: HexaPlanner.Repo,
  plugins: [Oban.Plugins.Pruner],
  queues: [default: 10, solver: 16] # solver queue maps to 16 cores
```
4. Add `{Oban, Application.fetch_env!(:hexaplanner, :Oban)}` to the supervision tree in `lib/hexaplanner/application.ex` (AFTER the Repo).

**Step 3: Run check to verify it passes**

Run: `nix develop -c bash -c "cd hexaplanner && mix ecto.migrate && mix test"`
Expected: PASS (Oban is running)

**Step 4: Commit**

```bash
git add hexaplanner/
git commit -m "feat(orchestration): activate oban queue for distributing rust solver tasks"
```

---

### Task 3: Model the Core Digital Twin Entities (Problem, Job, Resource)

**Files:**
- Create: `hexaplanner/lib/hexaplanner/domain/resource.ex`
- Create: `hexaplanner/lib/hexaplanner/domain/job.ex`
- Create: `hexaplanner/lib/hexaplanner/domain/problem.ex`
- Test: `hexaplanner/test/domain_test.exs`

**Step 1: Write the failing test**

```elixir
# hexaplanner/test/domain_test.exs
defmodule HexaPlanner.DomainTest do
  use ExUnit.Case
  alias HexaPlanner.Domain.{Problem, Job, Resource}

  test "a problem can be modeled immutably" do
    r1 = %Resource{id: 1, name: "Machine A", capacity: 1}
    j1 = %Job{id: 100, duration: 60, required_resources: [1]}
    
    problem = %Problem{id: "sim_1", resources: [r1], jobs: [j1]}
    assert length(problem.jobs) == 1
  end
end
```

**Step 2: Run test to verify it fails**

Run: `nix develop -c bash -c "cd hexaplanner && mix test test/domain_test.exs"`
Expected: FAIL (Undefined modules)

**Step 3: Write minimal implementation**

We define these as `Ecto.Schema` (embedded or backed by tables) to ensure strict typing.

1. `lib/hexaplanner/domain/resource.ex`:
```elixir
defmodule HexaPlanner.Domain.Resource do
  @moduledoc "A physical asset in the factory/network."
  use Ecto.Schema

  @primary_key {:id, :id, autogenerate: true}
  schema "resources" do
    field :name, :string
    field :capacity, :integer, default: 1
    # future: location/topology links
    timestamps()
  end
end
```

2. `lib/hexaplanner/domain/job.ex`:
```elixir
defmodule HexaPlanner.Domain.Job do
  @moduledoc "A task to be scheduled."
  use Ecto.Schema

  @primary_key {:id, :id, autogenerate: true}
  schema "jobs" do
    field :duration, :integer # in minutes/ticks
    field :required_resources, {:array, :integer} # IDs of needed resources
    # Planning Variables (to be filled by Rust)
    field :start_time, :integer
    timestamps()
  end
end
```

3. `lib/hexaplanner/domain/problem.ex`:
```elixir
defmodule HexaPlanner.Domain.Problem do
  @moduledoc "The root aggregate holding the entire Twin state."
  defstruct [:id, resources: [], jobs: []]
  
  @type t :: %__MODULE__{
    id: String.t(),
    resources: list(HexaPlanner.Domain.Resource.t()),
    jobs: list(HexaPlanner.Domain.Job.t())
  }
end
```

**Step 4: Run test to verify it passes**

Run: `nix develop -c bash -c "cd hexaplanner && mix test test/domain_test.exs"`
Expected: PASS

**Step 5: Commit**

```bash
git add hexaplanner/
git commit -m "feat(domain): establish immutable data structures for digital twin state"
```