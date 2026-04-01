# Copyright (c) Didier Stadelmann. All rights reserved.

defmodule HexaFactory.Solver.ResultDecoder do
  @moduledoc "Decodes a solved generic HexaCore problem into HexaFactory-facing schedules and diagnostics."

  alias HexaFactory.Solver.Diagnostics

  @spec decode(HexaFactory.Generator.Dataset.t(), HexaCore.Domain.Problem.t()) :: map()
  def decode(dataset, solved_problem) do
    resources_by_id = Map.new(solved_problem.resources, &{&1.id, &1})

    machine_schedules =
      solved_problem.jobs
      |> Enum.filter(& &1.start_time)
      |> Enum.flat_map(fn job ->
        job.required_resources
        |> Enum.map(&Map.get(resources_by_id, &1))
        |> Enum.filter(& &1)
        |> Enum.filter(&String.starts_with?(&1.name, "machine:"))
        |> Enum.map(fn resource ->
          %{resource: resource.name, job_id: job.id, start_time: job.start_time, duration: job.duration}
        end)
      end)

    labor_allocations =
      solved_problem.jobs
      |> Enum.filter(& &1.start_time)
      |> Enum.flat_map(fn job ->
        job.required_resources
        |> Enum.map(&Map.get(resources_by_id, &1))
        |> Enum.filter(& &1)
        |> Enum.filter(&String.starts_with?(&1.name, "labor_pool:"))
        |> Enum.map(fn resource ->
          %{resource: resource.name, job_id: job.id, start_time: job.start_time}
        end)
      end)

    transfer_plan =
      solved_problem.edges
      |> Enum.filter(&(&1.lag > 0))
      |> Enum.map(fn edge ->
        %{from_job_id: edge.from_job_id, to_job_id: edge.to_job_id, lag: edge.lag}
      end)

    buffer_diagnostics =
      solved_problem.resources
      |> Enum.filter(&String.starts_with?(&1.name, "buffer:"))
      |> Enum.map(fn resource ->
        %{buffer: resource.name, capacity: resource.capacity}
      end)

    %{
      machine_schedules: machine_schedules,
      labor_allocations: labor_allocations,
      transfer_plan: transfer_plan,
      buffer_diagnostics: buffer_diagnostics,
      score_breakdown: Diagnostics.score_breakdown(dataset, solved_problem)
    }
  end
end
