defmodule HexaCore.Domain.SolverConfig do
  defstruct lahc_history_size: 100, swap_move_prob: 20, shift_move_prob: 40, shift_window: 120
  @type t :: %__MODULE__{}
end
