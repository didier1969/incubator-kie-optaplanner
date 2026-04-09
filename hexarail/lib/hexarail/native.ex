# Copyright (c) Didier Stadelmann. All rights reserved.

defmodule HexaRail.Native do
  @moduledoc false

  use Rustler,
    otp_app: :hexarail,
    crate: "hexarail_engine",
    path: "native/hexarail_engine",
    target_dir: Path.expand("native/target", File.cwd!())

  def init_network, do: :erlang.nif_error(:nif_not_loaded)

  def load_stops(_resource, _stops), do: :erlang.nif_error(:nif_not_loaded)
  def load_trips(_resource, _trips), do: :erlang.nif_error(:nif_not_loaded)
  def load_stop_times(_resource, _stop_times), do: :erlang.nif_error(:nif_not_loaded)
  def load_transfers(_resource, _transfers), do: :erlang.nif_error(:nif_not_loaded)
  def load_dem(_resource, _dem_grid), do: :erlang.nif_error(:nif_not_loaded)
  def load_perturbations(_resource, _perturbations), do: :erlang.nif_error(:nif_not_loaded)
  def get_system_health(_resource), do: :erlang.nif_error(:nif_not_loaded)
  def load_calendars(_resource, _calendars), do: :erlang.nif_error(:nif_not_loaded)
  def load_calendar_dates(_resource, _dates), do: :erlang.nif_error(:nif_not_loaded)
  def load_fleet(_resource, _profiles), do: :erlang.nif_error(:nif_not_loaded)
  def load_tracks(_resource, _tracks), do: :erlang.nif_error(:nif_not_loaded)
  def build_network_graph(_edges), do: :erlang.nif_error(:nif_not_loaded)
  def load_osm_from_json(_resource, _path), do: :erlang.nif_error(:nif_not_loaded)
  def load_osm(_resource, _nodes, _ways), do: :erlang.nif_error(:nif_not_loaded)
  def route_micro_path(_resource, _start_id, _end_id), do: :erlang.nif_error(:nif_not_loaded)

  def route_micro_path_with_kinematics(_resource, _start_id, _end_id, _fleet_id),
    do: :erlang.nif_error(:nif_not_loaded)

  def stitch_osm_to_macro(_resource), do: :erlang.nif_error(:nif_not_loaded)
  def get_train_position(_resource, _trip_id, _time), do: :erlang.nif_error(:nif_not_loaded)
  def get_active_positions(_resource, _time), do: :erlang.nif_error(:nif_not_loaded)
  def finalize_temporal_graph(_resource), do: :erlang.nif_error(:nif_not_loaded)
  def detect_conflicts(_resource), do: :erlang.nif_error(:nif_not_loaded)
  def get_conflict_summary(_resource), do: :erlang.nif_error(:nif_not_loaded)
  def freeze_state(_resource, _path), do: :erlang.nif_error(:nif_not_loaded)
  def thaw_state(_resource, _path), do: :erlang.nif_error(:nif_not_loaded)
  def inject_delay(_resource, _trip_id, _delay_seconds), do: :erlang.nif_error(:nif_not_loaded)
  def resolve_conflict_greedy(_resource), do: :erlang.nif_error(:nif_not_loaded)
  def resolve_conflict_local_search(_resource), do: :erlang.nif_error(:nif_not_loaded)
  def get_all_tracks(_resource), do: :erlang.nif_error(:nif_not_loaded)
end
