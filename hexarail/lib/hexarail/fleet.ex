defmodule HexaRail.Fleet do
  @moduledoc """
  Vehicle Registry holding exact physical characteristics of the SBB/CFF Rolling Stock.
  Used to replace the generic "200m" train with absolute Newtonian reality.
  """

  defmodule RollingStockProfile do
    defstruct [:model, :length_meters, :mass_tonnes, :max_speed_kmh, :acceleration_ms2]
  end

  def sbb_fleet do
    %{
      # Trafic Grandes Lignes (TGL)
      giruno: %RollingStockProfile{
        model: "RABe 501 (Giruno)",
        length_meters: 202.0,
        mass_tonnes: 380.0,
        max_speed_kmh: 250.0,
        acceleration_ms2: 0.8
      },
      astoro: %RollingStockProfile{
        model: "RABe 503 (Astoro)",
        length_meters: 187.4,
        mass_tonnes: 385.0,
        max_speed_kmh: 250.0,
        acceleration_ms2: 0.75
      },
      fv_dosto: %RollingStockProfile{
        model: "RABe 502 (FV-Dosto)",
        length_meters: 199.9, # IR200 version
        mass_tonnes: 450.0,
        max_speed_kmh: 200.0,
        acceleration_ms2: 0.7
      },
      icn: %RollingStockProfile{
        model: "RABDe 500 (ICN)",
        length_meters: 188.8,
        mass_tonnes: 359.0,
        max_speed_kmh: 200.0,
        acceleration_ms2: 0.75
      },
      
      # Trafic Régional (TR)
      flirt: %RollingStockProfile{
        model: "RABe 523 (FLIRT)",
        length_meters: 74.0,
        mass_tonnes: 120.0,
        max_speed_kmh: 160.0,
        acceleration_ms2: 1.2 # High acceleration for S-Bahn
      },
      kiss: %RollingStockProfile{
        model: "RABe 511 (KISS)",
        length_meters: 101.3, # 4-car
        mass_tonnes: 216.0,
        max_speed_kmh: 160.0,
        acceleration_ms2: 1.1
      },
      domino: %RollingStockProfile{
        model: "RBDe 560 (Domino)",
        length_meters: 75.0, # 3-car
        mass_tonnes: 130.0,
        max_speed_kmh: 140.0,
        acceleration_ms2: 0.9
      },

      # Fret (Approximation for SBB Cargo Re 420 + Heavy Wagons)
      fret_heavy: %RollingStockProfile{
        model: "Re 420 + 20 Wagons",
        length_meters: 500.0,
        mass_tonnes: 1600.0,
        max_speed_kmh: 100.0,
        acceleration_ms2: 0.3
      }
    }
  end

  @doc """
  Infers the physical train composition based on the GTFS route short name or ID.
  In a production environment connected directly to CUS/FOS, this would be an API call.
  For the simulation, this provides 100% deterministic physical allocation.
  """
  def infer_profile(route_id) when is_binary(route_id) do
    fleet = sbb_fleet()
    cond do
      String.match?(route_id, ~r/(EC|IC|ICE|RJX)/i) ->
        fleet[:giruno]

      String.match?(route_id, ~r/(IR|RE)/i) ->
        fleet[:fv_dosto]

      String.match?(route_id, ~r/S\d+/i) ->
        flirt = fleet[:flirt]
        %{flirt | length_meters: flirt.length_meters * 2.0, mass_tonnes: flirt.mass_tonnes * 2.0}

      String.match?(route_id, ~r/R/i) ->
        fleet[:domino]

      String.match?(route_id, ~r/EXT/i) ->
        fleet[:fret_heavy]

      true ->
        fleet[:flirt]
    end
  end
end
