defmodule HexaRail.Repo.Migrations.AddWaitingToleranceToTransfers do
  use Ecto.Migration

  def change do
    alter table(:gtfs_transfers) do
      add :waiting_tolerance_seconds, :integer, default: 0
    end
  end
end
