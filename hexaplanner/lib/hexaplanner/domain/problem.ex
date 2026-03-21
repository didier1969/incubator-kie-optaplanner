defmodule HexaPlanner.Domain.Problem do
  @moduledoc "The root aggregate holding the entire Twin state."
  defstruct [:id, resources: [], jobs: []]

  @type t :: %__MODULE__{
          id: String.t() | nil,
          resources: list(HexaPlanner.Domain.Resource.t()),
          jobs: list(HexaPlanner.Domain.Job.t())
        }
end
