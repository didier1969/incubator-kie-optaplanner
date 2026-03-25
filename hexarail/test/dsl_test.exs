defmodule HexaCore.DSLTest do
  use ExUnit.Case

  defmodule MyRules do
    use HexaCore.DSL

    defconstraint "unassigned_job" do
      match(:job, :start_time, :is_nil)
      penalize(:hard, 100)
    end
  end

  test "DSL parses constraints into AST structs" do
    rules = MyRules.__rules__()
    assert length(rules) == 1
    rule = hd(rules)

    assert rule.name == "unassigned_job"
    assert rule.entity == :job
    assert rule.field == :start_time
    assert rule.condition == :is_nil
    assert rule.penalty_type == :hard
    assert rule.penalty_score == 100
  end
end
