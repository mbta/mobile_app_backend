defmodule MobileAppBackend.Throttler do
  use GenServer

  defmodule State do
    @type t :: %__MODULE__{
            target: GenServer.server(),
            cast: term(),
            ms: non_neg_integer(),
            last_cast: integer() | nil,
            timer: reference() | nil
          }
    defstruct [:target, :cast, :ms, :last_cast, :timer]

    def new(opts) do
      %__MODULE__{
        target: Keyword.fetch!(opts, :target),
        cast: Keyword.fetch!(opts, :cast),
        ms: Keyword.get(opts, :ms, 1000),
        last_cast: nil,
        timer: nil
      }
    end
  end

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts)
  end

  def request(throttler) do
    GenServer.cast(throttler, :request)
  end

  @impl true
  def init(opts) do
    {:ok, State.new(opts)}
  end

  @impl true
  def handle_cast(:request, %State{} = state) do
    now = now()

    next_cast =
      case state.last_cast do
        nil -> now
        last_cast -> last_cast + state.ms
      end

    state =
      cond do
        next_cast <= now ->
          GenServer.cast(state.target, state.cast)
          %State{state | last_cast: now}

        is_nil(state.timer) ->
          ref = Process.send_after(self(), :cast_now, next_cast, abs: true)
          %State{state | timer: ref}

        true ->
          state
      end

    {:noreply, state}
  end

  @impl true
  def handle_info(:cast_now, %State{} = state) do
    now = now()
    GenServer.cast(state.target, state.cast)
    state = %State{state | last_cast: now, timer: nil}
    {:noreply, state}
  end

  defp now, do: System.monotonic_time(:millisecond)
end
