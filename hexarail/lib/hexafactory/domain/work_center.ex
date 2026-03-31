# Copyright (c) Didier Stadelmann. All rights reserved.

defmodule HexaFactory.Domain.WorkCenter do
  @moduledoc "Logical capacity center grouping one or more machines."

  use Ecto.Schema

  @primary_key {:id, :id, autogenerate: true}
  schema "hexafactory_work_centers" do
    field(:code, :string)
    field(:name, :string)
    field(:kind, :string)

    belongs_to(:plant, HexaFactory.Domain.Plant)
    has_many(:machines, HexaFactory.Domain.Machine)

    timestamps()
  end
end
