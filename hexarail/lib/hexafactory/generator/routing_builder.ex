# Copyright (c) Didier Stadelmann. All rights reserved.

defmodule HexaFactory.Generator.RoutingBuilder do
  @moduledoc "Builds deterministic routings, operations, and transport lanes."

  @spec build(map(), map(), map(), term()) :: {map(), term()}
  def build(_config, topology, materials_data, state) do
    routings =
      Enum.with_index(topology.plants, 1)
      |> Enum.map(fn {plant, index} ->
        %{
          code: "#{plant.code}-ROUT-#{index}",
          alternative_kind: if(index == 1, do: "cross_plant", else: "in_house"),
          plant_code: plant.code,
          material_code: "#{plant.code}-T1-#{index}"
        }
      end)

    routing_operations =
      Enum.flat_map(routings, fn routing ->
        [
          %{routing_code: routing.code, sequence: 10, operation_kind: "decolletage", batchable: false, transfer_batch_size: nil},
          %{routing_code: routing.code, sequence: 20, operation_kind: "heat_treatment", batchable: true, transfer_batch_size: 250},
          %{routing_code: routing.code, sequence: 30, operation_kind: "assembly", batchable: false, transfer_batch_size: nil}
        ]
      end)

    plants = topology.plants

    transport_lanes =
      materials_data.materials
      |> Enum.filter(&(&1.material_type in ["HALB", "FERT"]))
      |> Enum.map(fn material ->
        [source, target] =
          case plants do
            [single] -> [single, single]
            [first, second | _] -> [first, second]
          end

        %{
          material_code: material.code,
          source_plant_code: source.code,
          target_plant_code: target.code,
          transit_minutes: 180
        }
      end)

    {%{routings: routings, routing_operations: routing_operations, transport_lanes: transport_lanes}, state}
  end
end
