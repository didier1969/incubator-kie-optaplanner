defmodule HexaPlanner.Repo.Migrations.AddRouteTransfersFields do
  use Ecto.Migration

  def change do
    alter table(:gtfs_transfers) do
      add :from_route_id, references(:gtfs_routes, column: :id, type: :bigint, on_delete: :nilify_all)
      add :to_route_id, references(:gtfs_routes, column: :id, type: :bigint, on_delete: :nilify_all)
    end
  end
end
