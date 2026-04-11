# Phase 1: MLOps - Training the Neural Brain (GNN) Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Create a robust MLOps data export pipeline that extracts SOTA graph tensors ($X$) and expert trajectories ($Y$) from PostgreSQL to flat files for offline PyTorch/Candle training.

**Architecture:** We will create an Elixir Mix Task (`mix hexafactory.export_tensors`) that queries `HexaFactory.Domain.PlanningHorizon` records (where `tensor_x_json` is not null), structures them into a standard Deep Learning JSONLines format (`.jsonl`), and saves them to the filesystem.

**Tech Stack:** Elixir, PostgreSQL, Jason (for JSON generation).

---

### Task 1: Create the Tensor Exporter Module

**Files:**
- Create: `hexarail/lib/hexafactory/mlops/tensor_exporter.ex`
- Test: `hexarail/test/hexafactory/mlops/tensor_exporter_test.exs`

**Step 1: Write the failing test**

```elixir
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
```

**Step 2: Run test to verify it fails**

Run: `nix develop --command bash -c "cd hexarail && mix test test/hexafactory/mlops/tensor_exporter_test.exs"`
Expected: FAIL with "module HexaFactory.MLOps.TensorExporter is not available".

**Step 3: Write minimal implementation**

```elixir
defmodule HexaFactory.MLOps.TensorExporter do
  @moduledoc "Exports tensor data to JSONLines for offline ML training."
  
  import Ecto.Query
  alias HexaFactory.Domain.PlanningHorizon
  alias HexaRail.Repo

  @spec export_to_file(String.t()) :: :ok | {:error, any()}
  def export_to_file(path) do
    query = 
      from h in PlanningHorizon,
        where: not is_nil(h.tensor_x_json) and not is_nil(h.tensor_y_json),
        select: %{id: h.id, x: h.tensor_x_json, y: h.tensor_y_json}

    File.open(path, [:write, :utf8], fn file ->
      Repo.all(query)
      |> Enum.each(fn record ->
        json_line = Jason.encode!(record)
        IO.puts(file, json_line)
      end)
    end)
    
    :ok
  end
end
```

**Step 4: Run test to verify it passes**

Run: `nix develop --command bash -c "cd hexarail && mix test test/hexafactory/mlops/tensor_exporter_test.exs"`
Expected: PASS

**Step 5: Commit**

```bash
git add hexarail/lib/hexafactory/mlops/tensor_exporter.ex hexarail/test/hexafactory/mlops/tensor_exporter_test.exs
git commit -m "feat(mlops): implement JSONLines tensor exporter module"
```

### Task 2: Create the Mix Task for Execution

**Files:**
- Create: `hexarail/lib/mix/tasks/hexafactory.export_tensors.ex`

**Step 1: Write minimal implementation (no complex test needed for Mix task wrapper)**

```elixir
defmodule Mix.Tasks.Hexafactory.ExportTensors do
  @moduledoc "Mix task to export X and Y tensors to a JSONLines file."
  use Mix.Task

  @shortdoc "Exports ML tensors to JSONLines"
  def run(args) do
    Mix.Task.run("app.start")

    {opts, _} = OptionParser.parse!(args, strict: [output: :string])
    output_path = Keyword.get(opts, :output, "tensors_export.jsonl")

    IO.puts("Exporting tensors to #{output_path}...")
    
    case HexaFactory.MLOps.TensorExporter.export_to_file(output_path) do
      :ok -> IO.puts("Export complete.")
      {:error, reason} -> IO.puts("Export failed: #{inspect(reason)}")
    end
  end
end
```

**Step 2: Commit**

```bash
git add hexarail/lib/mix/tasks/hexafactory.export_tensors.ex
git commit -m "feat(mlops): create mix task to export tensors"
```