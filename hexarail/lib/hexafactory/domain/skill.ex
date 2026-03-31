# Copyright (c) Didier Stadelmann. All rights reserved.

defmodule HexaFactory.Domain.Skill do
  @moduledoc "Reusable labor skill referenced by operators and future setup constraints."

  use Ecto.Schema

  @primary_key {:id, :id, autogenerate: true}
  schema "hexafactory_skills" do
    field(:code, :string)
    field(:name, :string)

    timestamps()
  end
end
