# Copyright (c) Didier Stadelmann. All rights reserved.

defmodule HexaFactory.Domain.Plant do
  @moduledoc "Manufacturing site within the HexaFactory network."

  use Ecto.Schema

  @primary_key {:id, :id, autogenerate: true}
  schema "hexafactory_plants" do
    field(:code, :string)
    field(:name, :string)

    belongs_to(:company_code, HexaFactory.Domain.CompanyCode)
    has_many(:storage_locations, HexaFactory.Domain.StorageLocation)
    has_many(:work_centers, HexaFactory.Domain.WorkCenter)
    has_many(:machines, HexaFactory.Domain.Machine)

    timestamps()
  end
end
