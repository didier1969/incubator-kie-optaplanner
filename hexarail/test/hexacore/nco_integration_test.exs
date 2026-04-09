# Copyright (c) Didier Stadelmann. All rights reserved.

defmodule HexaCore.NCOIntegrationTest do
  use ExUnit.Case, async: false

  alias HexaCore.Nif
  alias HexaFactory.Generator.Dataset
  alias HexaFactory.Adapter.ProblemProjection

  setup do
    # Ensure HexaFactory components can run
    Application.put_env(:hexarail, :start_simulation_engine, false)
    :ok
  end

  test "extract_features_core successfully parses a real industrial dataset statefully without crashing" do
    # Generate a realistic JSSP dataset
    dataset = Dataset.build(seed: 42, profile: :smoke)
    
    # Project to generic problem
    problem = ProblemProjection.build(dataset)
    
    # Initialize the Stateful Encoder Resource
    encoder_ref = Nif.init_feature_encoder()
    assert is_reference(encoder_ref)

    # Freeze vocabulary to test state mutations
    assert Nif.freeze_feature_encoder(encoder_ref) == :ok
    
    # Extract tensor data via Rust NIF using the initialized resource
    tensor = Nif.extract_features_core(encoder_ref, problem)
    
    assert is_map(tensor)
    assert Map.has_key?(tensor, :job_features)
    assert Map.has_key?(tensor, :resource_features)
    assert Map.has_key?(tensor, :global_features)
    
    # Verify dimensions are correct and not empty
    assert length(tensor.job_features) == length(problem.jobs)
    assert length(tensor.resource_features) == length(problem.resources)
    
    # Check fixed global features (4 metrics)
    assert length(tensor.global_features) == 4
    
    # Ensure the vectors contain actual floats
    assert is_list(hd(tensor.job_features))
    assert is_float(hd(hd(tensor.job_features)))
  end
end
