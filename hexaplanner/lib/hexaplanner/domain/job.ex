defmodule HexaPlanner.Domain.Job do
  @moduledoc "A task to be scheduled."
  use Ecto.Schema

  @type t :: %__MODULE__{
          id: integer() | nil,
          duration: integer() | nil,
          required_resources: list(integer()) | nil,
          start_time: integer() | nil,
          inserted_at: NaiveDateTime.t() | nil,
          updated_at: NaiveDateTime.t() | nil
        }

  @primary_key {:id, :id, autogenerate: true}
  schema "jobs" do
    # in minutes/ticks
    field(:duration, :integer)
    # IDs of needed resources
    field(:required_resources, {:array, :integer})
    # Planning Variables (to be filled by Rust)
    field(:start_time, :integer)
    timestamps()
  end
end
