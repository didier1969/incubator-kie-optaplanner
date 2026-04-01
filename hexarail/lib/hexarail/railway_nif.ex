# Copyright (c) Didier Stadelmann. All rights reserved.

defmodule HexaRail.RailwayNif do
  @moduledoc """
  Railway vertical API exposing only railway-facing operations.
  """

  alias HexaRail.Native

  def init_network, do: Native.init_network()

  defdelegate load_stops(resource, stops), to: Native
  defdelegate load_trips(resource, trips), to: Native
  defdelegate load_stop_times(resource, stop_times), to: Native
  defdelegate load_transfers(resource, transfers), to: Native
  defdelegate load_calendars(resource, calendars), to: Native
  defdelegate load_calendar_dates(resource, dates), to: Native
  defdelegate load_fleet(resource, profiles), to: Native
  defdelegate load_tracks(resource, tracks), to: Native
  defdelegate load_dem(resource, dem_grid), to: Native
  defdelegate load_perturbations(resource, perturbations), to: Native
  defdelegate get_system_health(resource), to: Native

  defdelegate load_osm_from_json(resource, path), to: Native
  defdelegate load_osm(resource, nodes, ways), to: Native
  defdelegate route_micro_path(resource, start_id, end_id), to: Native
  defdelegate route_micro_path_with_kinematics(resource, start_id, end_id, fleet_id), to: Native
  defdelegate stitch_osm_to_macro(resource), to: Native
  defdelegate get_train_position(resource, trip_id, time), to: Native
  defdelegate get_active_positions(resource, time), to: Native
  defdelegate finalize_temporal_graph(resource), to: Native
  defdelegate get_conflict_summary(resource), to: Native
  defdelegate freeze_state(resource, path), to: Native
  defdelegate thaw_state(resource, path), to: Native
  defdelegate inject_delay(resource, trip_id, delay_seconds), to: Native
  defdelegate resolve_conflict_greedy(resource), to: Native
  defdelegate resolve_conflict_local_search(resource), to: Native
  defdelegate get_all_tracks(resource), to: Native
  defdelegate detect_conflicts(resource), to: Native
end
