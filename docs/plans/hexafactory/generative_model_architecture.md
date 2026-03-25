# HexaFactory: Generative Model & Domain Completion

*Based on the architect's directive to build a synthetic data generator mimicking a specific real-world company (to impress stakeholders), while keeping the underlying vertical parametric and agnostic enough for other industries.*

## The Missing Pieces in Complex Job-Shop Scheduling (JSSP)
Before generating data, we need to address these typical blind spots in heavy industrial models:

1. **Tooling & Fixtures (Outillages et posages)**: Machines aren't enough. Does an operation require a specific tool (e.g., a specific broach for gear hobbing) or fixture? Tools are often finite resources. If there are 10 machines but only 2 tools of type X, only 2 machines can run that operation concurrently.
2. **Maintenance (Preventive & Predictive)**: How are machine maintenance windows modeled? Do we have hard stops (machine offline every 500 hours of run time) or calendar-based maintenance?
3. **Setup Resources (Operators)**: We mentioned humans for setup. Are there specific skills? E.g., can any operator set up a 'Décolletage' machine, or only a Level 3 CNC Setter? Does the setup worker need to stay at the machine during the entire production run, or just during the setup phase?
4. **Batching / Lot Sizing & Splitting**: Can a production order of 10,000 units be split across 2 identical machines to meet a tight deadline (Order Splitting)? Conversely, can operations like 'Trempe' (Heat Treatment) batch multiple different orders together if they share the same thermal profile?
5. **Transfer Batches (Overlapping Operations)**: Does the entire batch of 10,000 need to finish Operation 10 before starting Operation 20, or can Operation 20 start as soon as the first 500 units are done (Continuous Flow / Transfer Batching)?
6. **Storage/Buffer Constraints**: Do the *Storage Locations (Lagerorte)* have finite capacity? If the buffer before a T0 assembly line is full, does it block upstream machines?
7. **Changeover Constraints (Campaigns)**: Are there preferred sequences that aren't just time-based? E.g., in surface treatment, always go from light to dark colors to avoid contamination.

## The Generator Approach
The Elixir generator will use a seeded pseudo-random engine to create:
- A predictable topology of 60 Plants.
- A fleet of exactly 800+ machines distributed correctly (200 Décolletage, 150 Taillage, etc.).
- A deterministic but "messy" BOM structure generating T0s and T1s.
- Simulated client orders with Due Dates.
- A pre-calculated `Setup Matrix`.
