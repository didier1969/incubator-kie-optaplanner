defmodule HexaPlanner.GTFS.Stop do
  use Ecto.Schema
  import Ecto.Changeset

  schema "gtfs_stops" do
    field :original_stop_id, :string
    field :stop_name, :string
    field :location, Geo.PostGIS.Geometry
  end

  def changeset(stop, attrs) do
    stop
    |> cast(attrs, [:original_stop_id, :stop_name, :location])
    |> validate_required([:original_stop_id, :stop_name, :location])
  end
end
