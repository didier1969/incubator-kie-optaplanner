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
