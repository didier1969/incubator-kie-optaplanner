defmodule HexaPlanner.GTFS.Transfer do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false
  schema "gtfs_transfers" do
    field :from_stop_id, :string
    field :to_stop_id, :string
    field :transfer_type, :integer
    field :min_transfer_time, :integer
    # Optional fields for guaranteed connections
    field :from_trip_id, :string
    field :to_trip_id, :string
  end

  def changeset(transfer, attrs) do
    transfer
    |> cast(attrs, [:from_stop_id, :to_stop_id, :transfer_type, :min_transfer_time, :from_trip_id, :to_trip_id])
    |> validate_required([:from_stop_id, :to_stop_id, :transfer_type])
  end
end
