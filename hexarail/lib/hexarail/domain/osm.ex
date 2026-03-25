defmodule HexaRail.Domain.OsmNode do
  defstruct [:id, :lat, :lon, tags: %{}]
end

defmodule HexaRail.Domain.OsmWay do
  defstruct [:id, nodes: [], tags: %{}]
end
