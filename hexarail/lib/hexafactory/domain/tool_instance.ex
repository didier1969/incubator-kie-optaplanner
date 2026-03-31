# Copyright (c) Didier Stadelmann. All rights reserved.

defmodule HexaFactory.Domain.ToolInstance do
  @moduledoc "Concrete finite tool instance that can move between plants."

  use Ecto.Schema

  @primary_key {:id, :id, autogenerate: true}
  schema "hexafactory_tool_instances" do
    field(:code, :string)
    field(:status, :string, default: "available")

    belongs_to(:tool, HexaFactory.Domain.Tool)
    belongs_to(:current_plant, HexaFactory.Domain.Plant)

    timestamps()
  end
end
