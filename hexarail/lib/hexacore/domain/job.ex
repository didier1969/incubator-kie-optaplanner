# Copyright (c) Didier Stadelmann. All rights reserved.

defmodule HexaCore.Domain.Job do
  @moduledoc "A generic scheduling task carried as a plain data contract."

  @enforce_keys []
  defstruct [
    :id,
    :duration,
    :release_time,
    :due_time,
    :group_id,
    :start_time,
    required_resources: []
  ]

  @type t :: %__MODULE__{
          id: integer() | nil,
          duration: integer() | nil,
          required_resources: list(integer()),
          release_time: integer() | nil,
          due_time: integer() | nil,
          group_id: String.t() | nil,
          start_time: integer() | nil
        }
end
