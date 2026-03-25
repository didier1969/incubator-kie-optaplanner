defmodule HexaCore.Domain.Problem do
  @moduledoc "The root aggregate holding the entire Twin state."
  defstruct [:id, resources: [], jobs: []]

  @type t :: %__MODULE__{
          id: String.t() | nil,
          resources: list(HexaCore.Domain.Resource.t()),
          jobs: list(HexaCore.Domain.Job.t())
        }
end
