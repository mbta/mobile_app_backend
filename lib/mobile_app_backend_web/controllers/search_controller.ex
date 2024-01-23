defmodule MobileAppBackendWeb.SearchController do
  @moduledoc false
  use MobileAppBackendWeb, :controller
  alias MobileAppBackend.Search.Algolia

  alias Plug.Conn

  @spec query(Conn.t(), map) :: Conn.t()
  def query(%Conn{} = conn, %{"query" => ""}) do
    json(conn, %{data: []})
  end

  def query(%Conn{} = conn, %{"query" => query}) do
    queries = [
      Algolia.QueryPayload.for_index(:route, query),
      Algolia.QueryPayload.for_index(:stop, query)
    ]

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
