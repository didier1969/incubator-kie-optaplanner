defmodule HexaRail.GTFS.CalendarDate do
  use Ecto.Schema

  @primary_key false
  schema "gtfs_calendar_dates" do
    field :service_id, :string
    field :date, :integer
    field :exception_type, :integer
  end
end
