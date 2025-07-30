defmodule MobileAppBackend.Search.Algolia.QueryPayload do
  @moduledoc """
  The data expected by Algolia for search queries.
  """
  alias MobileAppBackend.Search.Algolia
  @type supported_index :: :stop | :route

  @type t :: %__MODULE__{
          index_name: String.t(),
          params: map()
        }

  @default_params %{"hitsPerPage" => 5, "clickAnalytics" => true}

  defstruct index_name: "",
            params: %{}

  @spec for_index(supported_index, String.t()) :: t()
  def for_index(:route, query) do
    Algolia.Index.index_name(:route)
    |> new(query)
    |> with_hit_size(5)
  end

  def for_index(:stop, query) do
    Algolia.Index.index_name(:stop)
    |> new(query)
    |> with_hit_size(10)
  end

  def for_route_filter(query) do
    Algolia.Index.index_name(:route)
    |> new(query)
    |> with_hit_size(1000)
  end

  defp new(index_name, query) do
    track_analytics? =
      Application.get_env(:mobile_app_backend, MobileAppBackend.Search.Algolia)[:track_analytics?] ||
        false

    %__MODULE__{
      index_name: index_name,
      params:
        @default_params
        |> Map.put("analytics", track_analytics?)
        |> Map.put("query", query)
    }
  end

  defp with_hit_size(query_payload, hitSize) do
    %__MODULE__{
      query_payload
      | params: Map.put(query_payload.params, "hitsPerPage", hitSize)
    }
  end
end
