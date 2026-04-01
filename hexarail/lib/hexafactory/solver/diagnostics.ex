# Copyright (c) Didier Stadelmann. All rights reserved.

defmodule HexaFactory.Solver.Diagnostics do
  @moduledoc "Computes vertical-facing diagnostics from a solved HexaFactory problem."

  alias HexaFactory.Constraints.{
    Batching,
    BufferCapacity,
    DueDate,
    LaborSkill,
    MachineCost,
    Maintenance,
    ScrapYield,
    SetupSequence,
    TransferBatch,
    Transport
  }

  @spec score_breakdown(HexaFactory.Generator.Dataset.t(), HexaCore.Domain.Problem.t()) :: map()
  def score_breakdown(dataset, solved_problem) do
    [
      DueDate,
      SetupSequence,
      MachineCost,
      LaborSkill,
      Batching,
      TransferBatch,
      BufferCapacity,
      ScrapYield,
      Maintenance,
      Transport
    ]
    |> Enum.reduce(%{}, fn module, acc ->
      Map.merge(acc, module.measure(dataset, solved_problem))
    end)
  end
end
