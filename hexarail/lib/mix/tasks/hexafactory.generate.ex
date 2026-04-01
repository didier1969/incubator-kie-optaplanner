# Copyright (c) Didier Stadelmann. All rights reserved.

defmodule Mix.Tasks.Hexafactory.Generate do
  @shortdoc "Builds a deterministic HexaFactory dataset and prints its summary"

  use Mix.Task

  alias HexaFactory.CLI

  @impl Mix.Task
  def run(args) do
    opts = CLI.parse_common_opts(args, profile: "smoke", seed: 42)

    opts
    |> CLI.build_dataset()
    |> CLI.print_dataset_summary("generate")
  end
end
