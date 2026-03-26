defmodule HexaCore.Domain.DemGrid do
  @moduledoc """
  Agnostic Digital Elevation Model grid used by the HexaCore Newton solver
  to calculate slopes (Pitch) and kinematics.
  """
  defstruct [
    :lat_min,
    :lat_max,
    :lon_min,
    :lon_max,
    :lat_steps,
    :lon_steps,
    :elevations
  ]
end