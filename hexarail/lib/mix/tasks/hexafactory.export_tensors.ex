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