defmodule MBTAV3API do
  @moduledoc "Handles fetching and caching generic JSON:API responses from the V3 API."

  require Logger
  alias MBTAV3API.JsonApi

  @type params :: %{String.t() => String.t()}

  @spec get_json(String.t(), params(), Keyword.t()) :: JsonApi.t() | {:error, any}
  def get_json(url, params \\ %{}, opts \\ []) do
    _ =
      Logger.debug(fn ->
        "MBTAV3API.get_json url=#{url} params=#{params |> Jason.encode!()}"
      end)

    body = ""
    opts = Keyword.merge(default_options(), opts)

    with {time, response} <- timed_get(url, params, opts),
         :ok <- log_response(url, params, time, response),
         {:ok, %Req.Response{body: body}} <- response do
      body
      |> JsonApi.parse()
      |> maybe_log_parse_error(url, params, body)
    else
      {:error, error} ->
        _ = log_response_error(url, params, body)
        {:error, error}

      error ->
        _ = log_response_error(url, params, body)
        {:error, error}
    end
  end

  defp timed_get(url, params, opts) do
    api_key = Keyword.fetch!(opts, :api_key)
    base_url = Keyword.fetch!(opts, :base_url)
    headers = [{"accept", "application/vnd.api+json"} | MBTAV3API.Headers.build(api_key)]
    timeout = Keyword.fetch!(opts, :timeout)

    {time, response} =
      :timer.tc(fn ->
        Req.new(
          method: :get,
          base_url: base_url,
          url: URI.encode(url),
          headers: headers,
          params: params,
          compressed: true,
          decode_body: false,
          cache: true,
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
      timeout: 10_000
    ]
  end
end
