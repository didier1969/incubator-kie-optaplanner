defmodule HexaPlanner.TranspilerTest do
  use ExUnit.Case
  alias HexaPlanner.DSL.Rule
  alias HexaPlanner.Transpiler.RustGenerator

  test "generates valid rust iterator code from rule struct" do
    rule = %Rule{
      name: "unassigned_job",
      entity: :job,
      field: :start_time,
      condition: :is_nil,
      penalty_type: :hard,
      penalty_score: 100
    }

    rust_code = RustGenerator.generate([rule])
    
    assert rust_code =~ "pub fn calculate_generated_score"
    assert rust_code =~ "for job in &problem.jobs {"
    assert rust_code =~ "if job.start_time.is_none() {"
    assert rust_code =~ "score -= 100;"
  end
end
