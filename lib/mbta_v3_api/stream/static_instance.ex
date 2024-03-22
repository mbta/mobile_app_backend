defmodule MBTAV3API.Stream.StaticInstance do
  @moduledoc """
  A `MBTAV3API.Stream.Instance` that always runs whether there's demand for the data or not.
  """
  alias MBTAV3API.JsonApi
  alias MBTAV3API.Stream

  def child_spec(opts) do
    type = Keyword.fetch!(opts, :type)
    {params, opts} = Keyword.split(opts, [:sort, :fields, :include, :filter])
    params = JsonApi.Params.flatten_params(params, type)
    url = Keyword.fetch!(opts, :url)
    {topic, opts} = Keyword.pop!(opts, :topic)

    (MBTAV3API.stream_args(url, params, opts ++ [destination: topic]) ++
       [name: Stream.Registry.via_name(topic)])
    |> Stream.Instance.child_spec()
    |> Map.merge(%{id: {__MODULE__, topic}, restart: :permanent})
  end

  @spec subscribe(Phoenix.PubSub.topic()) :: {:ok, Stream.State.t()} | {:error, term()}
  def subscribe(topic) do
    with :ok <- Stream.PubSub.subscribe(topic) do
      if is_nil(Stream.Registry.find_pid(topic)) do
        Stream.Supervisor.start_static_instance(args_for_topic(topic))
      end

      current_data = GenServer.call(Stream.Registry.via_name(topic), :get_data)
      {:ok, current_data}
    end
  end

  @spec args_for_topic(Phoenix.PubSub.topic()) :: Stream.Instance.opts()
  defp args_for_topic("alerts") do
    [type: MBTAV3API.Alert, url: "/alerts", topic: "alerts"]
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
end
