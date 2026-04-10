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
        strict: [profile: :string, count: :integer, concurrency: :integer, iterations: :integer]
      )

    profile_opt = Keyword.get(opts, :profile, "curriculum")
    count = Keyword.get(opts, :count, 100)
    
    # Enable Deep Solve for Expert Trajectories (10,000 iterations to approach global optimum)
    iterations = Keyword.get(opts, :iterations, 10_000)
    
    # Ecto pool size safety (protecting PostgreSQL from connection saturation)
    db_pool_size = Application.get_env(:hexarail, Repo)[:pool_size] || 10
    safe_max_concurrency = max(1, db_pool_size - 2)
    
    requested_concurrency = Keyword.get(opts, :concurrency, System.schedulers_online())
    concurrency = min(requested_concurrency, safe_max_concurrency)

    IO.puts("Starting offline generation of #{count} Expert Trajectories (Profile: '#{profile_opt}', Deep Solve Iterations: #{iterations}, DB-safe Concurrency: #{concurrency})...")

    start_time = System.monotonic_time()

    # Initialize the ML Latent Space Encoder to populate global vocabularies during generation
    encoder_ref = HexaCore.Nif.init_feature_encoder()

    1..count
    |> Task.async_stream(
      fn seed ->
        # 1. Curriculum Learning
        profile = if profile_opt == "curriculum" do
          Enum.random([:smoke, :interaction, :volumetry_smoke, :target_60_plant])
        else
          String.to_atom(profile_opt)
        end
        
        # 2. Dataset Split (Train/Val/Test = 80/10/10) via deterministic hash of the seed
        split = case rem(seed, 10) do
          0 -> "test"
          1 -> "val"
          _ -> "train"
        end
        
        # 3. State Generation
        dataset = Dataset.build(seed: seed, profile: profile)
        persisted = PersistedDataset.persist!(dataset, split)
        
        # 4. Ground Truth Resolution (Deep Solve Expert Trajectory)
        reloaded = PersistedDataset.load!(persisted.dataset_ref)
        
        abstract_problem = HexaFactory.Adapter.ProblemProjection.build(reloaded)
        
        # ML Metric Collection: Extract the initial state (X) before optimization (t=0)
        tensor_x = HexaCore.Nif.extract_features_core(encoder_ref, abstract_problem, 0.0)
        
        solved_problem = 
          abstract_problem
          |> HexaCore.Nif.optimize_problem_core("metaheuristic", iterations)
          
        # ML Metric Collection: Extract the final solved state (Y) after optimization
        # For the final state, we use the makespan as the current time 't'
        final_time = 
          solved_problem.jobs
          |> Enum.map(&((&1.start_time || 0) + &1.duration))
          |> Enum.max(fn -> 0 end)
          |> then(&(&1 * 1.0))
          
        tensor_y = HexaCore.Nif.extract_features_core(encoder_ref, solved_problem, final_time)
          
        decoded = HexaFactory.Solver.ResultDecoder.decode(reloaded, solved_problem)
        metrics = decoded.score_breakdown
        
        # 5. Expert Persistence
        PersistedDataset.persist_expert_trajectory!(persisted.dataset_ref, solved_problem, metrics, tensor_x, tensor_y)
        
        {seed, profile, split, persisted.dataset_ref, metrics}
      end,
      max_concurrency: concurrency,
      timeout: :infinity
    )
    |> Enum.reduce(0, fn
      {:ok, {seed, actual_profile, split, _ref, metrics}}, acc ->
        if rem(acc + 1, 10) == 0 do
          IO.puts("Generated expert trajectory #{acc + 1}/#{count} (seed: #{seed}, profile: #{actual_profile}, split: #{split}, late_jobs: #{metrics.late_jobs}, overdue: #{metrics.overdue_minutes}m)")
        end
        acc + 1
      {:error, reason}, acc ->
        IO.puts(:stderr, "Failed to generate dataset: #{inspect(reason)}")
        acc
    end)

    # ML Pipeline Completion: Export and save the global vocabulary
    HexaCore.Nif.freeze_feature_encoder(encoder_ref)
    vocab_json = HexaCore.Nif.export_feature_vocabularies(encoder_ref)
    File.write!("dataset_vocabularies.json", vocab_json)
    IO.puts("Exported ML Categorical Vocabularies to dataset_vocabularies.json")

    end_time = System.monotonic_time()
    duration_ms = System.convert_time_unit(end_time - start_time, :native, :millisecond)

    IO.puts("Successfully generated #{count} expert trajectories in #{duration_ms} ms (#{(duration_ms / count) |> Float.round(2)} ms/dataset).")
  end
end
