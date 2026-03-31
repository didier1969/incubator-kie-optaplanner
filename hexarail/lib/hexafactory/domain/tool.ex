# Copyright (c) Didier Stadelmann. All rights reserved.

defmodule HexaFactory.Domain.Tool do
  @moduledoc "Finite tooling or fixture family required by manufacturing operations."

  use Ecto.Schema

  @primary_key {:id, :id, autogenerate: true}
  schema "hexafactory_tools" do
    field(:code, :string)
    field(:name, :string)
    field(:tool_type, :string)

    timestamps()
  end
end
