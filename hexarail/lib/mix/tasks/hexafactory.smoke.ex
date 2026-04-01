# Copyright (c) Didier Stadelmann. All rights reserved.

defmodule Mix.Tasks.Hexafactory.Smoke do
  @shortdoc "Runs a reduced-volume HexaFactory end-to-end smoke path"

  use Mix.Task

  alias HexaFactory.Generator.Dataset
  alias HexaFactory.Ingestion.PersistedDataset
  alias HexaFactory.Solver.Facade

  @impl Mix.Task
  def run(args) do
    Mix.Task.run("app.start")

    {opts, _argv, _invalid} =
      OptionParser.parse(args,
        strict: [profile: :string, seed: :integer, iterations: :integer]
      )

    profile = parse_profile(Keyword.get(opts, :profile, "volumetry_smoke"))
    seed = Keyword.get(opts, :seed, 1001)
    iterations = Keyword.get(opts, :iterations, 200)

    dataset = Dataset.build(seed: seed, profile: profile)
    persisted = PersistedDataset.persist!(dataset)
    reloaded = PersistedDataset.load!(persisted.dataset_ref)
    result = Facade.solve(reloaded, iterations: iterations)

    IO.puts("HexaFactory smoke")
    IO.puts("profile=#{profile} seed=#{seed} iterations=#{iterations}")
    IO.puts("signature=#{reloaded.signature}")

    IO.puts(
      "plants=#{length(reloaded.plants)} machines=#{length(reloaded.machines)} orders=#{length(reloaded.production_orders)}"
    )

    IO.puts(
      "late_jobs=#{result.score_breakdown.late_jobs} overdue_minutes=#{result.score_breakdown.overdue_minutes} " <>
        "setup_minutes=#{result.score_breakdown.setup_minutes} transfer_minutes=#{result.score_breakdown.transfer_minutes}"
    )
  end

  defp parse_profile("smoke"), do: :smoke
  defp parse_profile("interaction"), do: :interaction
  defp parse_profile("volumetry_smoke"), do: :volumetry_smoke
  defp parse_profile("target_60_plant"), do: :target_60_plant
  defp parse_profile(profile) when is_atom(profile), do: profile
  defp parse_profile(_profile), do: :volumetry_smoke
end
