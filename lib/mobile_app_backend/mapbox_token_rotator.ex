defmodule MobileAppBackend.MapboxTokenRotator.Behaviour do
  @callback get_public_token() :: String.t()
end

defmodule MobileAppBackend.MapboxTokenRotator do
  use GenServer

  alias MobileAppBackend.MapboxTokenRotator

  @behaviour MapboxTokenRotator.Behaviour

  defmodule State do
    defstruct [:primary_token, :username, :current_public_token, :expire_ms, :rotate_ms]
  end

  def start_link(opts) do
    server_name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, nil, name: server_name)
  end

  @impl MapboxTokenRotator.Behaviour
  def get_public_token(server \\ __MODULE__) do
    GenServer.call(server, :get_public_token)
  end

  @impl GenServer
  def init(_) do
    config = Application.get_env(:mobile_app_backend, MobileAppBackend.ClientConfig)

    state =
      case Keyword.fetch(config, :mapbox_primary_token) do
        {:ok, primary_token} ->
          Process.send_after(self(), :rotate_token, 0)

          %State{
            primary_token: primary_token,
            username: config[:mapbox_username],
            expire_ms: config[:token_expiration],
            rotate_ms: config[:token_renewal]
          }

        _ ->
          %State{current_public_token: config[:mapbox_public_token]}
      end

    {:ok, state}
  end

  @impl GenServer
  def handle_call(:get_public_token, _from, %State{current_public_token: public_token} = state) do
    {:reply, public_token, state}
  end

  @impl GenServer
  def handle_info(:rotate_token, %State{} = state) do
    expiration_time = DateTime.utc_now() |> DateTime.add(state.expire_ms, :millisecond)

    {:ok, %Req.Response{status: 201, body: %{"token" => public_token}}} =
      Req.new(
        method: :post,
        url: "https://api.mapbox.com/tokens/v2/#{state.username}",
        params: %{access_token: state.primary_token},
        json: %{
          expires: expiration_time |> DateTime.to_iso8601(),
          scopes: ["styles:read", "fonts:read"]
        }
      )
      |> MobileAppBackend.HTTP.request()

    Process.send_after(self(), :rotate_token, state.rotate_ms)

    {:noreply, %State{state | current_public_token: public_token}}
  end
end
