# Copyright (c) Didier Stadelmann. All rights reserved.

defmodule HexaFactory.Generator.TopologyBuilder do
  @moduledoc "Builds deterministic enterprise topology and finite-capacity assets."

  alias HexaFactory.Generator.Seed

  @spec build(map(), Seed.state()) :: {map(), Seed.state()}
  def build(config, state) do
    company_codes = [%{code: "CC-01", name: "Hexa Manufacturing Group"}]

    {plants, state} =
      Enum.map_reduce(1..config.plant_count, state, fn plant_index, acc_state ->
        {kind, next_state} = Seed.pick(acc_state, ["decolletage", "assembly", "heat"])

        plant = %{
          code: "PLANT-#{pad3(plant_index)}",
          name: "Plant #{pad3(plant_index)}",
          company_code_code: "CC-01",
          typology: kind
        }

        {plant, next_state}
      end)

    storage_locations =
      Enum.flat_map(plants, fn plant ->
        [
          %{code: "#{plant.code}-ROH", name: "#{plant.code} Raw", kind: "roh", plant_code: plant.code},
          %{code: "#{plant.code}-HALB", name: "#{plant.code} Halb", kind: "halb", plant_code: plant.code},
          %{code: "#{plant.code}-FERT", name: "#{plant.code} Fert", kind: "fert", plant_code: plant.code}
        ]
      end)

    work_centers =
      Enum.flat_map(plants, fn plant ->
        [
          %{code: "#{plant.code}-WC-DEC", name: "#{plant.code} Decolletage", kind: "decolletage", plant_code: plant.code},
          %{code: "#{plant.code}-WC-HEAT", name: "#{plant.code} Heat", kind: "heat_treatment", plant_code: plant.code},
          %{code: "#{plant.code}-WC-ASM", name: "#{plant.code} Assembly", kind: "assembly", plant_code: plant.code}
        ]
      end)

    work_centers_by_plant = Enum.group_by(work_centers, & &1.plant_code)

    {machines, state} =
      Enum.map_reduce(plants, state, fn plant, acc_state ->
        plant_work_centers = Map.fetch!(work_centers_by_plant, plant.code)

        Enum.map_reduce(1..config.machines_per_plant, acc_state, fn machine_index, machine_state ->
          work_center = Enum.at(plant_work_centers, rem(machine_index - 1, length(plant_work_centers)))
          {hourly_cost_cents, next_state} = Seed.integer(machine_state, 9_000, 18_000)

          machine = %{
            code: "#{plant.code}-M-#{pad3(machine_index)}",
            name: "#{work_center.name} Machine #{pad3(machine_index)}",
            hourly_cost_cents: hourly_cost_cents,
            active: true,
            plant_code: work_center.plant_code,
            work_center_code: work_center.code
          }

          {machine, next_state}
        end)
      end)

    machines = List.flatten(machines)

    skills = [
      %{code: "SETTER-L3", name: "Level 3 Setter"},
      %{code: "THERM-OP", name: "Thermal Operator"},
      %{code: "ASSEMBLER", name: "Assembler"}
    ]

    operators =
      Enum.with_index(plants, 1)
      |> Enum.map(fn {plant, operator_index} ->
        skill_code =
          case rem(operator_index, 3) do
            1 -> "SETTER-L3"
            2 -> "THERM-OP"
            _ -> "ASSEMBLER"
          end

        %{
          code: "#{plant.code}-OP-#{pad2(operator_index)}",
          name: "Operator #{pad2(operator_index)}",
          primary_skill_code: skill_code,
          home_plant_code: plant.code
        }
      end)

    labor_pools =
      Enum.map(plants, fn plant ->
        %{code: "#{plant.code}-POOL", name: "#{plant.code} Pool", plant_code: plant.code}
      end)

    tools = [
      %{code: "TOOL-HOB", name: "Hob Cutter", tool_type: "hob"},
      %{code: "TOOL-FURNACE", name: "Furnace Rack", tool_type: "thermal_fixture"}
    ]

    tool_instances =
      Enum.flat_map(plants, fn plant ->
        [
          %{code: "#{plant.code}-TOOL-HOB-01", status: "available", tool_code: "TOOL-HOB", current_plant_code: plant.code},
          %{code: "#{plant.code}-TOOL-FURNACE-01", status: "available", tool_code: "TOOL-FURNACE", current_plant_code: plant.code}
        ]
      end)

    topology = %{
      company_codes: company_codes,
      plants: plants,
      storage_locations: storage_locations,
      work_centers: work_centers,
      machines: machines,
      skills: skills,
      operators: operators,
      labor_pools: labor_pools,
      tools: tools,
      tool_instances: tool_instances
    }

    {topology, state}
  end

  defp pad2(value), do: value |> Integer.to_string() |> String.pad_leading(2, "0")
  defp pad3(value), do: value |> Integer.to_string() |> String.pad_leading(3, "0")
end
