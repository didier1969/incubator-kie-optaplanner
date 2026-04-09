# Copyright (c) Didier Stadelmann. All rights reserved.

defmodule Mix.Tasks.Hexafactory.GenerateDataset do
  @shortdoc "Generates a large-scale offline dataset for NCO training"

  use Mix.Task

  alias HexaFactory.CLI
  alias HexaFactory.Generator.Dataset
  alias HexaFactory.Ingestion.PersistedDataset

  @impl Mix.Task
  def run(args) do
    CLI.bootstrap_planning_runtime!()

    {opts, _argv, _invalid} =
      OptionParser.parse(args,
        strict: [profile: :string, count: :integer, concurrency: :integer]
      )

    profile = String.to_atom(Keyword.get(opts, :profile, "volumetry_smoke"))
    count = Keyword.get(opts, :count, 100)
    concurrency = Keyword.get(opts, :concurrency, System.schedulers_online())

    IO.puts("Starting generation of #{count} datasets for profile '#{profile}' with concurrency #{concurrency}...")

    start_time = System.monotonic_time()

    1..count
    |> Task.async_stream(
      fn seed ->
        dataset = Dataset.build(seed: seed, profile: profile)
        persisted = PersistedDataset.persist!(dataset)
        {seed, persisted.dataset_ref}
      end,
      max_concurrency: concurrency,
      timeout: :infinity
    )
    |> Enum.reduce(0, fn
      {:ok, {seed, _ref}}, acc ->
        if rem(acc + 1, 10) == 0 do
          IO.puts("Generated dataset #{acc + 1}/#{count} (latest seed: #{seed})")
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
