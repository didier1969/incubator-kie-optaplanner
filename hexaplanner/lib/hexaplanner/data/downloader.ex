defmodule HexaPlanner.Data.Downloader do
  @moduledoc """
  Handles fetching large datasets from Open Data portals.
  """

  @doc """
  Fetches GeoJSON from a given URL.
  Pass `limit: N` in options to restrict the number of features (useful for testing).
  """
  def fetch_geojson(url, opts \\ []) do
    req_url =
      case Keyword.get(opts, :limit) do
        nil -> url
        limit -> "#{url}?limit=#{limit}"
      end

    case Req.get(req_url) do
      {:ok, %Req.Response{status: 200, body: body}} ->
        {:ok, body}

      {:ok, %Req.Response{status: status}} ->
        {:error, "HTTP Request failed with status #{status}"}

      {:error, reason} ->
        {:error, reason}
    end
  end
end
