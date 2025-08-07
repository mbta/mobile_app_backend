defmodule MobileAppBackendWeb.SearchController do
  @moduledoc false
  use MobileAppBackendWeb, :controller
  alias MobileAppBackend.Search.Algolia

  alias Plug.Conn

  @spec query(Conn.t(), map) :: Conn.t()
  def query(%Conn{} = conn, %{"query" => ""}) do
    json(conn, %{data: %{}})
  end

  def query(%Conn{} = conn, %{"query" => query}) do
    algolia_request(conn, [
      Algolia.QueryPayload.for_index(:route, query),
      Algolia.QueryPayload.for_index(:stop, query)
    ])
  end

  @spec routes(Conn.t(), map) :: Conn.t()
  def routes(%Conn{} = conn, %{"query" => ""}) do
    json(conn, %{data: %{}})
  end

  def routes(%Conn{} = conn, %{"query" => query} = params) do
    algolia_request(conn, [
      Algolia.QueryPayload.for_route_filter(
        query,
        %{
          "route.type" => parse_type_param(Map.get(params, "type")),
          "route.line_id" => Map.get(params, "line_id")
        }
        |> Map.reject(fn {_, v} -> v == nil end)
      )
    ])
  end

  @spec parse_type_param(String.t() | nil) :: String.t() | nil
  defp parse_type_param(nil), do: nil

  # Accept comma separated lists of types like "bus" or "heavy_rail",
  # then convert to GTFS route type IDs, and join back to a comma separated string
  defp parse_type_param(type_string) do
    String.split(type_string, ",")
    |> Enum.map_join(",", fn type ->
      String.to_existing_atom(type)
      |> MBTAV3API.Route.serialize_type!()
      |> Integer.to_string()
    end)
  catch
    _, _ -> nil
  end

  @spec routes(Conn.t(), [Algolia.QueryPayload.t()]) :: Conn.t()
  defp algolia_request(conn, queries) do
    algolia_query_fn =
      Application.get_env(
        :mobile_app_backend,
        :algolia_multi_index_search_fn,
        &Algolia.Api.multi_index_search/1
      )

    case algolia_query_fn.(queries) do
      {:ok, response} ->
        json(conn, %{data: response})

      {:error, _error} ->
        conn
        |> put_status(:internal_server_error)
        |> json(%{error: "search_failed"})
    end
  end
end
