defmodule HexaRail.GTFS.Trip do
  use Ecto.Schema
  import Ecto.Changeset

  schema "gtfs_trips" do
    field(:original_trip_id, :string)
    field(:route_id, :string)
    field(:service_id, :string)
    field(:trip_headsign, :string)
    field(:trip_short_name, :string)
    field(:direction_id, :integer)
    field(:block_id, :string)
    field(:hints, :string)
  end

  def changeset(trip, attrs) do
    trip
    |> cast(attrs, [
      :original_trip_id,
      :route_id,
      :service_id,
      :trip_headsign,
      :trip_short_name,
      :direction_id,
      :block_id,
      :hints
    ])
    |> validate_required([:original_trip_id, :route_id, :service_id])
  end
end
