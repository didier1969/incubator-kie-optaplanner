# Copyright (c) Didier Stadelmann. All rights reserved.

defmodule HexaFactory.Adapter.JobProjection do
  @moduledoc "Projects HexaFactory routings and orders into generic HexaCore jobs and precedence edges."

  alias HexaCore.Domain.{Edge, Job}

  @spec build(HexaFactory.Generator.Dataset.t(), map()) :: {list(Job.t()), list(Edge.t())}
  def build(dataset, resource_index) do
    work_centers_by_code = Map.new(dataset.work_centers, &{&1.code, &1})
    machines_by_plant = Enum.group_by(dataset.machines, & &1.plant_code)
    pools_by_plant = Enum.group_by(dataset.labor_pools, & &1.plant_code)
    tools_by_plant = Enum.group_by(dataset.tool_instances, & &1.current_plant_code)
    buffers_by_plant = Enum.group_by(dataset.buffers, & &1.plant_code)
    routings_by_material = Map.new(dataset.routings, &{&1.material_code, &1})
    operations_by_routing = Enum.group_by(dataset.routing_operations, & &1.routing_code)
    transport_lanes_by_material = Map.new(dataset.transport_lanes, &{&1.material_code, &1})

    {jobs, edges, next_job_id} =
      Enum.reduce(dataset.production_orders, {[], [], 1}, fn order, {jobs_acc, edges_acc, next_job_id} ->
        routing = Map.fetch!(routings_by_material, order.material_code)

        operations =
          operations_by_routing
          |> Map.fetch!(routing.code)
          |> Enum.sort_by(& &1.sequence)

        {order_jobs, order_edges, next_job_id} =
          Enum.reduce(operations, {[], [], next_job_id}, fn operation, {order_jobs_acc, order_edges_acc, current_job_id} ->
            machine =
              machines_by_plant
              |> Map.fetch!(order.plant_code)
              |> Enum.find(fn candidate ->
                work_center = Map.fetch!(work_centers_by_code, candidate.work_center_code)
                work_center.kind == operation.operation_kind
              end) ||
                hd(Map.fetch!(machines_by_plant, order.plant_code))

            labor_pool = hd(Map.fetch!(pools_by_plant, order.plant_code))
            tool = hd(Map.fetch!(tools_by_plant, order.plant_code))
            buffer = hd(Map.fetch!(buffers_by_plant, order.plant_code))

            required_resources =
              [
                Map.fetch!(resource_index, {:machine, machine.code}),
                Map.fetch!(resource_index, {:labor_pool, labor_pool.code}),
                Map.fetch!(resource_index, {:tool, tool.code}),
                Map.fetch!(resource_index, {:buffer, buffer.code})
              ]
              |> Enum.uniq()

            job = %Job{
              id: current_job_id,
              duration: duration_for(operation.operation_kind),
              required_resources: required_resources,
              release_time: 0,
              due_time: 720 + order.priority * 60,
              batch_key: batch_key_for(order, operation),
              start_time: nil
            }

            edge =
              case List.last(order_jobs_acc) do
                nil ->
                  nil

                previous_job ->
                  %Edge{
                    from_job_id: previous_job.id,
                    to_job_id: job.id,
                    lag: lag_for(operation.operation_kind),
                    edge_type: "finish_to_start"
                  }
              end

            {
              order_jobs_acc ++ [job],
              if(edge, do: order_edges_acc ++ [edge], else: order_edges_acc),
              current_job_id + 1
            }
          end)

        {order_jobs, order_edges, next_job_id} =
          maybe_add_transfer_job(
            order_jobs,
            order_edges,
            next_job_id,
            routing,
            order,
            buffers_by_plant,
            transport_lanes_by_material,
            resource_index
          )

        {jobs_acc ++ order_jobs, edges_acc ++ order_edges, next_job_id}
      end)

    {maintenance_jobs, final_job_id} =
      Enum.map_reduce(dataset.maintenance_windows, next_job_id, fn maintenance_window, current_job_id ->
        machine =
          machines_by_plant
          |> Map.fetch!(maintenance_window.plant_code)
          |> hd()

        job = %Job{
          id: current_job_id,
          duration: maintenance_window.end_minute - maintenance_window.start_minute,
          required_resources: [Map.fetch!(resource_index, {:machine, machine.code})],
          release_time: maintenance_window.start_minute,
          due_time: maintenance_window.end_minute,
          batch_key: nil,
          start_time: maintenance_window.start_minute
        }

        {job, current_job_id + 1}
      end)

    {transport_blackout_jobs, _next_job_id} =
      Enum.map_reduce(dataset.transport_lanes, final_job_id, fn lane, current_job_id ->
        job = %Job{
          id: current_job_id,
          duration: lane.transit_minutes,
          required_resources: [
            Map.fetch!(resource_index, {:transport, lane.material_code, lane.source_plant_code, lane.target_plant_code})
          ],
          release_time: 0,
          due_time: 1_440,
          batch_key: "transport:#{lane.material_code}",
          start_time: nil
        }

        {job, current_job_id + 1}
      end)

    {jobs ++ maintenance_jobs ++ transport_blackout_jobs, edges}
  end

  defp duration_for("decolletage"), do: 120
  defp duration_for("heat_treatment"), do: 240
  defp duration_for("assembly"), do: 90
  defp duration_for(_operation_kind), do: 60

  defp lag_for("heat_treatment"), do: 30
  defp lag_for(_operation_kind), do: 0

  defp batch_key_for(order, %{batchable: true}), do: "batch:#{order.material_code}"
  defp batch_key_for(_order, _operation), do: nil

  defp maybe_add_transfer_job(
         order_jobs,
         order_edges,
         next_job_id,
         %{alternative_kind: "cross_plant"} = _routing,
         order,
         buffers_by_plant,
       transport_lanes_by_material,
        resource_index
       ) do
    case Map.get(transport_lanes_by_material, order.material_code) do
      lane when not is_nil(lane) ->
        lane = Map.fetch!(transport_lanes_by_material, order.material_code)
        buffer = hd(Map.fetch!(buffers_by_plant, order.plant_code))

        transfer_job = %Job{
          id: next_job_id,
          duration: lane.transit_minutes,
          required_resources: [
            Map.fetch!(resource_index, {:transport, lane.material_code, lane.source_plant_code, lane.target_plant_code}),
            Map.fetch!(resource_index, {:buffer, buffer.code})
          ],
          release_time: 0,
          due_time: 1_440,
          batch_key: "transfer:#{order.material_code}",
          start_time: nil
        }

        transfer_edge =
          case List.last(order_jobs) do
            nil ->
              nil

            previous_job ->
              %Edge{
                from_job_id: previous_job.id,
                to_job_id: transfer_job.id,
                lag: 0,
                edge_type: "finish_to_start"
              }
          end

        {
          order_jobs ++ [transfer_job],
          if(transfer_edge, do: order_edges ++ [transfer_edge], else: order_edges),
          next_job_id + 1
        }

      _ ->
        {order_jobs, order_edges, next_job_id}
    end
  end

  defp maybe_add_transfer_job(order_jobs, order_edges, next_job_id, _routing, _order, _buffers_by_plant, _transport_lanes_by_material, _resource_index) do
    {order_jobs, order_edges, next_job_id}
  end
end
