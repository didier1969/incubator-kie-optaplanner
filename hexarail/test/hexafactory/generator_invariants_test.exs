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
end
