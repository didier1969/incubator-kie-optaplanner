# Copyright (c) Didier Stadelmann. All rights reserved.

defmodule HexaFactory.PlanningSchemaTest do
  use HexaRail.DataCase, async: true

  alias HexaFactory.Domain.{
    BatchPolicy,
    BomItem,
    Buffer,
    CompanyCode,
    MaintenanceWindow,
    Material,
    Plant,
    ProductionOrder,
    Routing,
    RoutingOperation,
    SetupProfile,
    SetupTransition
  }

  test "planning schemas represent bom, routing, setup, batching, maintenance, and buffers" do
    company_code = Repo.insert!(%CompanyCode{code: "CC-PLAN", name: "Planning Co"})
    plant = Repo.insert!(%Plant{code: "PLANT-PLAN", name: "Planning Plant", company_code_id: company_code.id})

    parent_material =
      Repo.insert!(%Material{
        code: "T1-100",
        description: "Finished assembly",
        material_type: "FERT",
        base_uom: "EA"
      })

    component_material =
      Repo.insert!(%Material{
        code: "HALB-100",
        description: "Intermediate gear",
        material_type: "HALB",
        base_uom: "EA"
      })

    bom_item =
      Repo.insert!(%BomItem{
        parent_material_id: parent_material.id,
        component_material_id: component_material.id,
        quantity_per_parent: Decimal.new("2.50"),
        scrap_rate: Decimal.new("0.08")
      })

    routing =
      Repo.insert!(%Routing{
        code: "ROUT-100",
        plant_id: plant.id,
        material_id: parent_material.id,
        alternative_kind: "cross_plant"
      })

    operation =
      Repo.insert!(%RoutingOperation{
        routing_id: routing.id,
        sequence: 10,
        operation_kind: "heat_treatment",
        batchable: true,
        transfer_batch_size: 250
      })

    order =
      Repo.insert!(%ProductionOrder{
        order_code: "PO-100",
        plant_id: plant.id,
        material_id: parent_material.id,
        quantity: 1000,
        priority: 1
      })

    setup_profile = Repo.insert!(%SetupProfile{code: "THERM-HOT", description: "Hot thermal profile"})

    transition =
      Repo.insert!(%SetupTransition{
        from_profile_id: setup_profile.id,
        to_profile_id: setup_profile.id,
        duration_minutes: 45
      })

    maintenance =
      Repo.insert!(%MaintenanceWindow{
        plant_id: plant.id,
        scope_type: "machine_group",
        scope_code: "HEAT",
        start_minute: 480,
        end_minute: 720
      })

    buffer =
      Repo.insert!(%Buffer{
        code: "BUF-T0",
        plant_id: plant.id,
        capacity_units: 1000,
        material_type: "HALB"
      })

    batch_policy =
      Repo.insert!(%BatchPolicy{
        code: "BATCH-THERM",
        operation_kind: "heat_treatment",
        min_batch_size: 100,
        max_batch_size: 400,
        mix_key: "thermal_profile"
      })

    assert bom_item.quantity_per_parent == Decimal.new("2.50")
    assert routing.alternative_kind == "cross_plant"
    assert operation.batchable
    assert order.quantity == 1000
    assert transition.duration_minutes == 45
    assert maintenance.end_minute == 720
    assert buffer.capacity_units == 1000
    assert batch_policy.max_batch_size == 400
  end
end
