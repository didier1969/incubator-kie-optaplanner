# Copyright (c) Didier Stadelmann. All rights reserved.

defmodule HexaFactory.Solver.Facade do
  @moduledoc "Vertical solver entrypoint for HexaFactory."

  alias HexaCore.Nif
  alias HexaFactory.Adapter.ProblemProjection
  alias HexaFactory.Solver.ResultDecoder

  @spec solve(HexaFactory.Generator.Dataset.t(), keyword()) :: map()
  def solve(dataset, opts \\ []) do
    iterations = Keyword.get(opts, :iterations, 128)

    solved_problem =
      dataset
      |> ProblemProjection.build()
      |> Nif.optimize_problem_core(iterations)

    ResultDecoder.decode(dataset, solved_problem)
  end
end
