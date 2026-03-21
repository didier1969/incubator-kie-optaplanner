defmodule HexaPlanner.GTFS.Trip do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:trip_id, :string, autogenerate: false}
  schema "gtfs_trips" do
    field :route_id, :string
    field :service_id, :string
    
    # We omit direction_id, block_id, shape_id for MVP unless strictly needed for topology
  end

  def changeset(trip, attrs) do
    trip
    |> cast(attrs, [:trip_id, :route_id, :service_id])
    |> validate_required([:trip_id, :route_id, :service_id])
  end
end
