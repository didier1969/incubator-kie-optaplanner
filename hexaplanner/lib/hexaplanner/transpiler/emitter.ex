defmodule HexaPlanner.Transpiler.Emitter do
  @moduledoc "Writes the generated Rust code to the native file system."
  alias HexaPlanner.Transpiler.RustGenerator

  @target_path "native/hexa_solver/src/generated_score.rs"

  @spec emit(list(HexaPlanner.DSL.Rule.t())) :: :ok
  def emit(rules) do
    rust_code = RustGenerator.generate(rules)
    File.write!(@target_path, rust_code)
    :ok
  end
end
