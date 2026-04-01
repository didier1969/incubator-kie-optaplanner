# Chaos Director Stabilization Slice

## Scope
- Stabilize the active branch around the `Chaos Director` UI flow and the runtime effect of infrastructure perturbations.
- Remove a false-positive test/runtime coupling by preventing `HexaRail.Simulation.Engine` from starting in `test`.

## Root Causes
1. `HexaRailWeb.TwinLive` accepted partial `:chaos_detected` payloads but the template assumed `chaos_event.resolved` always existed, causing a render crash.
2. `execute_scenario` and `resolve_chaos` assigned status messages that were never rendered, so the UI state changed without visible feedback.
3. Infrastructure perturbations were loaded into the Rust manager but not applied before position queries, and the path fallback masked disabled infrastructure by keeping a straight-line interpolation alive.
4. The simulation engine started in `test`, polluting LiveView and unit tests with DB and NIF bootstrap noise.
5. `HexaRailWeb.TwinLive` still mounted with hardcoded `:running / 100% / System Live` defaults instead of reflecting the engine state when available.

## Changes
- Normalize `chaos_event` payloads in `HexaRailWeb.TwinLive`.
- Render the current chaos status message in the `Chaos Director` panel.
- Apply perturbations before `get_train_position/3` and `get_active_positions/2`.
- Refuse the straight-line fallback when a perturbation has disabled the relevant physical path.
- Gate `HexaRail.Simulation.Engine` behind `config :hexarail, :start_simulation_engine`.
- Disable the simulation engine in `hexarail/config/test.exs`.
- Bootstrap the LiveView HUD from `Engine.get_status/0` when available, with a defensive fallback for `test` and disconnected mounts.
- Route `resolve_chaos` through `Engine.resolve_chaos/1` instead of leaving it as a UI-only placeholder.
- Use the same configurable engine boundary for `mount`, `execute_scenario`, `resolve_chaos`, `pause`, and `resume`, which makes the LiveView testable without booting the real engine.

## Validation
- `mix test test/hexaplanner_web/live/twin_live_test.exs`
- `mix test test/chaos_solver_test.exs`
- `mix test test/application_test.exs test/hexaplanner_web/live/twin_live_test.exs test/chaos_solver_test.exs`

## Remaining Work
- `HexaRail.Simulation.Engine` still performs raw scenario-to-core mapping internally instead of delegating to a dedicated boundary module.
- `get_system_health/1` still underreports runtime effects of perturbations because it has no time-context input.
- `resolve_chaos` now crosses the engine boundary, but only `greedy` and `local_search` strategies are wired to runtime actions; `genetic` and `otp` remain UI-level placeholders.
- The worktree still contains historical tracked artifacts outside this stabilization slice (`.pgdata/*`, `.direnv/*`, `server_run.log`, `hexarail/priv/native/libhexacore_engine.so`, `hexarail/priv/static/js/app.js`).
