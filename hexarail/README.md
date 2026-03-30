# HexaRail: Railway Vertical on Top of HexaCore

HexaRail is the railway vertical of the broader **HexaCore** optimization platform. It is a high-performance, institutional-grade railway network optimizer and simulator focused on the Swiss SBB/CFF showcase and used as the primary technical validator for the platform.

## Core Pillars
1.  **Spatio-Temporal Interval Graph (STIG)**: A custom graph engine implemented in Rust, capable of detecting centimeter-level collisions across millions of operations in $O(1)$.
2.  **Newtonian Kinematics**: Physics-aware routing that considers mass, acceleration, and speed restrictions on switches.
3.  **Reactive Score Engine**: Powered by **Salsa** (Rust), providing incremental score calculation for real-time metaheuristics.
4.  **Agnostic Core**: The mathematical engine is decoupled from the railway vertical and is intended to be reused by other verticals such as *HexaFactory*.

## Position in the Repository
This repository is not intended to stop at the railway domain.

The current structure and direction are:
- **HexaCore**: reusable platform and agnostic optimization core
- **HexaRail**: railway-specific vertical and showcase
- **HexaFactory**: manufacturing/job-shop vertical already started in planning and domain documentation

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

## Scope
HexaRail should be read as a vertical implementation, not as the final name or limit of the overall platform. Its purpose is to prove that if the core can absorb the operational and physical complexity of the Swiss railway network, the same platform can later support other industrial domains.
