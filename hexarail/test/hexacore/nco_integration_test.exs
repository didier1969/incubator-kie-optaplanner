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
    tensor = Nif.extract_features_core(encoder_ref, problem, 0.0)
    
    assert is_map(tensor)
    assert Map.has_key?(tensor, :job_features)
    assert Map.has_key?(tensor, :resource_features)
    assert Map.has_key?(tensor, :global_features)
    assert Map.has_key?(tensor, :scalars)
    
    # Verify dimensions are correct and not empty
    assert length(tensor.job_features) == length(problem.jobs)
    assert length(hd(tensor.job_features)) == 9
    assert length(tensor.resource_features) == length(problem.resources)
    assert length(hd(tensor.resource_features)) == 29
    
    # Check fixed global features (1 current_time + 16 metrics)
    assert length(tensor.global_features) == 17
    assert length(tensor.scalars) == 2
    
    # Ensure the vectors contain actual floats
    assert is_list(hd(tensor.job_features))
    assert is_float(hd(hd(tensor.job_features)))

    # Verify JSON vocabulary export
    vocab_json = Nif.export_feature_vocabularies(encoder_ref)
    assert is_binary(vocab_json)
    assert String.contains?(vocab_json, "group_id_dict")
    assert String.contains?(vocab_json, "edge_type_dict")
    assert String.contains?(vocab_json, "resource_name_dict")
    
    # Verify JSON import works
    imported_ref = Nif.import_feature_vocabularies(vocab_json)
    assert is_reference(imported_ref)
    
    # The imported encoder should preserve the frozen state
    assert Nif.export_feature_vocabularies(imported_ref) == vocab_json
  end
end
