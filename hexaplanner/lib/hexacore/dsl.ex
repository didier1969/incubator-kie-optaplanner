defmodule HexaCore.DSL do
  @moduledoc "Macros for defining Digital Twin constraints."
  alias HexaCore.DSL.Rule

  defmacro __using__(_opts) do
    quote do
      import HexaCore.DSL
      Module.register_attribute(__MODULE__, :rules, accumulate: true)
      @before_compile HexaCore.DSL
    end
  end

  defmacro __before_compile__(env) do
    rules = Module.get_attribute(env.module, :rules) |> Enum.reverse()

    quote do
      def __rules__, do: unquote(Macro.escape(rules))
    end
  end

  defmacro defconstraint(name, do: block) do
    # Extremely simplified parser for the MVP
    {:__block__, _, [match_ast, penalize_ast]} = block
    {:match, _, [entity, field, condition]} = match_ast
    {:penalize, _, [type, score]} = penalize_ast

    quote do
      @rules %Rule{
        name: unquote(name),
        entity: unquote(entity),
        field: unquote(field),
        condition: unquote(condition),
        penalty_type: unquote(type),
        penalty_score: unquote(score)
      }
    end
  end
end
