defmodule HexaCore.Domain.Job do
  @moduledoc "A task to be scheduled."
  use Ecto.Schema

  @type t :: %__MODULE__{
          id: integer() | nil,
          duration: integer() | nil,
          required_resources: list(integer()) | nil,
          release_time: integer() | nil,
          due_time: integer() | nil,
          batch_key: String.t() | nil,
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
    # Generic release and due dates carried by planning projections.
    field(:release_time, :integer, virtual: true)
    field(:due_time, :integer, virtual: true)
    field(:batch_key, :string, virtual: true)
    # Planning Variables (to be filled by Rust)
    field(:start_time, :integer)
    timestamps()
  end
end
