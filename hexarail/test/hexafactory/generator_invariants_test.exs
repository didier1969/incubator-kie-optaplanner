# Copyright (c) Didier Stadelmann. All rights reserved.

defmodule HexaFactory.GeneratorInvariantsTest do
  use ExUnit.Case, async: true

  alias HexaFactory.Generator.Dataset

  test "generator emits the full industrial feature set" do
    dataset = Dataset.build(seed: 42, profile: :smoke)

    assert dataset.company_codes != []
    assert dataset.plants != []
    assert dataset.storage_locations != []
    assert dataset.materials != []
    assert dataset.work_centers != []
    assert dataset.machines != []
    assert dataset.skills != []
    assert dataset.operators != []
    assert dataset.labor_pools != []
    assert dataset.tools != []
    assert dataset.tool_instances != []
    assert dataset.transport_lanes != []
    assert dataset.bom_items != []
    assert dataset.routings != []
    assert dataset.routing_operations != []
    assert dataset.production_orders != []
    assert dataset.setup_profiles != []
    assert dataset.setup_transitions != []
    assert dataset.maintenance_windows != []
    assert dataset.buffers != []
    assert dataset.batch_policies != []
  end

  test "generator honors target machines per plant and keeps machine references coherent" do
    dataset = Dataset.build(seed: 42, profile: :interaction)

    work_center_codes = MapSet.new(dataset.work_centers, & &1.code)

    machines_by_plant =
      Enum.group_by(dataset.machines, & &1.plant_code)

    assert map_size(machines_by_plant) == dataset.metadata.target_topology.plant_count

    Enum.each(dataset.plants, fn plant ->
      machines = Map.fetch!(machines_by_plant, plant.code)

      assert length(machines) == dataset.metadata.target_topology.machines_per_plant

      Enum.each(machines, fn machine ->
        assert machine.plant_code == plant.code
        assert MapSet.member?(work_center_codes, machine.work_center_code)
      end)
    end)
  end
end
