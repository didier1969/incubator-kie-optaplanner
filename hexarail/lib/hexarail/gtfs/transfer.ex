defmodule HexaRail.GTFS.Transfer do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false
  schema "gtfs_transfers" do
    field :from_stop_id, :integer
    field :to_stop_id, :integer
    field :transfer_type, :integer
    field :min_transfer_time, :integer
    field :waiting_tolerance_seconds, :integer
    field :from_trip_id, :integer
    field :to_trip_id, :integer
    field :from_route_id, :integer
    field :to_route_id, :integer
  end

  def changeset(transfer, attrs) do
    transfer
    |> cast(attrs, [:from_stop_id, :to_stop_id, :transfer_type, :min_transfer_time, :waiting_tolerance_seconds, :from_trip_id, :to_trip_id, :from_route_id, :to_route_id])
    |> validate_required([:from_stop_id, :to_stop_id, :transfer_type])
  end
end
