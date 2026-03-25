defmodule HexaPlanner.RailwayNif do
  @moduledoc """
  Railway Vertical API acting as a facade over HexaCore generic functions.
  """

  alias HexaCore.Nif

  def init_network, do: Nif.init_network()

  defdelegate load_stops(resource, stops), to: Nif
  defdelegate load_trips(resource, trips), to: Nif
  defdelegate load_stop_times(resource, stop_times), to: Nif
  defdelegate load_transfers(resource, transfers), to: Nif
  defdelegate load_calendars(resource, calendars), to: Nif
  defdelegate load_calendar_dates(resource, dates), to: Nif
  defdelegate load_fleet(resource, profiles), to: Nif
  defdelegate load_tracks(resource, tracks), to: Nif

  defdelegate load_osm(resource, nodes, ways), to: Nif
  defdelegate route_micro_path(resource, start_id, end_id), to: Nif
  defdelegate route_micro_path_with_kinematics(resource, start_id, end_id, fleet_id), to: Nif
  defdelegate stitch_osm_to_macro(resource), to: Nif
  defdelegate get_train_position(resource, trip_id, time), to: Nif
  defdelegate get_active_positions(resource, time), to: Nif
  defdelegate finalize_temporal_graph(resource), to: Nif
  defdelegate get_conflict_summary(resource), to: Nif
  defdelegate freeze_state(resource, path), to: Nif
  defdelegate thaw_state(resource, path), to: Nif
  defdelegate inject_delay(resource, trip_id, delay_seconds), to: Nif
  defdelegate resolve_conflict_greedy(resource), to: Nif
  defdelegate resolve_conflict_local_search(resource), to: Nif
  defdelegate get_all_tracks(resource), to: Nif
  defdelegate detect_conflicts(resource), to: Nif

  # Hexacore passthroughs for tests that reference SolverNif but should use HexaCore.Nif
  defdelegate evaluate_problem(resource, problem), to: Nif
  defdelegate optimize_problem(resource, problem, iterations), to: Nif
end
