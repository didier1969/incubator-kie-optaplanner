# Copyright (c) Didier Stadelmann. All rights reserved.

defmodule Mix.Tasks.Hexarail.Smoke do
  @shortdoc "Runs a deterministic HexaRail smoke path through perturbation and resolution"

  use Mix.Task

  alias HexaRail.Smoke

  @impl Mix.Task
  def run(args) do
    {opts, _argv, _invalid} =
      OptionParser.parse(args,
        strict: [strategy: :string, query_time: :integer, perturbation_start_time: :integer]
      )

    summary =
      Smoke.run(
        strategy: parse_strategy(Keyword.get(opts, :strategy, "greedy")),
        query_time: Keyword.get(opts, :query_time, 150),
        perturbation_start_time: Keyword.get(opts, :perturbation_start_time, 120)
      )

    Smoke.print_summary(summary)
  end

  defp parse_strategy("greedy"), do: :greedy
  defp parse_strategy("local_search"), do: :local_search
  defp parse_strategy(strategy) when is_atom(strategy), do: strategy
  defp parse_strategy(_strategy), do: :greedy
end
