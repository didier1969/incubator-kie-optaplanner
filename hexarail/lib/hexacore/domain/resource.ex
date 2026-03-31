defmodule HexaCore.Domain.Resource do
  @moduledoc "A physical asset in the factory/network."
  use Ecto.Schema

  @type t :: %__MODULE__{
          id: integer() | nil,
          name: String.t() | nil,
          capacity: integer() | nil,
          availability_windows: list(HexaCore.Domain.Window.t()) | nil,
          inserted_at: NaiveDateTime.t() | nil,
          updated_at: NaiveDateTime.t() | nil
        }

  @primary_key {:id, :id, autogenerate: true}
  schema "resources" do
    field(:name, :string)
    field(:capacity, :integer, default: 1)
    field(:availability_windows, {:array, :map}, virtual: true, default: [])
    # future: location/topology links
    timestamps()
  end
end
