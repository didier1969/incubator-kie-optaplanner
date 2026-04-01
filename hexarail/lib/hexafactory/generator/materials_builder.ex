# Copyright (c) Didier Stadelmann. All rights reserved.

defmodule HexaFactory.Generator.MaterialsBuilder do
  @moduledoc "Builds deterministic material masters and BOM relations."

  alias Decimal, as: D

  @spec build(map(), map(), term()) :: {map(), term()}
  def build(_config, topology, state) do
    materials =
      Enum.with_index(topology.plants, 1)
      |> Enum.flat_map(fn {plant, index} ->
        [
          %{code: "#{plant.code}-ROH-#{index}", description: "Raw bar #{index}", material_type: "ROH", base_uom: "KG"},
          %{code: "#{plant.code}-HALB-#{index}", description: "Intermediate #{index}", material_type: "HALB", base_uom: "EA"},
          %{code: "#{plant.code}-T0-#{index}", description: "Sub assembly #{index}", material_type: "HALB", base_uom: "EA"},
          %{code: "#{plant.code}-T1-#{index}", description: "Finished #{index}", material_type: "FERT", base_uom: "EA"}
        ]
      end)

    bom_items =
      Enum.with_index(topology.plants, 1)
      |> Enum.flat_map(fn {plant, index} ->
        roh_code = "#{plant.code}-ROH-#{index}"
        halb_code = "#{plant.code}-HALB-#{index}"
        t0_code = "#{plant.code}-T0-#{index}"
        t1_code = "#{plant.code}-T1-#{index}"

        [
          %{parent_material_code: halb_code, component_material_code: roh_code, quantity_per_parent: D.new("1.00"), scrap_rate: D.new("0.05")},
          %{parent_material_code: t0_code, component_material_code: halb_code, quantity_per_parent: D.new("2.00"), scrap_rate: D.new("0.08")},
          %{parent_material_code: t1_code, component_material_code: t0_code, quantity_per_parent: D.new("1.00"), scrap_rate: D.new("0.02")}
        ]
      end)

    {%{materials: materials, bom_items: bom_items}, state}
  end
end
