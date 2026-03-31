# Copyright (c) Didier Stadelmann. All rights reserved.

defmodule HexaFactory.Domain.CompanyCode do
  @moduledoc "Enterprise company code grouping one or more manufacturing plants."

  use Ecto.Schema

  @primary_key {:id, :id, autogenerate: true}
  schema "hexafactory_company_codes" do
    field(:code, :string)
    field(:name, :string)

    has_many(:plants, HexaFactory.Domain.Plant)

    timestamps()
  end
end
