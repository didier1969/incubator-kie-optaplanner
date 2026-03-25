defmodule HexaRail.RollingStock.ApiClient do
  @moduledoc """
  Client for the SBB Train Formation API v2.
  Fetches the physical composition of a given commercial train.
  """
  require Logger

  @base_url "https://api.opentransportdata.swiss/formation/v2"

  def fetch_formation(train_number, date) do
    # Requires an API key in a real scenario
    api_key = System.get_env("SBB_API_KEY")
    
    url = "#{@base_url}/#{train_number}/#{date}"
    
    case Req.get(url, headers: [{"Authorization", "Bearer #{api_key}"}]) do
      {:ok, %Req.Response{status: 200, body: body}} ->
        {:ok, parse_formation(body)}
      {:ok, %Req.Response{status: status}} ->
        {:error, "API Error: #{status}"}
      {:error, reason} ->
        {:error, reason}
    end
  end

  def parse_formation(body) do
    formation = body["formation"] || %{}
    wagons = formation["wagons"] || []

    vehicles = Enum.map(wagons, fn w ->
      %{
        uic_number: w["uicNumber"],
        model: w["type"],
        length_meters: w["length"],
        mass_tonnes: w["weight"],
        max_speed_kmh: w["maxSpeed"],
        acceleration_ms2: 0.8 # SBB default approximation if missing from API
      }
    end)

    %{
      total_length_meters: formation["length"],
      total_mass_tonnes: formation["weight"],
      vehicles: vehicles
    }
  end
end
