defmodule HexaPlanner.GTFS.Transfer do
  use Ecto.Schema

  @primary_key false
  schema "gtfs_transfers" do
    field :from_stop_id, :integer
    field :to_stop_id, :integer
    field :transfer_type, :integer
    field :min_transfer_time, :integer
    field :from_trip_id, :integer
    field :to_trip_id, :integer
    field :from_route_id, :integer
    field :to_route_id, :integer
  end
end
