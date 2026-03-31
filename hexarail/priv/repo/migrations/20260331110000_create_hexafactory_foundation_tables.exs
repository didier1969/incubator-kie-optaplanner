# Copyright (c) Didier Stadelmann. All rights reserved.

defmodule HexaRail.Repo.Migrations.CreateHexafactoryFoundationTables do
  use Ecto.Migration

  def change do
    create table(:hexafactory_company_codes) do
      add(:code, :string, null: false)
      add(:name, :string, null: false)

      timestamps()
    end

    create(unique_index(:hexafactory_company_codes, [:code]))

    create table(:hexafactory_plants) do
      add(:code, :string, null: false)
      add(:name, :string, null: false)
      add(:company_code_id, references(:hexafactory_company_codes, on_delete: :restrict), null: false)

      timestamps()
    end

    create(unique_index(:hexafactory_plants, [:code]))
    create(index(:hexafactory_plants, [:company_code_id]))

    create table(:hexafactory_storage_locations) do
      add(:code, :string, null: false)
      add(:name, :string, null: false)
      add(:kind, :string, null: false)
      add(:plant_id, references(:hexafactory_plants, on_delete: :delete_all), null: false)

      timestamps()
    end

    create(unique_index(:hexafactory_storage_locations, [:plant_id, :code]))
    create(index(:hexafactory_storage_locations, [:kind]))

    create table(:hexafactory_materials) do
      add(:code, :string, null: false)
      add(:description, :string, null: false)
      add(:material_type, :string, null: false)
      add(:base_uom, :string, null: false)

      timestamps()
    end

    create(unique_index(:hexafactory_materials, [:code]))
    create(index(:hexafactory_materials, [:material_type]))

    create table(:hexafactory_work_centers) do
      add(:code, :string, null: false)
      add(:name, :string, null: false)
      add(:kind, :string, null: false)
      add(:plant_id, references(:hexafactory_plants, on_delete: :delete_all), null: false)

      timestamps()
    end

    create(unique_index(:hexafactory_work_centers, [:plant_id, :code]))
    create(index(:hexafactory_work_centers, [:kind]))

    create table(:hexafactory_machines) do
      add(:code, :string, null: false)
      add(:name, :string, null: false)
      add(:hourly_cost_cents, :integer, null: false)
      add(:active, :boolean, null: false, default: true)
      add(:plant_id, references(:hexafactory_plants, on_delete: :delete_all), null: false)
      add(:work_center_id, references(:hexafactory_work_centers, on_delete: :restrict), null: false)

      timestamps()
    end

    create(unique_index(:hexafactory_machines, [:plant_id, :code]))
    create(index(:hexafactory_machines, [:work_center_id]))

    create table(:hexafactory_skills) do
      add(:code, :string, null: false)
      add(:name, :string, null: false)

      timestamps()
    end

    create(unique_index(:hexafactory_skills, [:code]))

    create table(:hexafactory_operators) do
      add(:code, :string, null: false)
      add(:name, :string, null: false)
      add(:primary_skill_id, references(:hexafactory_skills, on_delete: :restrict), null: false)
      add(:home_plant_id, references(:hexafactory_plants, on_delete: :restrict), null: false)

      timestamps()
    end

    create(unique_index(:hexafactory_operators, [:code]))
    create(index(:hexafactory_operators, [:primary_skill_id]))
    create(index(:hexafactory_operators, [:home_plant_id]))

    create table(:hexafactory_labor_pools) do
      add(:code, :string, null: false)
      add(:name, :string, null: false)
      add(:plant_id, references(:hexafactory_plants, on_delete: :delete_all), null: false)

      timestamps()
    end

    create(unique_index(:hexafactory_labor_pools, [:plant_id, :code]))

    create table(:hexafactory_tools) do
      add(:code, :string, null: false)
      add(:name, :string, null: false)
      add(:tool_type, :string, null: false)

      timestamps()
    end

    create(unique_index(:hexafactory_tools, [:code]))
    create(index(:hexafactory_tools, [:tool_type]))

    create table(:hexafactory_tool_instances) do
      add(:code, :string, null: false)
      add(:status, :string, null: false, default: "available")
      add(:tool_id, references(:hexafactory_tools, on_delete: :delete_all), null: false)
      add(:current_plant_id, references(:hexafactory_plants, on_delete: :restrict), null: false)

      timestamps()
    end

    create(unique_index(:hexafactory_tool_instances, [:code]))
    create(index(:hexafactory_tool_instances, [:tool_id]))
    create(index(:hexafactory_tool_instances, [:current_plant_id]))

    create table(:hexafactory_transport_lanes) do
      add(:material_id, references(:hexafactory_materials, on_delete: :delete_all), null: false)
      add(:source_plant_id, references(:hexafactory_plants, on_delete: :delete_all), null: false)
      add(:target_plant_id, references(:hexafactory_plants, on_delete: :delete_all), null: false)
      add(:transit_minutes, :integer, null: false)

      timestamps()
    end

    create(unique_index(:hexafactory_transport_lanes, [:material_id, :source_plant_id, :target_plant_id]))
    create(index(:hexafactory_transport_lanes, [:source_plant_id]))
    create(index(:hexafactory_transport_lanes, [:target_plant_id]))
  end
end
