# Findings

## Architecture Decisions
- **Strategy Pattern:** The UI will expose a selector `[Greedy, Local Search, Genetic, OTP]`. Elixir will route the "Resolve" command to the corresponding engine.
- **Data Integrity:** The Rust STIG remains the absolute source of truth. OTP negotiation (Scenario D) must only propose changes that Rust validates.

## Open Questions
- How to efficiently extract the "Blast Zone" in Rust without traversing the entire 150M canton STIG?
- Answer: Use the `KdTree` and the temporal bounds of the initial delayed train.

## Local Search (Tabu) Strategy
- **Framework:** `localsearch` crate (`OptModel` trait).
- **Solution Space:** A `HashMap<i64, i32>` representing the delay added to each trip in the blast zone.
- **Neighborhood Move:** Add `X` seconds to a random trip's delay.
- **Fitness Function:** Hard penalty (+1,000,000) for any overlapping `CompactEOS` in the STIG. Soft penalty (+1) for every second of total delay added across all trains. Minimizing fitness leads to the optimal conflict-free schedule.
