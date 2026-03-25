Postgrex.Types.define(
  HexaRail.PostgresTypes,
  [Geo.PostGIS.Extension] ++ Ecto.Adapters.Postgres.extensions(),
  []
)

defmodule HexaRail.Repo do
  @moduledoc "Main Ecto Repo for HexaRail"
  use Ecto.Repo,
    otp_app: :hexarail,
    adapter: Ecto.Adapters.Postgres
end
