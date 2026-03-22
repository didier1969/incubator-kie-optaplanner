defmodule HexaPlanner.Repo.Migrations.CreateGtfsCalendarTables do
  use Ecto.Migration

  def change do
    create table(:gtfs_calendars, primary_key: false) do
      add :service_id, :string, primary_key: true
      add :monday, :integer, null: false
      add :tuesday, :integer, null: false
      add :wednesday, :integer, null: false
      add :thursday, :integer, null: false
      add :friday, :integer, null: false
      add :saturday, :integer, null: false
      add :sunday, :integer, null: false
      add :start_date, :integer, null: false
      add :end_date, :integer, null: false
    end

    create table(:gtfs_calendar_dates, primary_key: false) do
      add :service_id, references(:gtfs_calendars, column: :service_id, type: :string, on_delete: :delete_all), null: false
      add :date, :integer, null: false
      add :exception_type, :integer, null: false
    end

    create index(:gtfs_calendar_dates, [:service_id, :date])
    create index(:gtfs_calendar_dates, [:date])
  end
end
