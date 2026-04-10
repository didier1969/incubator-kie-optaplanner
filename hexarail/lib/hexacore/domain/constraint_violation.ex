# Copyright (c) Didier Stadelmann. All rights reserved.

defmodule HexaCore.Domain.ConstraintViolation do
  @moduledoc """
  Detailed constraint violation metadata for XAI.
  """

  @enforce_keys [:name, :severity, :message]
  defstruct [:name, :severity, :message, :job_id, :resource_id]

  @type t :: %__MODULE__{
          name: String.t(),
          severity: String.t(),
          message: String.t(),
          job_id: integer() | nil,
          resource_id: integer() | nil
        }
end
