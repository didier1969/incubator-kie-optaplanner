defmodule HexaFactory.MLOps.TensorExporterTest do
  use HexaRail.DataCase
  alias HexaFactory.MLOps.TensorExporter
  alias HexaFactory.Domain.PlanningHorizon
  alias HexaRail.Repo

  test "exports populated planning horizons to JSONL" do
    # 1. Insert a mock planning horizon
    %PlanningHorizon{
      code: "mock-1",
      seed: 42,
      profile: "smoke",
      signature: "abc",
      payload: <<0>>,
      tensor_x_json: %{"job_features" => [[1.0]]},
      tensor_y_json: %{"optimal_start_times" => [10]}
    }
    |> Repo.insert!()

    # 2. Export to a temporary file
    temp_dir = System.tmp_dir!()
    export_path = Path.join(temp_dir, "test_export.jsonl")
    
    assert :ok = TensorExporter.export_to_file(export_path)

    # 3. Verify file content
    assert File.exists?(export_path)
    content = File.read!(export_path)
    assert content =~ "\"x\":{\"job_features\":[[1.0]]}"
    assert content =~ "\"y\":{\"optimal_start_times\":[10]}"
  end
end
