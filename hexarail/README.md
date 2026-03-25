# HexaRail: The High-Fidelity SBB/CFF Digital Twin

HexaRail is a high-performance, institutional-grade railway network optimizer and simulator. Built on top of the **HexaCore** agnostic optimization framework, it models the entire Swiss railway network with Newtonian precision.

## Core Pillars
1.  **Spatio-Temporal Interval Graph (STIG)**: A custom graph engine implemented in Rust, capable of detecting centimeter-level collisions across millions of operations in $O(1)$.
2.  **Newtonian Kinematics**: Physics-aware routing that considers mass, acceleration, and speed restrictions on switches.
3.  **Reactive Score Engine**: Powered by **Salsa** (Rust), providing incremental score calculation for real-time metaheuristics.
4.  **Agnostic Core**: The mathematical engine is decoupled from the railway vertical, allowing future extensions like *HexaFactory*.

## Technical Stack
- **Control Plane**: Elixir / Phoenix LiveView (Real-time orchestration and UI).
- **Data Plane**: Rust (Computationally heavy graph and solver logic).
- **Database**: PostgreSQL + PostGIS (Geospatial storage).
- **Frontend**: MapLibre GL JS + Deck.gl (WebGL visualization).

## Getting Started
Requires **Nix** with flakes enabled.

```bash
nix develop
cd hexarail
mix deps.get
mix ecto.setup
mix phx.server
```
