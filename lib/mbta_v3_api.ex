defmodule MBTAV3API do
  @moduledoc "Handles fetching and caching generic JSON:API responses from the V3 API."

  require Logger
  alias MBTAV3API.JsonApi

  @type params :: %{String.t() => String.t()}

  @spec get_json(String.t(), params(), Keyword.t()) :: JsonApi.t() | {:error, any}
  @doc """
  Fetch from the V3API using `if-modified-since` header with optional time-based caching.
  Options:
  `:ttl_minutes` - optional ttl for the cached response (defaults to 0).
    If the ttl has expired, will re-fetch from the api using the `if-modified-since` header and will reset the ttl if the data has not changed.
  `:now` - value of now to use when evaluating `:ttl_minutes` (defaults to `DateTime.utc_now()`)
  `:base_url` - defaults to read from config
  `:api_key` - defaults to read from config
  `:timeout` - defaults to 7_000ms

  """
  def get_json(url, params \\ %{}, opts \\ []) do
    _ =
      Logger.debug(fn ->
        "MBTAV3API.get_json url=#{url} params=#{params |> Jason.encode!()}"
      end)

    {:ok, cache_value} =
      url
      |> MBTAV3API.ResponseCache.cache_key(params)
      |> MBTAV3API.ResponseCache.get()

    if is_nil(cache_value) do
      fetch_on_cache_miss(url, params, opts)
    else
      {_last_modified, expires_at, data} = cache_value

      if DateTime.before?(Keyword.get(opts, :now, DateTime.utc_now()), expires_at) do
        data
      else
        fetch_on_cache_hit(url, params, cache_value, opts)
      end
    end
  end

  defp fetch_on_cache_miss(url, params, opts) do
    url
    |> fetch(params, opts)
    |> parse_response(url, params, opts)
  end

  # Fetch using the if-modified-since header. If the response is a 304, bump the expiration time
  # on the cache & return the cached response. Otherwise, process the response and update the cached value
  defp fetch_on_cache_hit(url, params, {last_modified, _expires_at, cached_data}, opts) do
    opts =
      opts
      |> Keyword.merge(headers: [{"if-modified-since", last_modified}])
      |> Keyword.put_new(:ttl_minutes, 0)

    response = fetch(url, params, opts)

    case response do
      %{status: 304} ->
        Logger.info("#{__MODULE__} cache hit url=#{url} params=#{inspect(params)}")

        update_cached_response(
          url,
          params,
          cached_data,
          [{"last-modified", [last_modified]}],
          opts
        )

        cached_data

      _ ->
        parse_response(response, url, params, opts)
    end
  end

  defp fetch(url, params, opts) do
    body = ""

    opts =
      default_options()
      |> Keyword.merge(opts)
      |> Keyword.put_new(:ttl_minutes, 0)
      |> Keyword.put_new(:now, DateTime.utc_now())

    with {time, response} <- timed_get(url, params, opts),
         :ok <- log_response(url, params, time, response),
         {:ok, %Req.Response{status: _status} = response_content} <- response do
      response_content
    else
      {:error, error} ->
        _ = log_response_error(url, params, body)
        {:error, error}

      error ->
        _ = log_response_error(url, params, body)
        {:error, error}
    end
  end

  defp parse_response({:error, error}, _, _, _) do
    {:error, error}
  end

  defp parse_response(%{body: body, headers: headers}, url, params, opts) do
    parsed_response =
      body
      |> JsonApi.parse()
      |> maybe_log_parse_error(url, params, body)

    case parsed_response do
      {:error, error} ->
        {:error, error}

      valid_parsed_response ->
        update_cached_response(url, params, valid_parsed_response, headers, opts)
        valid_parsed_response
    end
  end

  defp update_cached_response(url, params, response, headers, opts) do
    date =
      headers
      |> Enum.into(%{})
      |> Map.get("last-modified", [])
      |> List.first()

    expires_at =
      DateTime.add(
        Keyword.get(opts, :now, DateTime.utc_now()),
        Keyword.get(opts, :ttl_minutes, 0),
        :minute
      )

    url
    |> MBTAV3API.ResponseCache.cache_key(params)
    |> MBTAV3API.ResponseCache.put({date, expires_at, response})
  end

  @spec start_stream(String.t(), %{String.t() => String.t()}, Keyword.t()) ::
          MBTAV3API.Stream.Supervisor.on_start_instance()
  def start_stream(url, params \\ %{}, opts \\ []) do
    _ =
      Logger.debug(fn ->
        "MBTAV3API.start_stream url=#{url} params=#{params |> Jason.encode!()}"
      end)

    MBTAV3API.Stream.Supervisor.start_instance(stream_args(url, params, opts))
  end

  def stream_args(url, params \\ %{}, opts \\ []) do
    opts = Keyword.merge(default_stream_options(), opts)
    api_key = Keyword.fetch!(opts, :api_key)
    base_url = Keyword.fetch!(opts, :base_url)
    destination = Keyword.fetch!(opts, :destination)
    type = Keyword.fetch!(opts, :type)

    headers = MBTAV3API.Headers.build(api_key) |> Keyword.reject(fn {_, v} -> is_nil(v) end)

    url =
      URI.parse(base_url)
      |> URI.append_path(URI.encode(url))
      |> URI.append_query(URI.encode_query(params))
      |> URI.to_string()

    [
      url: url,
      headers: headers,
      destination: destination,
      type: type
    ]
  end

  defp timed_get(url, params, opts) do
    api_key = Keyword.fetch!(opts, :api_key)
    base_url = Keyword.fetch!(opts, :base_url)

    headers =
      Keyword.get(opts, :headers, []) ++
        [{"accept", "application/vnd.api+json"} | MBTAV3API.Headers.build(api_key)]

    timeout = Keyword.fetch!(opts, :timeout)

    {time, response} =
      :timer.tc(fn ->
        Req.new(
          finch: Finch.CustomPool,
          method: :get,
          base_url: base_url,
          url: URI.encode(url),
          headers: headers,
          params: params,
          compressed: true,
          decode_body: false,
          retry_delay: fn _ -> 300 end,
          max_retries: 2,
          pool_timeout: timeout,
          receive_timeout: timeout
        )
        |> MobileAppBackend.HTTP.request()
      end)

    {time, response}
  end

  @spec maybe_log_parse_error(JsonApi.t() | {:error, any}, String.t(), params(), String.t()) ::
          JsonApi.t() | {:error, any}
  defp maybe_log_parse_error({:error, error}, url, params, body) do
    _ = log_response_error(url, params, body)
    {:error, error}
  end

  defp maybe_log_parse_error(response, _, _, _) do
    response
  end

  @spec log_response(String.t(), params(), integer, any) :: :ok
  defp log_response(url, params, time, response) do
    entry = fn ->
      "MBTAV3API.get_json_response url=#{inspect(url)} " <>
        "params=#{params |> Jason.encode!()} " <>
        log_body(response) <>
        " duration=#{time / 1000}" <>
        " request_id=#{Logger.metadata() |> Keyword.get(:request_id)}"
    end

    _ = Logger.info(entry)
    :ok
  end

  @spec log_response_error(String.t(), params(), String.t()) :: :ok
  defp log_response_error(url, params, body) do
    entry = fn ->
      "MBTAV3API.get_json_response url=#{inspect(url)} " <>
        "params=#{params |> Jason.encode!()} response=" <> body
    end

    _ = Logger.info(entry)
    :ok
  end

  defp log_body({:ok, response}) do
    "status=#{response.status} content_length=#{byte_size(response.body)}"
  end

  defp log_body({:error, error}) do
    ~s(status=error error="#{inspect(error)}")
  end

  defp default_options do
    [
      base_url: Application.get_env(:mobile_app_backend, :base_url),
      api_key: Application.get_env(:mobile_app_backend, :api_key),
      timeout: 7_000
    ]
  end

  defp default_stream_options do
    Keyword.take(default_options(), [:base_url, :api_key])
    |> Keyword.merge(destination: self())
  end
end
