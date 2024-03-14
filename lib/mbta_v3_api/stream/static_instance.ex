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
    |> Map.put(:id, {__MODULE__, topic})
  end

  @spec subscribe(Phoenix.PubSub.topic()) :: {:ok, Stream.State.t()} | {:error, term()}
  def subscribe(topic) do
    with :ok <- Stream.PubSub.subscribe(topic) do
      current_data = GenServer.call(Stream.Registry.via_name(topic), :get_data)
      {:ok, current_data}
    end
  end
end
