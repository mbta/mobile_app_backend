defmodule MBTAV3API.Stream.StaticInstance do
  alias MBTAV3API.Stream
  alias MBTAV3API.Stream.StaticInstance

  @callback child_spec(keyword()) :: Supervisor.child_spec()

  @doc """
  Start a stream for the given topic if it doesn't already exist
  """
  @callback subscribe(Phoenix.PubSub.topic(), Keyword.t()) ::
              {:ok, Stream.State.t()} | {:error, term()}

  @spec child_spec(any()) :: any()
  def child_spec(opts) do
    Application.get_env(:mobile_app_backend, MBTAV3API.Stream.StaticInstance, StaticInstance.Impl).child_spec(
      opts
    )
  end

  def subscribe(topic, opts \\ []) do
    Application.get_env(:mobile_app_backend, MBTAV3API.Stream.StaticInstance, StaticInstance.Impl).subscribe(
      topic,
      opts
    )
  end
end

defmodule MBTAV3API.Stream.StaticInstance.Impl do
  @moduledoc """
  A `MBTAV3API.Stream.Instance` that always runs whether there's demand for the data or not.
  """
  alias MBTAV3API.JsonApi
  alias MBTAV3API.Stream
  require Logger
  @behaviour Stream.StaticInstance

  @impl true
  def child_spec(opts) do
    type = Keyword.fetch!(opts, :type)
    {params, opts} = Keyword.split(opts, [:sort, :fields, :include, :filter])
    params = JsonApi.Params.flatten_params(params, type)
    url = Keyword.fetch!(opts, :url)
    {topic, opts} = Keyword.pop!(opts, :topic)
    destination = Keyword.get(opts, :destination, topic)

    (MBTAV3API.stream_args(url, params, opts ++ [destination: destination]) ++
       [name: Stream.Registry.via_name(topic), consumer: Keyword.get(opts, :consumer)])
    |> Stream.Instance.child_spec()
    |> Map.merge(%{id: {Stream.StaticInstance, topic}, restart: :permanent})
  end

  @impl true
  def subscribe(topic, opts \\ []) do
    include_current_data = Keyword.get(opts, :include_current_data, true)

    with :ok <- Stream.PubSub.subscribe(topic) do
      if is_nil(Stream.Registry.find_pid(topic)) do
        {time_micros, _result} =
          :timer.tc(Stream.Supervisor, :start_static_instance, [args_for_topic(topic)])

        Logger.info(
          "#{__MODULE__} match=false topic=#{topic} started_stream duration =#{time_micros / 1000}"
        )
      else
        Logger.info("#{__MODULE__} match=true topic=#{topic}")
      end

      if include_current_data do
        current_data = GenServer.call(Stream.Registry.via_name(topic), :get_data)
        {:ok, current_data}
      else
        {:ok, :current_data_not_requested}
      end
    end
  end

  @spec args_for_topic(Phoenix.PubSub.topic()) :: Stream.Instance.opts()
  defp args_for_topic("alerts") do
    [type: MBTAV3API.Alert, url: "/alerts", topic: "alerts"]
  end

  defp args_for_topic("predictions:route:to_store:" <> route_id) do
    [
      type: MBTAV3API.Prediction,
      url: "/predictions",
      filter: [route: route_id],
      include: [:trip],
      # `:topic` is unique to a route because we stream predictions separately by route
      # `:destination` is the same across all routes because all predictions
      # are unified in `Store.Predictions`
      topic: "predictions:route:to_store:#{route_id}",
      destination: "predictions:all:events",
      consumer: %{
        store: MBTAV3API.Store.Predictions,
        scope: [route_id: route_id]
      }
    ]
  end

  defp args_for_topic("predictions:route:" <> route_id) do
    [
      type: MBTAV3API.Prediction,
      url: "/predictions",
      filter: [route: route_id],
      include: [:trip, :vehicle],
      topic: "predictions:route:#{route_id}"
    ]
  end

  defp args_for_topic("vehicles") do
    [type: MBTAV3API.Vehicle, url: "/vehicles", topic: "vehicles"]
  end
end
