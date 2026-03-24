defmodule HexaPlanner.RollingStock.ApiClientTest do
  use ExUnit.Case
  alias HexaPlanner.RollingStock.ApiClient

  test "parses train formation API response correctly" do
    mock_response = %{
      "trainNumber" => "IC 1",
      "formation" => %{
        "length" => 202.0,
        "weight" => 380.0,
        "wagons" => [
          %{"uicNumber" => "938505010015", "type" => "RABe 501", "length" => 202.0, "weight" => 380.0, "maxSpeed" => 250.0}
        ]
      }
    }

    result = ApiClient.parse_formation(mock_response)
    
    assert result.total_length_meters == 202.0
    assert result.total_mass_tonnes == 380.0
    assert length(result.vehicles) == 1
    
    vehicle = hd(result.vehicles)
    assert vehicle.uic_number == "938505010015"
    assert vehicle.model == "RABe 501"
  end
end
