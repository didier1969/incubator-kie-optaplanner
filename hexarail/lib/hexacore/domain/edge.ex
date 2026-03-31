# Copyright (c) Didier Stadelmann. All rights reserved.

defmodule HexaCore.Domain.Edge do
  @moduledoc "A generic precedence relation between two jobs."

  @enforce_keys [:from_job_id, :to_job_id, :lag, :edge_type]
  defstruct [:from_job_id, :to_job_id, :lag, :edge_type]

  @type edge_type :: String.t()

  @type t :: %__MODULE__{
          from_job_id: integer(),
          to_job_id: integer(),
          lag: integer(),
          edge_type: edge_type()
        }
end
