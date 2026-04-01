# Copyright (c) Didier Stadelmann. All rights reserved.

defmodule HexaFactory.Generator.CapacityBuilder do
  @moduledoc "Builds deterministic maintenance windows and finite buffers."

  alias HexaFactory.Generator.Seed

  @spec build(map(), map(), map(), Seed.state()) :: {map(), Seed.state()}
  def build(_config, topology, materials_data, state) do
    {maintenance_windows, state} =
      Enum.map_reduce(topology.plants, state, fn plant, acc_state ->
        {start_minute, next_state} = Seed.integer(acc_state, 240, 960)

        maintenance = %{
          plant_code: plant.code,
          scope_type: "machine_group",
          scope_code: "#{plant.code}-WC-HEAT",
          start_minute: start_minute,
          end_minute: start_minute + 180
        }

        {maintenance, next_state}
      end)

    buffers =
      materials_data.materials
      |> Enum.filter(&(&1.material_type in ["HALB", "FERT"]))
      |> Enum.map(fn material ->
        plant_code = material.code |> String.split("-") |> Enum.take(2) |> Enum.join("-")

        %{
          code: "#{material.code}-BUF",
          capacity_units: 1_000,
          material_type: material.material_type,
          plant_code: plant_code
        }
      end)

    {%{maintenance_windows: maintenance_windows, buffers: buffers}, state}
  end
end
