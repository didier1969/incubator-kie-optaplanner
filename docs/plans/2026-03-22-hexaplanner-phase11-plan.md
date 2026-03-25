# HexaRail Phase 11 Implementation Plan: Ingestion GTFS Temps & Vitesse

> **For Claude/Gemini:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Ingest the massive temporal data from the GTFS timetable (Trips, StopTimes, Transfers) into our Elixir Ecto database. This provides the exact schedule and constraints (min transfer times) required by the Rust solver to optimize paths and detect cascading delays.

**Architecture:** Elixir / Ecto / PostgreSQL (Bulk Inserts via NimbleCSV).

**Tech Stack:** Elixir, `nimble_csv`, `ecto_sql`.

---

### Task 1: Create GTFS Ecto Schemas

**Files:**
- Create: `hexarail/lib/hexarail/gtfs/trip.ex`
- Create: `hexarail/lib/hexarail/gtfs/stop_time.ex`
- Create: `hexarail/lib/hexarail/gtfs/transfer.ex`

**Step 1: Write the failing tests**
Create schemas tests validating required fields.

**Step 2: Run test to verify it fails**

**Step 3: Write minimal implementation**
Define Ecto Schemas mapping directly to the official GTFS spec:
- `Trip`: `trip_id` (PK), `route_id`, `service_id`
- `StopTime`: `trip_id` (FK), `arrival_time` (String or Integer seconds), `departure_time`, `stop_id` (FK), `stop_sequence`
- `Transfer`: `from_stop_id` (FK), `to_stop_id` (FK), `transfer_type`, `min_transfer_time`

**Step 4: Run test to verify it passes**

**Step 5: Commit**

### Task 2: Create Database Migrations

**Files:**
- Create: `hexarail/priv/repo/migrations/*_create_gtfs_tables.exs`

**Step 1: Write the failing check**
`mix ecto.migrate` status check

**Step 2: Write minimal implementation**
Generate migrations for `gtfs_trips`, `gtfs_stop_times`, `gtfs_transfers` with appropriate foreign keys and indexes (crucial for 1.4GB of `stop_times`).
*Index on `stop_times(trip_id)` and `stop_times(stop_id)`.*

**Step 3: Run check to verify it passes**
`mix ecto.migrate`

**Step 4: Commit**

### Task 3: Stream and Bulk Insert GTFS Files

**Files:**
- Modify: `hexarail/lib/hexarail/gtfs/importer.ex`

**Step 1: Write the failing test**
Unit test importing a mock `stop_times.txt`.

**Step 2: Run test to verify it fails**

**Step 3: Write minimal implementation**
Expand the `GTFS.Importer` module to parse and bulk insert `trips.txt` and `stop_times.txt` using `Repo.insert_all`. Ensure chunks of ~5000 rows to balance memory and DB speed.

**Step 4: Run test to verify it passes**

**Step 5: Commit**
