# Copyright (c) Didier Stadelmann. All rights reserved.

defmodule HexaFactory.Adapter.ProblemProjection do
  @moduledoc "Builds a generic HexaCore problem from a HexaFactory dataset."

  alias HexaCore.Domain.Problem
  alias HexaFactory.Adapter.{JobProjection, ResourceProjection, ScoreProjection}

  @spec build(HexaFactory.Generator.Dataset.t()) :: Problem.t()
  def build(dataset) do
    {resources, resource_index} = ResourceProjection.build(dataset)
    {jobs, edges} = JobProjection.build(dataset, resource_index)

    %Problem{
      id: "hexafactory:#{dataset.signature}",
      resources: resources,
      jobs: jobs,
      edges: edges,
      score_components: ScoreProjection.build(dataset)
    }
  end
end
