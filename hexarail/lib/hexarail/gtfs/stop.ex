defmodule HexaRail.GTFS.Stop do
  use Ecto.Schema
  import Ecto.Changeset

  schema "gtfs_stops" do
    field(:original_stop_id, :string)
    field(:stop_name, :string)
    field(:abbreviation, :string)
    field(:location, Geo.PostGIS.Geometry)
    field(:location_type, :integer)
    field(:parent_station, :string)
    field(:platform_code, :string)
  end

  def changeset(stop, attrs) do
    stop
    |> cast(attrs, [
      :original_stop_id,
      :stop_name,
      :abbreviation,
      :location,
      :location_type,
      :parent_station,
      :platform_code
    ])
    |> validate_required([:original_stop_id, :stop_name, :location])
  end
end
