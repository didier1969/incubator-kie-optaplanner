defmodule HexaPlanner.GTFS.StopTime do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false
  schema "gtfs_stop_times" do
    field(:trip_id, :integer)
    # Seconds from midnight
    field(:arrival_time, :integer)
    # Seconds from midnight
    field(:departure_time, :integer)
    field(:stop_id, :integer)
    field(:stop_sequence, :integer)
    field(:pickup_type, :integer)
    field(:drop_off_type, :integer)
  end

  def changeset(stop_time, attrs) do
    stop_time
    |> cast(attrs, [
      :trip_id,
      :arrival_time,
      :departure_time,
      :stop_id,
      :stop_sequence,
      :pickup_type,
      :drop_off_type
    ])
    |> validate_required([:trip_id, :arrival_time, :stop_id, :stop_sequence])
  end
end
