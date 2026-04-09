# Copyright (c) Didier Stadelmann. All rights reserved.

defmodule Mix.Tasks.Hexafactory.GenerateDataset do
  @shortdoc "Generates a large-scale offline dataset for NCO training"

  use Mix.Task

  alias HexaFactory.CLI
  alias HexaFactory.Generator.Dataset
  alias HexaFactory.Ingestion.PersistedDataset
  alias HexaRail.Repo

  @impl Mix.Task
  def run(args) do
    CLI.bootstrap_planning_runtime!()

    {opts, _argv, _invalid} =
      OptionParser.parse(args,
        strict: [profile: :string, count: :integer, concurrency: :integer]
      )

    profile_opt = Keyword.get(opts, :profile, "curriculum")
    count = Keyword.get(opts, :count, 100)
    
    # Ecto pool size safety (protecting PostgreSQL from connection saturation)
    db_pool_size = Application.get_env(:hexarail, Repo)[:pool_size] || 10
    safe_max_concurrency = max(1, db_pool_size - 2)
    
    requested_concurrency = Keyword.get(opts, :concurrency, System.schedulers_online())
    concurrency = min(requested_concurrency, safe_max_concurrency)

    IO.puts("Starting generation of #{count} datasets for profile '#{profile_opt}' with DB-safe concurrency #{concurrency} (Pool size: #{db_pool_size})...")

    start_time = System.monotonic_time()

    1..count
    |> Task.async_stream(
      fn seed ->
        # Curriculum Learning: Randomize the industrial topology size if requested
        profile = if profile_opt == "curriculum" do
          Enum.random([:smoke, :interaction, :volumetry_smoke, :target_60_plant])
        else
          String.to_atom(profile_opt)
        end
        
        dataset = Dataset.build(seed: seed, profile: profile)
        persisted = PersistedDataset.persist!(dataset)
        {seed, profile, persisted.dataset_ref}
      end,
      max_concurrency: concurrency,
      timeout: :infinity
    )
    |> Enum.reduce(0, fn
      {:ok, {seed, actual_profile, _ref}}, acc ->
        if rem(acc + 1, 10) == 0 do
          IO.puts("Generated dataset #{acc + 1}/#{count} (latest seed: #{seed}, profile: #{actual_profile})")
        end
        acc + 1
      {:error, reason}, acc ->
        IO.puts(:stderr, "Failed to generate dataset: #{inspect(reason)}")
        acc
    end)

    end_time = System.monotonic_time()
    duration_ms = System.convert_time_unit(end_time - start_time, :native, :millisecond)

    IO.puts("Successfully generated #{count} datasets in #{duration_ms} ms (#{(duration_ms / count) |> Float.round(2)} ms/dataset).")
  end
end
