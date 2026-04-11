# Copyright (c) Didier Stadelmann. All rights reserved.

defmodule HexaFactory.Adapter.ProblemProjection do
  @moduledoc "Builds a generic HexaCore problem from a HexaFactory dataset."

  alias HexaCore.Domain.Problem
  alias HexaCore.Domain.SetupTransition
  alias HexaFactory.Adapter.{JobProjection, ResourceProjection, ScoreProjection}

  @spec build(HexaFactory.Generator.Dataset.t()) :: Problem.t()
  def build(dataset) do
    {resources, resource_index} = ResourceProjection.build(dataset)
    {jobs, edges} = JobProjection.build(dataset, resource_index)

    # In a real SOTA factory, group_ids map to setup profiles.
    # For now, we create a simplified fallback transition matrix mapping all unique group_ids
    # to each other using the first dataset transition duration, or 45 mins.
    # This prepares the Rust engine to consume a real dynamic matrix.
    base_duration =
      case List.first(dataset.setup_transitions) do
        %{duration_minutes: d} -> d
        _ -> 45
      end

    group_ids =
      jobs
      |> Enum.map(& &1.group_id)
      |> Enum.reject(&is_nil/1)
      |> Enum.uniq()

    setup_transitions =
      for from <- group_ids, to <- group_ids, from != to do
        %SetupTransition{from_group: from, to_group: to, duration: base_duration}
      end

    %Problem{
      id: "hexafactory:#{dataset.signature}",
      resources: resources,
      jobs: jobs,
      edges: edges,
      score_components: ScoreProjection.build(dataset),
      setup_transitions: setup_transitions
    }
  end
end
