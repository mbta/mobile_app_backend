defmodule MBTAV3API.Stream.Instance do
  require Logger
  use Supervisor, restart: :transient

  @opaque t :: pid()

  @type opt ::
          {:url, String.t()}
          | {:headers, [{String.t(), String.t()}]}
          | {:destination, pid() | Phoenix.PubSub.topic()}
          | {:type, module()}
  @type opts :: [opt()]

  @spec start_link(opts()) :: {:ok, t()} | :ignore | {:error, {:already_started, t()} | term()}
  def start_link(opts) do
    Supervisor.start_link(__MODULE__, opts)
  end

  @spec shutdown(t(), term()) :: :ok
  def shutdown(pid, reason \\ :shutdown) do
    Supervisor.stop(pid, reason)
  end

  @impl Supervisor
  def init(opts) do
    ref = make_ref()
    url = Keyword.fetch!(opts, :url)
    headers = Keyword.fetch!(opts, :headers)

    children = [
      {MobileAppBackend.SSE,
       name: MBTAV3API.Stream.Registry.via_name(ref),
       url: url,
       headers: headers,
       idle_timeout: :timer.seconds(45)},
      consumer_spec(Keyword.put(opts, :ref, ref))
    ]

    Supervisor.init(children, strategy: :rest_for_one)
  end

  @spec consumer_spec(keyword()) :: {module(), keyword()}
  @doc """
  Build a spec for the stream consumer based on the :consumer argument.
  Returns a `MBTAV3Api.StreamConsumer` spec by default if :consumer is not configured.
  """
  def consumer_spec(opts) do
    ref = Keyword.fetch!(opts, :ref)
    destination = Keyword.fetch!(opts, :destination)
    type = Keyword.fetch!(opts, :type)
    name = Keyword.get(opts, :name)

    case Keyword.get(opts, :consumer) do
      nil ->
        {MBTAV3API.Stream.Consumer,
         subscribe_to: [{MBTAV3API.Stream.Registry.via_name(ref), []}],
         destination: destination,
         type: type,
         name: name}

      %{store: store, scope: scope} ->
        {MBTAV3API.Stream.ConsumerToStore,
         subscribe_to: [{MBTAV3API.Stream.Registry.via_name(ref), []}],
         destination: destination,
         type: type,
         name: name,
         store: store,
         scope: scope}
    end
  end

  def check_health(pid) do
    children = Supervisor.which_children(pid)

    {_, sses_pid, _, _} =
      Enum.find(children, {nil, nil, nil, nil}, fn {_, _, _, [module]} ->
        module == ServerSentEventStage
      end)

    {_, consumer_pid, _, _} =
      Enum.find(children, {nil, nil, nil, nil}, fn {_, _, _, [module]} ->
        module == MBTAV3API.Stream.Consumer
      end)

    {stage_healthy, stage_info} = stage_health(sses_pid)
    {consumer_healthy, consumer_info} = consumer_health(consumer_pid)

    health_state =
      (stage_info ++ consumer_info)
      |> Enum.map_join(" ", fn {name, value} -> "#{name}=#{value}" end)

    if stage_healthy and consumer_healthy do
      Logger.info("#{__MODULE__} #{health_state}")
    else
      Logger.warning("#{__MODULE__} #{health_state}")
    end
  end

  defp stage_health(sses_pid) do
    stage_alive = not is_nil(sses_pid) and Process.alive?(sses_pid)

    stage_open =
      if stage_alive do
        %GenStage{state: %ServerSentEventStage{conn: conn}} = :sys.get_state(sses_pid)

        conn != nil and Mint.HTTP.open?(conn)
      else
        false
      end

    healthy = stage_alive and stage_open

    info = [stage_alive: stage_alive, stage_open: stage_open]

    {healthy, info}
  end

  defp consumer_health(consumer_pid) do
    consumer_alive = not is_nil(consumer_pid) and Process.alive?(consumer_pid)

    consumer_dest =
      if consumer_alive do
        %GenStage{state: %MBTAV3API.Stream.Consumer.State{destination: destination}} =
          :sys.get_state(consumer_pid)

        case destination do
          topic when is_binary(topic) -> topic
          pid when is_pid(pid) -> inspect(pid)
        end
      end

    consumer_subscribers =
      if consumer_dest do
        Registry.count_match(MBTAV3API.Stream.PubSub, consumer_dest, :_)
      end

    healthy = consumer_alive

    info =
      [
        consumer_alive: consumer_alive,
        consumer_dest: consumer_dest,
        consumer_subscribers: consumer_subscribers
      ]

    {healthy, info}
  end
end
