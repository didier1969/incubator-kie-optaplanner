# Copyright (c) Didier Stadelmann. All rights reserved.

defmodule HexaFactory.Adapter.ResourceProjection do
  @moduledoc "Projects HexaFactory master data into generic HexaCore resources."

  alias HexaCore.Domain.{Resource, Window}

  @spec build(HexaFactory.Generator.Dataset.t()) :: {list(Resource.t()), map()}
  def build(dataset) do
    machine_resources =
      dataset.machines
      |> Enum.with_index(1)
      |> Enum.map(fn {machine, index} ->
        resource = %Resource{
          id: index,
          name: "machine:#{machine.code}",
          capacity: 1,
          availability_windows: [%Window{start_at: 0, end_at: 1_440}]
        }

        {resource, {:machine, machine.code}}
      end)

    labor_resources =
      dataset.labor_pools
      |> Enum.with_index(length(machine_resources) + 1)
      |> Enum.map(fn {labor_pool, index} ->
        resource = %Resource{
          id: index,
          name: "labor_pool:#{labor_pool.code}",
          capacity: 1,
          availability_windows: [%Window{start_at: 0, end_at: 480}]
        }

        {resource, {:labor_pool, labor_pool.code}}
      end)

    tool_resources =
      dataset.tool_instances
      |> Enum.with_index(length(machine_resources) + length(labor_resources) + 1)
      |> Enum.map(fn {tool_instance, index} ->
        resource = %Resource{
          id: index,
          name: "tool:#{tool_instance.code}",
          capacity: 1,
          availability_windows: [%Window{start_at: 0, end_at: 1_440}]
        }

        {resource, {:tool, tool_instance.code}}
      end)

    buffer_resources =
      dataset.buffers
      |> Enum.with_index(length(machine_resources) + length(labor_resources) + length(tool_resources) + 1)
      |> Enum.map(fn {buffer, index} ->
        resource = %Resource{
          id: index,
          name: "buffer:#{buffer.code}",
          capacity: buffer.capacity_units,
          availability_windows: [%Window{start_at: 0, end_at: 1_440}]
        }

        {resource, {:buffer, buffer.code}}
      end)

    transport_resources =
      dataset.transport_lanes
      |> Enum.with_index(
        length(machine_resources) + length(labor_resources) + length(tool_resources) + length(buffer_resources) + 1
      )
      |> Enum.map(fn {lane, index} ->
        resource = %Resource{
          id: index,
          name: "transport:#{lane.source_plant_code}->#{lane.target_plant_code}:#{lane.material_code}",
          capacity: 1,
          availability_windows: [%Window{start_at: 0, end_at: 1_440}]
        }

        {resource, {:transport, lane.material_code, lane.source_plant_code, lane.target_plant_code}}
      end)

    resources_with_keys =
      machine_resources ++ labor_resources ++ tool_resources ++ buffer_resources ++ transport_resources

    resources = Enum.map(resources_with_keys, &elem(&1, 0))
    index = Map.new(resources_with_keys, fn {resource, key} -> {key, resource.id} end)

    {resources, index}
  end
end
