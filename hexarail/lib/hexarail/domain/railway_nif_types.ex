# Copyright (c) Didier Stadelmann. All rights reserved.

defmodule HexaRail.Domain.Perturbation do
  defstruct [:id, :perturbation_type, :target_id, :start_time, :duration]
end

defmodule HexaRail.Domain.SystemHealth do
  defstruct [:total_delay_seconds, :active_conflicts, :broken_connections, :active_perturbations]
end

defmodule HexaRail.Domain.ActivePosition do
  defstruct [:trip_id, :head_lon, :head_lat, :tail_lon, :tail_lat, :alt, :heading, :pitch, :roll, :velocity]
end

defmodule HexaRail.Domain.EOS do
  defstruct [:trip_id, :track_id, :start_time, :end_time]
end

defmodule HexaRail.Domain.Conflict do
  defstruct [:trip_a, :trip_b, :track_id, :start_time, :end_time]
end

defmodule HexaRail.Domain.ConflictSummary do
  defstruct [:total_conflicts, sample_conflicts: []]
end

defmodule HexaRail.Domain.ResolutionMetrics do
  defstruct [:status, :trains_impacted, :total_delay_added, :computation_time_ms]
end

defmodule HexaRail.Domain.CompactEOS do
  defstruct [:trip_idx, :track_idx, :start_time, :end_time]
end
