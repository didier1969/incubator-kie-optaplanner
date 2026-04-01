# Copyright (c) Didier Stadelmann. All rights reserved.

defmodule HexaFactory.CLI do
  @moduledoc false

  alias HexaFactory.Generator.Dataset
  alias HexaFactory.Ingestion.PersistedDataset
  alias HexaFactory.Solver.Facade

  @spec bootstrap_planning_runtime!() :: :ok
  def bootstrap_planning_runtime! do
    Application.put_env(:hexarail, :start_simulation_engine, false)

    if Mix.env() != :test do
      Mix.Task.reenable("ecto.create")
      Mix.Task.reenable("ecto.migrate")
      Mix.Task.run("ecto.create", ["--quiet"])
      Mix.Task.run("ecto.migrate", ["--quiet"])
    end

    Mix.Task.reenable("app.start")
    Mix.Task.run("app.start")
    :ok
  end

  @spec parse_common_opts([String.t()], keyword()) :: keyword()
  def parse_common_opts(args, defaults \\ []) do
    {opts, _argv, _invalid} =
      OptionParser.parse(args,
        strict: [profile: :string, seed: :integer, iterations: :integer]
      )

    [
      profile: parse_profile(Keyword.get(opts, :profile, Keyword.get(defaults, :profile, "volumetry_smoke"))),
      seed: Keyword.get(opts, :seed, Keyword.get(defaults, :seed, 1001)),
      iterations: Keyword.get(opts, :iterations, Keyword.get(defaults, :iterations, 200))
    ]
  end

  @spec build_dataset(keyword()) :: map()
  def build_dataset(opts) do
    profile = Keyword.fetch!(opts, :profile)
    seed = Keyword.fetch!(opts, :seed)
    dataset = Dataset.build(seed: seed, profile: profile)

    %{profile: profile, seed: seed, dataset: dataset}
  end

  @spec persist_dataset(keyword()) :: map()
  def persist_dataset(opts) do
    %{profile: profile, seed: seed, dataset: dataset} = build_dataset(opts)
    persisted = PersistedDataset.persist!(dataset)

    %{
      profile: profile,
      seed: seed,
      dataset: dataset,
      persisted: persisted
    }
  end

  @spec solve_dataset(keyword()) :: map()
  def solve_dataset(opts) do
    iterations = Keyword.fetch!(opts, :iterations)
    %{profile: profile, seed: seed, dataset: dataset, persisted: persisted} = persist_dataset(opts)
    reloaded = PersistedDataset.load!(persisted.dataset_ref)
    result = Facade.solve(reloaded, iterations: iterations)

    %{
      profile: profile,
      seed: seed,
      iterations: iterations,
      dataset: dataset,
      persisted: persisted,
      reloaded: reloaded,
      result: result
    }
  end

  @spec print_dataset_summary(map(), String.t()) :: :ok
  def print_dataset_summary(%{profile: profile, seed: seed, dataset: dataset}, label) do
    IO.puts("HexaFactory #{label}")
    IO.puts("profile=#{profile} seed=#{seed}")
    IO.puts("signature=#{dataset.signature}")

    IO.puts(
      "plants=#{length(dataset.plants)} machines=#{length(dataset.machines)} orders=#{length(dataset.production_orders)}"
    )
  end

  @spec print_persist_summary(map(), String.t()) :: :ok
  def print_persist_summary(%{profile: profile, seed: seed, dataset: dataset, persisted: persisted}, label) do
    IO.puts("HexaFactory #{label}")
    IO.puts("profile=#{profile} seed=#{seed}")
    IO.puts("dataset_ref=#{persisted.dataset_ref} signature=#{persisted.signature}")

    IO.puts(
      "plants=#{length(dataset.plants)} machines=#{length(dataset.machines)} orders=#{length(dataset.production_orders)}"
    )
  end

  @spec print_solve_summary(map(), String.t()) :: :ok
  def print_solve_summary(
        %{profile: profile, seed: seed, iterations: iterations, persisted: persisted, reloaded: reloaded, result: result},
        label
      ) do
    IO.puts("HexaFactory #{label}")
    IO.puts("profile=#{profile} seed=#{seed} iterations=#{iterations}")
    IO.puts("dataset_ref=#{persisted.dataset_ref} signature=#{reloaded.signature}")

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
