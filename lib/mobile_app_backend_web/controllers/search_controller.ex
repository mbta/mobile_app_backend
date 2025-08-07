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
        Map.new(["type", "line_id"], fn facet ->
          {"route.#{facet}", parse_facet_param(params, facet)}
        end)
        |> Map.reject(fn {_, v} -> is_nil(v) end)
      )
    ])
  end

  defp param_split_or_nil(params, key) do
    case Map.get(params, key) do
      nil -> nil
      value -> String.split(value, ",")
    end
  end

  # Converts lists of route types like ["bus", "heavy_rail"] into GTFS IDs like ["3", "1"]
  defp parse_facet_param(params, "type" = key) do
    case param_split_or_nil(params, key) do
      nil ->
        nil

      types ->
        Enum.map(types, fn type ->
          String.to_existing_atom(type)
          |> MBTAV3API.Route.serialize_type!()
          |> Integer.to_string()
        end)
    end
  catch
    _, _ -> nil
  end

  defp parse_facet_param(params, key), do: param_split_or_nil(params, key)

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
