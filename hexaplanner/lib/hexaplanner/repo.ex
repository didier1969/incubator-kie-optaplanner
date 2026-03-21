defmodule HexaPlanner.Repo do
  @moduledoc "Main Ecto Repo for HexaPlanner"
  use Ecto.Repo,
    otp_app: :hexaplanner,
    adapter: Ecto.Adapters.Postgres
end
