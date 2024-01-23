defmodule OpenTripPlannerClient do
  @moduledoc """
  Fetches data from the OpenTripPlanner API.

  ## Configuration

  ```elixir
  config :mobile_app_backend,
    otp_url: "http://localhost:8080"
  ```
  """

  require Logger

  alias OpenTripPlannerClient.Nearby

  @doc """
  Fetches stops (and route patterns and routes) within the given number of meters of the given position.
  """
  @spec nearby(float(), float(), integer(), Keyword.t()) ::
          {:ok, {[MBTAV3API.Stop.t()], [MBTAV3API.RoutePattern.t()]}}
          | {:error, term()}
  def nearby(latitude, longitude, radius, opts \\ []) do
    root_url =
      Keyword.get(opts, :root_url, Application.fetch_env!(:mobile_app_backend, :otp_url))

    request =
      Nearby.request(latitude, longitude, radius)
      |> Req.update(base_url: root_url, url: "/otp/routers/default/index/graphql")

    case send_request(request) do
      {:ok, body} -> Nearby.parse(body)
      {:error, error} -> {:error, error}
    end
  end

  @spec send_request(Req.Request.t()) :: {:ok, term()} | {:error, term()}
  defp send_request(request) do
    with {:ok, response} <- log_response(request),
         %{status: 200, body: body} <- response do
      {:ok, body}
    else
      %{status: _} = response ->
        {:error, response}

      error ->
        error
    end
  end

  @spec log_response(Req.Request.t()) :: {:ok, Req.Response.t()} | {:error, term()}
  defp log_response(request) do
    {duration, response} =
      :timer.tc(
        MobileAppBackend.HTTP,
        :request,
        [request]
      )

    _ =
      Logger.info(fn ->
        "#{__MODULE__}.otp_response query=#{inspect(request.options[:graphql])} #{status_text(response)} duration=#{duration / :timer.seconds(1)}"
      end)

    response
  end

  defp status_text({:ok, %{status: code}}) do
    "status=#{code}"
  end

  defp status_text({:error, error}) do
    "status=error error=#{inspect(error)}"
  end
end
