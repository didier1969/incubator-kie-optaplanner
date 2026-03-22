defmodule HexaPlanner.GTFS.Calendar do
  use Ecto.Schema

  @primary_key {:service_id, :string, []}
  schema "gtfs_calendars" do
    field :monday, :integer
    field :tuesday, :integer
    field :wednesday, :integer
    field :thursday, :integer
    field :friday, :integer
    field :saturday, :integer
    field :sunday, :integer
    field :start_date, :integer
    field :end_date, :integer
  end
end
