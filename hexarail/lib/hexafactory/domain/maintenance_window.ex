# Copyright (c) Didier Stadelmann. All rights reserved.

defmodule HexaFactory.Domain.MaintenanceWindow do
  @moduledoc "Planned or reactive blackout interval applied to a plant-level scope."

  use Ecto.Schema

  @primary_key {:id, :id, autogenerate: true}
  schema "hexafactory_maintenance_windows" do
    field(:scope_type, :string)
    field(:scope_code, :string)
    field(:start_minute, :integer)
    field(:end_minute, :integer)

    belongs_to(:plant, HexaFactory.Domain.Plant)

    timestamps()
  end
end
