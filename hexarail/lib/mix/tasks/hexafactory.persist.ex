# Copyright (c) Didier Stadelmann. All rights reserved.

defmodule Mix.Tasks.Hexafactory.Persist do
  @shortdoc "Builds and persists a deterministic HexaFactory planning horizon"

  use Mix.Task

  alias HexaFactory.CLI

  @impl Mix.Task
  def run(args) do
    Mix.Task.run("app.start")

    args
    |> CLI.parse_common_opts(profile: "smoke", seed: 42)
    |> CLI.persist_dataset()
    |> CLI.print_persist_summary("persist")
  end
end
