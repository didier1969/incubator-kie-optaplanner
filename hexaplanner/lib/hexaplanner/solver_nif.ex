defmodule HexaPlanner.SolverNif do
  @moduledoc """
  NIF bridge to the Rust implementation.
  """

  use Rustler, otp_app: :hexaplanner, crate: "hexa_solver"

  @spec add(integer(), integer()) :: integer()
  def add(_a, _b), do: :erlang.nif_error(:nif_not_loaded)
end
