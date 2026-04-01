# Copyright (c) Didier Stadelmann. All rights reserved.

defmodule HexaRail.Repo.Migrations.CreateHexafactoryPlanningTables do
  use Ecto.Migration

  def change do
    create table(:hexafactory_bom_items) do
      add(:parent_material_id, references(:hexafactory_materials, on_delete: :delete_all), null: false)
      add(:component_material_id, references(:hexafactory_materials, on_delete: :delete_all), null: false)
      add(:quantity_per_parent, :decimal, null: false)
      add(:scrap_rate, :decimal, null: false, default: 0)

      timestamps()
    end

    create(index(:hexafactory_bom_items, [:parent_material_id]))
    create(index(:hexafactory_bom_items, [:component_material_id]))

    create table(:hexafactory_routings) do
      add(:code, :string, null: false)
      add(:alternative_kind, :string, null: false)
      add(:plant_id, references(:hexafactory_plants, on_delete: :delete_all), null: false)
      add(:material_id, references(:hexafactory_materials, on_delete: :delete_all), null: false)

      timestamps()
    end

    create(unique_index(:hexafactory_routings, [:plant_id, :code]))
    create(index(:hexafactory_routings, [:material_id]))

    create table(:hexafactory_routing_operations) do
      add(:routing_id, references(:hexafactory_routings, on_delete: :delete_all), null: false)
      add(:sequence, :integer, null: false)
      add(:operation_kind, :string, null: false)
      add(:batchable, :boolean, null: false, default: false)
      add(:transfer_batch_size, :integer)

      timestamps()
    end

    create(unique_index(:hexafactory_routing_operations, [:routing_id, :sequence]))
    create(index(:hexafactory_routing_operations, [:operation_kind]))

    create table(:hexafactory_production_orders) do
      add(:order_code, :string, null: false)
      add(:quantity, :integer, null: false)
      add(:priority, :integer, null: false, default: 1)
      add(:plant_id, references(:hexafactory_plants, on_delete: :delete_all), null: false)
      add(:material_id, references(:hexafactory_materials, on_delete: :delete_all), null: false)

      timestamps()
    end

    create(unique_index(:hexafactory_production_orders, [:order_code]))
    create(index(:hexafactory_production_orders, [:plant_id]))
    create(index(:hexafactory_production_orders, [:material_id]))

    create table(:hexafactory_setup_profiles) do
      add(:code, :string, null: false)
      add(:description, :string, null: false)

      timestamps()
    end

    create(unique_index(:hexafactory_setup_profiles, [:code]))

    create table(:hexafactory_setup_transitions) do
      add(:from_profile_id, references(:hexafactory_setup_profiles, on_delete: :delete_all), null: false)
      add(:to_profile_id, references(:hexafactory_setup_profiles, on_delete: :delete_all), null: false)
      add(:duration_minutes, :integer, null: false)

      timestamps()
    end

    create(unique_index(:hexafactory_setup_transitions, [:from_profile_id, :to_profile_id]))

    create table(:hexafactory_maintenance_windows) do
      add(:plant_id, references(:hexafactory_plants, on_delete: :delete_all), null: false)
      add(:scope_type, :string, null: false)
      add(:scope_code, :string, null: false)
      add(:start_minute, :integer, null: false)
      add(:end_minute, :integer, null: false)

      timestamps()
    end

    create(index(:hexafactory_maintenance_windows, [:plant_id]))
    create(index(:hexafactory_maintenance_windows, [:scope_type, :scope_code]))

    create table(:hexafactory_buffers) do
      add(:code, :string, null: false)
      add(:capacity_units, :integer, null: false)
      add(:material_type, :string, null: false)
      add(:plant_id, references(:hexafactory_plants, on_delete: :delete_all), null: false)

      timestamps()
    end

    create(unique_index(:hexafactory_buffers, [:plant_id, :code]))
    create(index(:hexafactory_buffers, [:material_type]))

    create table(:hexafactory_batch_policies) do
      add(:code, :string, null: false)
      add(:operation_kind, :string, null: false)
      add(:min_batch_size, :integer, null: false)
      add(:max_batch_size, :integer, null: false)
      add(:mix_key, :string, null: false)

      timestamps()
    end

    create(unique_index(:hexafactory_batch_policies, [:code]))
    create(index(:hexafactory_batch_policies, [:operation_kind]))
  end
end
