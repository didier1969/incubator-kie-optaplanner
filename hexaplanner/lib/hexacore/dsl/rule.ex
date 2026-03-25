defmodule HexaCore.DSL.Rule do
  @moduledoc "Represents a parsed business rule constraint."
  @type t :: %__MODULE__{
          name: String.t(),
          entity: atom(),
          field: atom(),
          condition: atom(),
          penalty_type: atom(),
          penalty_score: integer()
        }
  defstruct [:name, :entity, :field, :condition, :penalty_type, :penalty_score]
end
