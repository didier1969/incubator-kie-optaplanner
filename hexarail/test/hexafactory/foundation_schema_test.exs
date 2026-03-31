# Copyright (c) Didier Stadelmann. All rights reserved.

defmodule HexaFactory.FoundationSchemaTest do
  use HexaRail.DataCase, async: true

  alias HexaFactory.Domain.{
    CompanyCode,
    LaborPool,
    Machine,
    Material,
    Operator,
    Plant,
    Skill,
    StorageLocation,
    Tool,
    ToolInstance,
    TransportLane,
    WorkCenter
  }

  test "foundation schemas persist the multi-plant manufacturing topology" do
    company_code = Repo.insert!(%CompanyCode{code: "CC-01", name: "Core Manufacturing"})

    source_plant =
      Repo.insert!(%Plant{
        code: "PLANT-001",
        name: "Plant 001",
        company_code_id: company_code.id
      })

    target_plant =
      Repo.insert!(%Plant{
        code: "PLANT-002",
        name: "Plant 002",
        company_code_id: company_code.id
      })

    storage_location =
      Repo.insert!(%StorageLocation{
        code: "HALB-01",
        name: "Semi Finished Buffer",
        kind: "halb",
        plant_id: source_plant.id
      })

    material =
      Repo.insert!(%Material{
        code: "MAT-100",
        description: "Gear blank",
        material_type: "HALB",
        base_uom: "EA"
      })

    work_center =
      Repo.insert!(%WorkCenter{
        code: "WC-100",
        name: "Decolletage Cell",
        kind: "decolletage",
        plant_id: source_plant.id
      })

    machine =
      Repo.insert!(%Machine{
        code: "M-100",
        name: "Tornos Alpha",
        plant_id: source_plant.id,
        work_center_id: work_center.id,
        hourly_cost_cents: 12_000
      })

    skill = Repo.insert!(%Skill{code: "SETTER-L3", name: "Level 3 Setter"})

    operator =
      Repo.insert!(%Operator{
        code: "OP-001",
        name: "Ariane",
        primary_skill_id: skill.id,
        home_plant_id: source_plant.id
      })

    labor_pool =
      Repo.insert!(%LaborPool{
        code: "POOL-SETUP",
        name: "Setup Specialists",
        plant_id: source_plant.id
      })

    tool = Repo.insert!(%Tool{code: "TOOL-HOB-01", name: "Hob Cutter", tool_type: "hob"})

    tool_instance =
      Repo.insert!(%ToolInstance{
        code: "TOOL-HOB-01-A",
        tool_id: tool.id,
        current_plant_id: source_plant.id
      })

    lane =
      Repo.insert!(%TransportLane{
        material_id: material.id,
        source_plant_id: source_plant.id,
        target_plant_id: target_plant.id,
        transit_minutes: 180
      })

    assert company_code.code == "CC-01"
    assert storage_location.plant_id == source_plant.id
    assert machine.work_center_id == work_center.id
    assert operator.primary_skill_id == skill.id
    assert labor_pool.plant_id == source_plant.id
    assert tool_instance.tool_id == tool.id
    assert lane.transit_minutes == 180
  end
end
