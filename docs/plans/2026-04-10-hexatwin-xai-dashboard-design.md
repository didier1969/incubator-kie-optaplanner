# HexaTwin Digital Twin: Architecture & UX Design (Macro/Micro XAI)

*Date: 2026-04-10*
*Topic: Phoenix LiveView & VizKit Integration for HexaFactory*
*Status: Approved*

## Overview
This document outlines the architecture for the "Pillar 3" of the HexaCore platform: the Explainable AI (XAI) Digital Twin interface for the `HexaFactory` manufacturing domain. It leverages the SOTA `viz_kit` (based on SwarmEx Viz concepts) to provide a seamless, high-performance "Drill-Down" experience from global supply chain topology down to individual machine scheduling.

**Critical Refactoring Note:** To eliminate historical confusion, the global web namespace `HexaRailWeb` will be refactored to `HexaTwinWeb` (or `HexaCoreWeb`), cleanly separating the generic visualization engine from the specific railway or factory implementations.

## 1. Architecture & Front-End Components

The interface is built on Phoenix LiveView, using `viz_kit` hooks for client-side rendering (avoiding massive SVG payloads over WebSockets).

*   **The Macro View (Knowledge Map):**
    *   **Engine:** `Sigma.js` (via VizKit).
    *   **Data Mapping:** 
        *   `Nodes` = `Plants` and `Work Centers`.
        *   `Edges` = `Transport Lanes` and Assembly Dependencies (BOM flow).
    *   **Visual Encoding:** Node size/color reflects the real-time "System Health" calculated by the Salsa engine. A red node indicates critical `Hard` constraint violations (e.g., machine capacity exceeded).

*   **The Micro View (Gantt/Timeline):**
    *   **Engine:** Custom SVG/Timeline (via VizKit).
    *   **Trigger:** Clicking a node in the Macro View performs a smooth "Drill-Down" transition.
    *   **Data Mapping:**
        *   `Y-Axis` = Resources (`Machines` and `Operators`).
        *   `X-Axis` = Time (Minutes).
        *   `Events` = Scheduled Jobs (`Production Orders`).

*   **XAI Diagnostics (Tooltip HUD):**
    *   **Engine:** `float-tooltip` (via VizKit).
    *   **Trigger:** Hovering over a Job in the Micro View.
    *   **Data Mapping:** Displays the exact `ScoreExplanation` payload from Rust. It lists all `ConstraintViolation` objects affecting that job, categorized by severity (e.g., "Hard: Overlap on M-100", "Soft: 45m setup penalty for thermal profile change").

## 2. Data Flow (Asynchronous Reactive Pipeline)

The system relies on unidirectional data flow to maintain 60 FPS rendering in the browser while the SOTA engine optimizes in the background.

1.  **State Mutation (Rust/Salsa):** The NCO solver mutates the schedule and calculates $O(\delta)$ scores.
2.  **Broadcast (Elixir/OTP):** `HexaFactory.Application` (or a dedicated simulation Ticker) broadcasts the updated JSON tensors and `ScoreExplanation` via `Phoenix.PubSub` on the `simulation:hexafactory` channel.
3.  **LiveView Controller (`HexaTwinWeb.TwinLive`):** 
    *   Listens to the PubSub channel via `handle_info`.
    *   Formats the raw data into VizKit primitives (`nodes`, `edges`, `events`).
    *   Pushes the payload to the client via `push_event("update_viz", payload)`.
4.  **VizKit Hook (JavaScript):**
    *   The DOM element `<div id="factory-viz" phx-update="ignore">` prevents LiveView from thrashing the DOM.
    *   The JS hook catches `update_viz` and calls `chart.update({ data: payload })`, allowing ECharts/Sigma.js to smoothly animate the changes.

## 3. UX Interactions & Decision Support (DSS)

The Digital Twin is an active Decision Support System, not just a passive dashboard.

*   **Drill-Down Navigation:**
    *   Clicking a Macro node sends a `push_event` to LiveView (`%{action: "zoom_in", target: "WC-100"}`).
    *   LiveView updates its state to fetch only the Micro data for that specific Work Center and pushes the new view to the client.
*   **Visual Alerting (Highlighting):**
    *   Jobs responsible for `Hard` penalties (feasibility) blink or are colored red.
    *   Jobs causing `Soft` penalties (sequence-dependent setups) are colored orange.
    *   Overloaded resources (Machines) have their entire Y-axis row highlighted.
*   **Chaos Engineering (Perturbation Injection):**
    *   A permanent side-panel allows operators to inject real-world chaos (e.g., "Machine M-100 breaks down for 4 hours", "Operator Ariane is absent").
    *   Clicking "Inject" triggers a re-optimization request to the Rust solver.
    *   The UI temporarily freezes the affected zone, the GNN/LAHC engine recalculates the SOTA score, and the Gantt chart visibly "snaps" to the new optimal layout, propagating health colors back up to the Macro view.