# Technical Documentation: High-Fidelity Database Schema

HexaRail uses PostgreSQL with PostGIS to store massive datasets with zero simplification. This document details the schema design and the optimized ingestion strategy used for the CFF/SBB reference vertical.

## 🏛 Schema Architecture

### 1. Geospatial Nodes (`gtfs_stops`)
Stores every physical station, quai (platform), and entrance with exact GPS coordinates.
*   `location`: Geometry (Point, 4326) for GIST-indexed spatial queries.
*   `platform_code`: Preserves the specific track/quai number for precise conflict resolution.

### 2. Temporal Events (`gtfs_stop_times`)
The high-volume table (19M+ rows).
*   Stored as integer seconds from midnight to eliminate string parsing overhead during optimization.
*   `pickup_type` / `drop_off_type`: Preserved to model passenger flow constraints accurately.

### 3. Service Logic (`gtfs_calendars` & `gtfs_calendar_dates`)
Models the full complexity of the Swiss timetable, including school holidays, one-off event trains, and maintenance cancellations.
*   `gtfs_calendar_dates` (6M+ rows): Tracks every single daily exception to the weekly schedule.

## 🚀 Optimized Ingestion Pipeline

To handle 20M+ events without exhausting Elixir VM memory, HexaRail uses a **Zero-Memory SQL Resolution** strategy:

1.  **Staging:** Data is streamed from CSV into `UNLOGGED` staging tables (`_staging`). Unlogged tables bypass the Write-Ahead Log (WAL) for 3x faster insertion.
2.  **Dictionary Sync:** Internal `ID` maps are mirrored from the main tables to unlogged dictionary tables (`_dict`).
3.  **SQL Resolution:** A single massive `INSERT INTO ... SELECT ... JOIN` query is executed. This moves the key resolution (matching GTFS string IDs to internal Integer BigSerials) entirely into the PostgreSQL engine.
4.  **Performance:** This approach allows ingesting the entire Swiss network in < 10 minutes on standard hardware.

## 🔗 Relationships & Integrity
*   **Transfers:** Guaranteed connection rules are modeled between Stops, Trips, and even specific Routes.
*   **Frequencies:** Supports frequency-based modeling (e.g., "every 5 minutes") for urban transit systems like the Lausanne Metro.
