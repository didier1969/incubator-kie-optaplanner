# Copyright (c) Didier Stadelmann. All rights reserved.

defmodule HexaFactory.Domain.Machine do
  @moduledoc "Physical machine instance available to the manufacturing scheduler."

  use Ecto.Schema

  @primary_key {:id, :id, autogenerate: true}
  schema "hexafactory_machines" do
    field(:code, :string)
    field(:name, :string)
    field(:hourly_cost_cents, :integer)
    field(:active, :boolean, default: true)

    belongs_to(:plant, HexaFactory.Domain.Plant)
    belongs_to(:work_center, HexaFactory.Domain.WorkCenter)

    timestamps()
  end
end
