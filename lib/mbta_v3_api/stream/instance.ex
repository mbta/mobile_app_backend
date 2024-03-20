defmodule MBTAV3API.Stream.Instance do
  use Supervisor, restart: :transient

  @opaque t :: pid()

  @type opt ::
          {:url, String.t()}
          | {:headers, [{String.t(), String.t()}]}
          | {:destination, pid() | Phoenix.PubSub.topic()}
          | {:type, module()}
          | {:name, term()}
          | {:throttle_ms, non_neg_integer()}
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

    sse_opts = Keyword.take(opts, [:url, :headers])
    consumer_opts = Keyword.take(opts, [:destination, :type, :name, :throttle_ms])

    children = [
      {MobileAppBackend.SSE, [name: MBTAV3API.Stream.Registry.via_name(ref)] ++ sse_opts},
      {MBTAV3API.Stream.Consumer,
       [subscribe_to: [{MBTAV3API.Stream.Registry.via_name(ref), []}]] ++ consumer_opts}
    ]

    Supervisor.init(children, strategy: :rest_for_one)
  end
end
