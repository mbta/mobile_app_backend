defmodule OpenTripPlannerClient do
  @moduledoc """
  Fetches data from the OpenTripPlanner API.

  ## Configuration

  ```elixir
  config :mobile_app_backend,
    otp_url: "http://localhost:8080",
    timezone: "America/New_York"
  ```
  """

  require Logger

  alias OpenTripPlannerClient.{Itinerary, ItineraryTag, NamedPosition, ParamsBuilder, Parser}

  @behaviour OpenTripPlannerClient.Behaviour

  @type error :: OpenTripPlannerClient.Behaviour.error()
  @type plan_opt :: OpenTripPlannerClient.Behaviour.plan_opt()

  @impl true
  @doc """
  Generate a trip plan with the given endpoints and options.
  """
  @spec plan(NamedPosition.t(), NamedPosition.t(), [plan_opt()]) ::
          {:ok, Itinerary.t()} | {:error, error()}
  def plan(from, to, opts) do
    accessible? = Keyword.get(opts, :wheelchair_accessible?, false)

    {postprocess_opts, opts} = Keyword.split(opts, [:tags])

    with {:ok, params} <- ParamsBuilder.build_params(from, to, opts) do
      param_string = Enum.map_join(params, "\n", fn {key, val} -> ~s{#{key}: #{val}} end)

      graphql_query = """
      {
        plan(
          #{param_string}
        )
        #{itinerary_shape()}
      }
      """

      root_url =
        Keyword.get(opts, :root_url, Application.fetch_env!(:mobile_app_backend, :otp_url))

      graphql_url = "#{root_url}/otp/routers/default/index/"

      with {:ok, body} <- send_request(graphql_url, graphql_query),
           {:ok, itineraries} <- Parser.parse_ql(body, accessible?) do
        tags = Keyword.get(postprocess_opts, :tags, [])

        result =
          Enum.reduce(tags, itineraries, fn tag, itineraries ->
            ItineraryTag.apply_tag(tag, itineraries)
          end)

        {:ok, result}
      end
    end
  end

  defp send_request(url, query) do
    with {:ok, response} <- log_response(url, query),
         %{status: 200, body: body} <- response do
      {:ok, body}
    else
      %{status: _} = response ->
        {:error, response}

      error ->
        error
    end
  end

  defp log_response(url, query) do
    graphql_req =
      Req.new(base_url: url)
      |> AbsintheClient.attach()

    {duration, response} =
      :timer.tc(
        Req,
        :post,
        [graphql_req, [graphql: query]]
      )

    _ =
      Logger.info(fn ->
        "#{__MODULE__}.plan_response url=#{url} query=#{inspect(query)} #{status_text(response)} duration=#{duration / :timer.seconds(1)}"
      end)

    response
  end

  defp status_text({:ok, %{status: code}}) do
    "status=#{code}"
  end

  defp status_text({:error, error}) do
    "status=error error=#{inspect(error)}"
  end

  defp itinerary_shape do
    """
    {
      routingErrors {
        code
        description
      }
      itineraries {
        accessibilityScore
        startTime
        endTime
        duration
        legs {
          mode
          startTime
          endTime
          distance
          duration
          intermediateStops {
            id
            gtfsId
            name
            desc
            lat
            lon
            code
            locationType
          }
          transitLeg
          headsign
          realTime
          realtimeState
          agency {
            id
            gtfsId
            name
          }
          alerts {
            id
            alertHeaderText
            alertDescriptionText
          }
          fareProducts {
            id
            product {
              id
              name
              riderCategory {
                id
                name

              }
            }
          }
          from {
            name
            lat
            lon
            departureTime
            arrivalTime
            stop {
              gtfsId
            }
          }
          to {
            name
            lat
            lon
            departureTime
            arrivalTime
            stop {
              gtfsId
            }
          }
          route {
            gtfsId
            longName
            shortName
            desc
            color
            textColor
          }
          trip {
            gtfsId
          }
          steps {
            distance
            streetName
            lat
            lon
            relativeDirection
            stayOn
          }
          legGeometry {
            points
          }
        }
      }
    }
    """
  end
end
