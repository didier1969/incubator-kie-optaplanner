defmodule HexaPlanner.GTFS.Stop do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:stop_id, :string, autogenerate: false}
  schema "gtfs_stops" do
    field :stop_name, :string
    field :location, Geo.PostGIS.Geometry
  end

  def changeset(stop, attrs) do
    stop
    |> cast(attrs, [:stop_id, :stop_name, :location])
    |> validate_required([:stop_id, :stop_name, :location])
  end
end
