defmodule HexaPlanner.GTFS.Trip do
  use Ecto.Schema
  import Ecto.Changeset

  schema "gtfs_trips" do
    field :original_trip_id, :string
    field :route_id, :string
    field :service_id, :string
  end

  def changeset(trip, attrs) do
    trip
    |> cast(attrs, [:original_trip_id, :route_id, :service_id])
    |> validate_required([:original_trip_id, :route_id, :service_id])
  end
end
