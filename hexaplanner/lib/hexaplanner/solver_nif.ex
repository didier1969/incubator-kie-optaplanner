defmodule HexaPlanner.SolverNif do
  @moduledoc """
  NIF bridge to the Rust implementation.
  """

  use Rustler, otp_app: :hexaplanner, crate: "hexa_solver"

  @spec add(integer(), integer()) :: integer()
  def add(_a, _b), do: :erlang.nif_error(:nif_not_loaded)

  @spec evaluate_problem(reference(), HexaPlanner.Domain.Problem.t()) :: integer()
  def evaluate_problem(_resource, _problem), do: :erlang.nif_error(:nif_not_loaded)

  @spec optimize_problem(reference(), HexaPlanner.Domain.Problem.t(), integer()) ::
          HexaPlanner.Domain.Problem.t()
  def optimize_problem(_resource, _problem, _iterations), do: :erlang.nif_error(:nif_not_loaded)

  def build_network_graph(_edges), do: :erlang.nif_error(:nif_not_loaded)

  def init_network, do: :erlang.nif_error(:nif_not_loaded)

  def load_stops(_resource, _stops), do: :erlang.nif_error(:nif_not_loaded)

  def load_stop_times(_resource, _stop_times), do: :erlang.nif_error(:nif_not_loaded)

  def load_transfers(_resource, _transfers), do: :erlang.nif_error(:nif_not_loaded)

  def load_calendars(_resource, _calendars), do: :erlang.nif_error(:nif_not_loaded)

  def load_calendar_dates(_resource, _dates), do: :erlang.nif_error(:nif_not_loaded)

  def load_tracks(_resource, _tracks), do: :erlang.nif_error(:nif_not_loaded)

  def get_train_position(_resource, _trip_id, _time), do: :erlang.nif_error(:nif_not_loaded)

  def finalize_temporal_graph(_resource), do: :erlang.nif_error(:nif_not_loaded)

  def detect_conflicts(_resource), do: :erlang.nif_error(:nif_not_loaded)
end
