defmodule HexaPlanner.Domain.FleetProfile do
  defstruct [:id, :type, :mass_tons, :max_acceleration, :max_deceleration, :max_speed_kmh]
end
