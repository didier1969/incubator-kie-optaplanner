# Task Plan: Documentation Alignment (Phase 1-11 Consolidation)

## Goal
Update all project documentation to 100% compliance with the current architecture and implementation of the CFF/SBB Digital Twin, ensuring no simplifications are mentioned or implied, and reflecting the full-scale data ingestion and Rust/Elixir hybrid architecture.

## Phases

### Phase 1: Audit & Inventory (Research)
- [x] Audit all files in `docs/` and `cahiers_des_charges_experts/`.
- [x] Identify contradictions between current implementation and existing documentation.
- [x] Identify missing sections (e.g., massive GTFS ingestion details, zero-memory SQL resolution).

### Phase 2: Master Architecture Update (Execution)
- [x] Update `cahiers_des_charges_experts/19_Master_Architecture_Document.md`.
- [x] Align with "Zero Simplification" mandate.
- [x] Detail the Elixir Control Plane vs Rust Data Plane split.

### Phase 3: Macro Plan Synchronization (Execution)
- [x] Update `docs/architecture/decisions/001_macro_plan_cff_twin.md`.
- [x] Mark Phases 1-11 as completed with technical specifics.
- [x] Refine Phases 12-14 based on the established high-fidelity baseline.

### Phase 4: Implementation Plans Cleanup (Execution)
- [x] Review and potentially archive/update outdated `docs/plans/2026-03-21-hexaplanner-phase*.md` files.
- [x] Ensure they reflect the *actual* implemented optimized techniques (PostgreSQL staging, etc.).

### Phase 5: Domain & Technical Documentation (Execution)
- [x] Update `README.md` in root.
- [x] Document the `mix data.download` and `mix data.import` workflows.
- [x] Document the schema mapping between GTFS and PostgreSQL.

### Phase 6: Final Review & Validation (Verification)
- [x] Cross-check all updated docs against the code.
- [x] Ensure 100% consistency.

## Progress
- [x] Audit completed.
- [x] Master Architecture corrected to reflect HexaPlanner as a Universal Framework.
- [x] README.md updated with the "Zero Simplification" vision.
- [x] CFF/SBB case explicitly identified as a "Showcase Validator".
- [x] Ingestion pipeline (Phase 11) fully documented and implemented without reduction.

