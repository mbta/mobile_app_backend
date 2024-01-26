defmodule MobileAppBackend.Search.Algolia.Api do
  @moduledoc """
  Client for the Algolia API.
  See https://www.algolia.com/doc/rest-api/search/
  Relies on configuration from :mobile_app_backend, MobileAppBackend.Search.Algolia
  """
  @algolia_api_version 1
  alias MobileAppBackend.Search.Algolia
  require Logger

  @spec multi_index_search([Algolia.QueryPayload.t()]) ::
          {:ok, [any()]} | {:error, any}
  @doc """
  Perform the given index queries and return a flattened list of parsed results
  """
  def multi_index_search(queries) do
    perform_request_fn =
      Application.get_env(
        :mobile_app_backend,
        :algolia_perform_request_fn,
        &make_request/3
      )

    body = multi_query_encoded_payload(queries)

    with {:ok, url} <- multi_index_url(),
         {:ok, headers} <- headers(),
         {:ok, response} <- perform_request_fn.(url, body, headers) do
      parse_results(response.body)
    else
      error ->
        Logger.error("#{__MODULE__} search_failed. reason=#{inspect(error)}")
        {:error, :search_failed}
    end
  end

  defp make_request(url, body, headers) do
    Req.post(url, body: body, headers: headers)
  end

  defp parse_results(%{"results" => results_per_index}) do
    {:ok,
     for index_results <- results_per_index,
         Algolia.Index.valid_index_name?(index_results["index"]),
         into: %{} do
       hits = index_results["hits"]
       index = index_results["index"]

       cond do
         index === Algolia.Index.index_name(:route) ->
           {:routes, Enum.map(hits, &Algolia.RouteResult.parse(&1))}

         index === Algolia.Index.index_name(:stop) ->
           {:stops, Enum.map(hits, &Algolia.StopResult.parse(&1))}
       end
     end}
  end

  defp parse_results(_bad_format) do
    {:error, :malformed_results}
  end

  defp multi_query_encoded_payload(queries) do
    encoded_query_payloads = Enum.map(queries, &encode_query_payload/1)

    Jason.encode!(%{
      "requests" => encoded_query_payloads
    })
  end

  defp encode_query_payload(query) do
    %{
      "indexName" => query.index_name,
      "params" => URI.encode_query(query.params)
    }
  end

  defp multi_index_url do
    case Application.get_env(:mobile_app_backend, MobileAppBackend.Search.Algolia)[:base_url] do
      nil -> {:error, :base_url_not_configured}
      base_url -> {:ok, Path.join(base_url, "#{@algolia_api_version}/indexes/*/queries")}
    end
  end

  @spec headers :: {:ok, [{String.t(), String.t()}]} | {:error, any}
  defp headers do
    config = Application.get_env(:mobile_app_backend, MobileAppBackend.Search.Algolia)
    app_id = config[:app_id]
    search_key = config[:search_key]

    if is_nil(app_id) || is_nil(search_key) do
      {:error, :missing_algolia_config}
    else
      {:ok,
       [
         {"X-Algolia-API-Key", search_key},
         {"X-Algolia-Application-Id", app_id}
       ]}
    end
  end
end
