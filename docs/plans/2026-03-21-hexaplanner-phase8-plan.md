# HexaPlanner Phase 8 Implementation Plan: Pipeline Open Data CFF (GTFS & PostGIS)

> **For Claude/Gemini:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Establish the foundational data ingestion pipeline for the ultimate CFF/SBB Digital Twin. We will upgrade our PostgreSQL database to support PostGIS (spatial queries), add the `geo_postgis` Elixir extension, and prepare the schema to ingest standard GTFS (General Transit Feed Specification) static data from the Swiss Federal Railways.

**Architecture:** Elixir / Ecto / PostGIS.

**Tech Stack:** `geo_postgis` (Elixir), PostgreSQL + PostGIS (via Nix).

---

### Task 1: Upgrade Nix Environment with PostGIS

**Files:**
- Modify: `flake.nix`

**Step 1: Write the failing check**
Run: `nix develop -c bash -c "pg_ctl status -D .pgdata || true && psql -p 15432 -d hexaplanner_dev -c 'CREATE EXTENSION IF NOT EXISTS postgis;'"`
Expected: FAIL (extension "postgis" is not available)

**Step 2: Write minimal implementation**
Modify `flake.nix` to use a PostgreSQL package bundled with PostGIS.
In the `buildInputs`, replace `postgresql_15` with `postgresql_15.withPackages (p: [ p.postgis ])`.

**Step 3: Run check to verify it passes**
Run: `nix develop -c bash -c "pg_ctl status -D .pgdata || true && psql -p 15432 -d hexaplanner_dev -c 'CREATE EXTENSION IF NOT EXISTS postgis;'"`
Expected: PASS (Extension created successfully).

**Step 4: Commit**
```bash
git add flake.nix
git commit -m "chore(db): upgrade local nix postgresql to include postgis extension for cff spatial data"
```

---

### Task 2: Integrate Geo PostGIS into Elixir/Ecto

**Files:**
- Modify: `hexaplanner/mix.exs`
- Create: `hexaplanner/lib/hexaplanner/repo.ex` (Modify to configure PostGIS types)

**Step 1: Write the failing check**
Run: `nix develop -c bash -c "cd hexaplanner && mix deps.tree | grep geo_postgis"`
Expected: FAIL

**Step 2: Write minimal implementation**
1. Add `{:geo_postgis, "~> 3.4"}` to `mix.exs`.
2. Update the `HexaPlanner.Repo` module (if it exists, or ensure it's configured) to know about PostGIS types:
```elixir
# in repo.ex or application config
Postgrex.Types.define(HexaPlanner.PostgresTypes, [Geo.PostGIS.Extension] ++ Ecto.Adapters.Postgres.extensions(), [])
```
*(Note: We will configure this via the Repo configuration in the Ecto setup).*

**Step 3: Run check to verify it passes**
Run: `nix develop -c bash -c "cd hexaplanner && mix deps.get && mix compile"`
Expected: PASS

**Step 4: Commit**
```bash
git add hexaplanner/mix.exs hexaplanner/mix.lock
git commit -m "chore(deps): add geo_postgis for spatial queries and gtfs processing"
```

---

### Task 3: Create Ecto Migration for GTFS Stops

**Files:**
- Create: `hexaplanner/priv/repo/migrations/*_create_cff_stops.exs`
- Create: `hexaplanner/lib/hexaplanner/cff/stop.ex`

**Step 1: Write the failing test**
Create a test to insert a GTFS Stop (ex: Bern Hauptbahnhof).
```elixir
# hexaplanner/test/cff/stop_test.exs
defmodule HexaPlanner.CFF.StopTest do
  use HexaPlanner.DataCase # Requires standard Ecto DataCase

  test "insert and retrieve a GTFS stop with geospatial point" do
    # Coordinates for Bern HB
    point = %Geo.Point{coordinates: {7.4391, 46.9488}, srid: 4326}
    
    {:ok, stop} = HexaPlanner.Repo.insert(%HexaPlanner.CFF.Stop{
      stop_id: "8507000", # SBB Didok code
      stop_name: "Bern",
      location: point
    })

    assert stop.stop_name == "Bern"
  end
end
```

**Step 2: Run test to verify it fails**
Run: `nix develop -c bash -c "cd hexaplanner && mix test test/cff/stop_test.exs"`
Expected: FAIL

**Step 3: Write minimal implementation**
1. Generate migration: `mix ecto.gen.migration create_cff_stops`
2. In the migration file:
```elixir
def change do
  execute("CREATE EXTENSION IF NOT EXISTS postgis")

  create table(:cff_stops, primary_key: false) do
    add :stop_id, :string, primary_key: true
    add :stop_name, :string, null: false
    add :location, :geometry, null: false
  end
end
```
3. Create the Schema `lib/hexaplanner/cff/stop.ex`:
```elixir
defmodule HexaPlanner.CFF.Stop do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:stop_id, :string, autogenerate: false}
  schema "cff_stops" do
    field :stop_name, :string
    field :location, Geo.PostGIS.Geometry
  end
end
```

**Step 4: Run test to verify it passes**
Run: `nix develop -c bash -c "cd hexaplanner && mix ecto.migrate && mix test test/cff/stop_test.exs"`
Expected: PASS

**Step 5: Commit**
```bash
git add hexaplanner/
git commit -m "feat(cff): implement GTFS Stop schema with PostGIS geometry"
```
