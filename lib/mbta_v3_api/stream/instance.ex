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

    children = [
      {MobileAppBackend.SSE,
       name: MBTAV3API.Stream.Registry.via_name(ref), url: url, headers: headers},
      {MBTAV3API.Stream.Consumer,
       subscribe_to: [{MBTAV3API.Stream.Registry.via_name(ref), []}],
       destination: destination,
       type: type,
       name: name}
    ]

    Supervisor.init(children, strategy: :rest_for_one)
  end

  def check_health(pid) do
    children = Supervisor.which_children(pid)

    {_, sses, _, _} =
      Enum.find(children, {nil, nil, nil, nil}, fn {_, _, _, [module]} ->
        module == ServerSentEventStage
      end)

    {_, consumer, _, _} =
      Enum.find(children, {nil, nil, nil, nil}, fn {_, _, _, [module]} ->
        module == MBTAV3API.Stream.Consumer
      end)

    stage_alive = not is_nil(sses) and Process.alive?(sses)
    consumer_alive = not is_nil(consumer) and Process.alive?(consumer)

    stage_open =
      if stage_alive do
        %GenStage{state: %ServerSentEventStage{conn: conn}} = :sys.get_state(sses)

        conn != nil and Mint.HTTP.open?(conn)
      end

    consumer_dest =
      if consumer_alive do
        %GenStage{state: %MBTAV3API.Stream.Consumer.State{destination: destination}} =
          :sys.get_state(consumer)

        case destination do
          topic when is_binary(topic) -> topic
          pid when is_pid(pid) -> inspect(pid)
        end
      end

    consumer_subscribers =
      if consumer_dest do
        Registry.count_match(MBTAV3API.Stream.PubSub, consumer_dest, :_)
      end

    health_state =
      [
        stage_alive: stage_alive,
        consumer_alive: consumer_alive,
        stage_open: stage_open,
        consumer_dest: consumer_dest,
        consumer_subscribers: consumer_subscribers
      ]
      |> Enum.map_join(" ", fn {name, value} -> "#{name}=#{value}" end)

    if stage_alive and consumer_alive and stage_open do
      Logger.info("#{__MODULE__} #{health_state}")
    else
      Logger.warning("#{__MODULE__} #{health_state}")
    end
  end
end
