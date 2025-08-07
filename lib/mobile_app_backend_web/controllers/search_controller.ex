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

  def routes(%Conn{} = conn, params = %{"query" => query}) do
    algolia_request(conn, [
      Algolia.QueryPayload.for_route_filter(
        query,
        %{
          "route.type" => Map.get(params, "type"),
          "route.line_id" => Map.get(params, "line_id")
        }
        |> Map.reject(fn {_, v} -> v == nil end)
      )
    ])
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
