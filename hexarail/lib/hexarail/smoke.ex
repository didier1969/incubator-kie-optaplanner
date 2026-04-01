# Copyright (c) Didier Stadelmann. All rights reserved.

defmodule HexaRail.Smoke do
  @moduledoc false

  alias HexaRail.GTFS.{Stop, StopTime}
  alias HexaRail.RailwayNif

  @type summary :: %{
          strategy: atom(),
          query_time: integer(),
          perturbation_start_time: integer(),
          tracks_loaded: non_neg_integer(),
          active_positions_before: non_neg_integer(),
          active_positions_after: non_neg_integer(),
          resolution_status: String.t(),
          trains_impacted: non_neg_integer(),
          total_delay_added: non_neg_integer(),
          computation_time_ms: non_neg_integer()
        }

  @spec run(keyword()) :: summary()
  def run(opts \\ []) do
    strategy = Keyword.get(opts, :strategy, :greedy)
    query_time = Keyword.get(opts, :query_time, 150)
    perturbation_start_time = Keyword.get(opts, :perturbation_start_time, 120)
    resource = RailwayNif.init_network()

    RailwayNif.load_stops(resource, smoke_stops())
    tracks_loaded = RailwayNif.load_tracks(resource, smoke_tracks())
    RailwayNif.load_stop_times(resource, smoke_stop_times())
    RailwayNif.finalize_temporal_graph(resource)

    active_positions_before = length(RailwayNif.get_active_positions(resource, query_time))

    :ok =
      RailwayNif.load_perturbations(
        resource,
        [
          %HexaRail.Domain.Perturbation{
            id: "hexarail-smoke-1",
            perturbation_type: "infrastructure",
            target_id: "A-B",
            start_time: perturbation_start_time,
            duration: 120
          }
        ]
      )

    active_positions_after = length(RailwayNif.get_active_positions(resource, query_time))
    resolution = resolve(resource, strategy)

    %{
      strategy: strategy,
      query_time: query_time,
      perturbation_start_time: perturbation_start_time,
      tracks_loaded: tracks_loaded,
      active_positions_before: active_positions_before,
      active_positions_after: active_positions_after,
      resolution_status: resolution.status,
      trains_impacted: resolution.trains_impacted,
      total_delay_added: resolution.total_delay_added,
      computation_time_ms: resolution.computation_time_ms
    }
  end

  @spec print_summary(summary(), String.t()) :: :ok
  def print_summary(summary, label \\ "smoke") do
    IO.puts("HexaRail #{label}")
    IO.puts("strategy=#{summary.strategy} query_time=#{summary.query_time} perturbation_start_time=#{summary.perturbation_start_time}")

    IO.puts(
      "tracks=#{summary.tracks_loaded} active_before=#{summary.active_positions_before} active_after=#{summary.active_positions_after}"
    )

    IO.puts(
      "resolution_status=#{summary.resolution_status} trains_impacted=#{summary.trains_impacted} " <>
        "delay_added=#{summary.total_delay_added} computation_ms=#{summary.computation_time_ms}"
    )
  end

  defp resolve(resource, :greedy), do: RailwayNif.resolve_conflict_greedy(resource)
  defp resolve(resource, :local_search), do: RailwayNif.resolve_conflict_local_search(resource)
  defp resolve(resource, _strategy), do: RailwayNif.resolve_conflict_greedy(resource)

  defp smoke_stops do
    [
      %Stop{
        id: 1,
        original_stop_id: "A",
        stop_name: "Station A",
        location: %Geo.Point{coordinates: {0.0, 0.0}, srid: 4326},
        abbreviation: "A",
        location_type: 0,
        parent_station: "",
        platform_code: ""
      },
      %Stop{
        id: 2,
        original_stop_id: "B",
        stop_name: "Station B",
        location: %Geo.Point{coordinates: {1.0, 0.0}, srid: 4326},
        abbreviation: "B",
        location_type: 0,
        parent_station: "",
        platform_code: ""
      }
    ]
  end

  defp smoke_tracks do
    [
      %HexaRail.Data.Parser.TrackSegment{
        line_id: "L1",
        coordinates: [{0.0, 0.0}, {1.0, 0.0}],
        properties: %{"bp_anfang" => "A", "bp_ende" => "B"}
      }
    ]
  end

  defp smoke_stop_times do
    [
      %StopTime{trip_id: 100, stop_id: 1, arrival_time: 100, departure_time: 100, stop_sequence: 1, pickup_type: 0, drop_off_type: 0},
      %StopTime{trip_id: 100, stop_id: 2, arrival_time: 200, departure_time: 200, stop_sequence: 2, pickup_type: 0, drop_off_type: 0},
      %StopTime{trip_id: 200, stop_id: 1, arrival_time: 101, departure_time: 101, stop_sequence: 1, pickup_type: 0, drop_off_type: 0},
      %StopTime{trip_id: 200, stop_id: 2, arrival_time: 201, departure_time: 201, stop_sequence: 2, pickup_type: 0, drop_off_type: 0}
    ]
  end
end
