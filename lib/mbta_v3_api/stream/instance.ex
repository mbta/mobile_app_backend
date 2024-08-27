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
    type = Keyword.fetch!(opts, :type)
    destination = Keyword.fetch!(opts, :destination)
    name = Keyword.get(opts, :name)
    store = Keyword.get(opts, :store)

    children = [
      {MobileAppBackend.SSE,
       name: MBTAV3API.Stream.Registry.via_name(ref),
       url: url,
       headers: headers,
       idle_timeout: :timer.seconds(45)}
    ]

    children =
      children ++
        if is_nil(store) do
          [
            {MBTAV3API.Stream.Consumer,
             subscribe_to: [{MBTAV3API.Stream.Registry.via_name(ref), []}],
             destination: destination,
             type: type,
             name: name}
          ]
        else
          require Logger
          [
            {MBTAV3API.Stream.StoreWriteConsumer,
             subscribe_to: [{MBTAV3API.Stream.Registry.via_name(ref), []}],
             destination: destination,
             type: type,
             name: name,
             store: store,
             scope: Keyword.get(opts, :scope)}
          ]
        end

    Supervisor.init(children, strategy: :rest_for_one)
  end

  def check_health(pid) do
    children = Supervisor.which_children(pid)

    {_, sses_pid, _, _} =
      Enum.find(children, {nil, nil, nil, nil}, fn {_, _, _, [module]} ->
        module == ServerSentEventStage
      end)

    {_, consumer_pid, _, _} =
      Enum.find(children, {nil, nil, nil, nil}, fn {_, _, _, [module]} ->
        module == MBTAV3API.Stream.Consumer || module == MBTAV3API.Stream.StoreWriteConsumer
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
        %GenStage{state: %{destination: destination}} =
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
