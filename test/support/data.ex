defmodule Test.Support.Data do
  @moduledoc """
  Manages the use of recorded responses to HTTP requests from tests.
  """
  require Logger
  use GenServer

  defmodule Request do
    @doc """
    Represents a request that was made to a backend HTTP service.

    `:host` is an abstract value denoting the config source, rather than the literal hostname.
    This avoids issues with connecting to the dev vs prod API invalidating the tests.

    For the V3 API, `:body` is the query string in the GET request.
    For OpenTripPlanner, `:body` is the body in the POST request.
    """
    defstruct [:host, :path, :body]

    @type t :: %__MODULE__{host: String.t(), path: String.t(), body: String.t()}

    def from_conn(%Plug.Conn{host: host, request_path: path} = conn) do
      %URI{host: v3_host} = URI.parse(Application.get_env(:mobile_app_backend, :base_url))
      %URI{host: otp_host} = URI.parse(Application.get_env(:mobile_app_backend, :otp_url))

      {host, body} =
        case host do
          ^v3_host ->
            {"V3_API", conn.query_string}

          ^otp_host ->
            {:ok, body, _conn} = Plug.Conn.read_body(conn)
            {"OPEN_TRIP_PLANNER", body}

          _ ->
            raise "Unknown host reference #{host}"
        end

      %Request{
        host: host,
        path: path,
        body: body
      }
    end

    defimpl String.Chars do
      def to_string(%{host: host, path: path, body: body}) do
        %URI{
          host: host,
          path: path,
          query:
            case {host, body} do
              {"OPEN_TRIP_PLANNER", _} -> nil
              {_, ""} -> nil
              _ -> body
            end
        }
        |> URI.to_string()
      end
    end
  end

  defmodule Response do
    @doc """
    Represents a response which was received from a backend API,
    and which may or may not have been used in this test session.
    """
    @enforce_keys [:id]
    defstruct [:id, :new_data, touched: false]
    @type t :: %__MODULE__{id: String.t(), new_data: binary() | nil, touched: boolean()}
  end

  defmodule State do
    @moduledoc """
    The state for the Data server.
    """
    defstruct data: %{}, updating_test_data?: false
    @type t :: %__MODULE__{data: %{Request.t() => Response.t()}, updating_test_data?: boolean()}
  end

  @doc "Starts the server."
  @spec start_link(Keyword.t()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    {server_opts, state_opts} = Keyword.split(opts, [:name])
    server_opts = Keyword.put_new(server_opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, state_opts, server_opts)
  end

  @doc """
  Sends a response to the given request.
  """
  @spec respond(Plug.Conn.t(), GenServer.server()) :: Plug.Conn.t()
  def respond(conn, server \\ __MODULE__) do
    request = Request.from_conn(conn)

    stored_response = GenServer.call(server, {:get, request})

    conn = conn |> Plug.Conn.put_resp_content_type("application/vnd.api+json")

    cond do
      GenServer.call(server, :updating_test_data?) ->
        data = update_response(conn, stored_response, server)

        Plug.Conn.send_resp(conn, :ok, Jason.encode_to_iodata!(data))

      is_nil(stored_response) ->
        Logger.warning("No test data for #{request}")

        Plug.Conn.send_resp(conn, :not_found, ~s({"errors":[{"code":"not_found"}]}))

      true ->
        Plug.Conn.send_file(conn, 200, response_path(stored_response))
    end
  end

  @doc """
  Creates new and optionally deletes unused backend responses.

  Assumes that test data is being updated.
  """
  @spec write_new_data(Keyword.t()) :: :ok
  def write_new_data(opts) do
    GenServer.call(__MODULE__, {:write_new_data, opts})
  end

  @doc """
  Issues warnings for recorded responses which were not used in this test session.
  """
  @spec warn_untouched :: :ok
  def warn_untouched do
    GenServer.call(__MODULE__, :warn_untouched)
  end

  @impl GenServer
  def init(opts) do
    updating_test_data? = Keyword.get(opts, :updating_test_data?, false)

    initial_data =
      with meta_path <- test_data_path("meta.json"),
           {:ok, meta} <- File.read(meta_path),
           {:ok, meta} <- Jason.decode(meta) do
        hydrate_state(meta)
      else
        _ -> %{}
      end

    {:ok, %State{data: initial_data, updating_test_data?: updating_test_data?}}
  end

  @impl GenServer
  def handle_call({:get, request}, _from, %State{} = state) do
    # set touched: true if req in state, but do not put if req not in state

    case Map.get(state.data, request) do
      nil ->
        {:reply, nil, state}

      result ->
        result = %Response{result | touched: true}
        state = put_in(state.data[request], result)
        {:reply, result, state}
    end
  end

  def handle_call({:put, request, data}, _from, %State{} = state) do
    state =
      update_in(state.data[request], fn
        nil -> %Response{id: Uniq.UUID.uuid7(), new_data: data, touched: true}
        resp -> %Response{resp | new_data: data, touched: true}
      end)

    {:reply, :ok, state}
  end

  def handle_call({:write_new_data, opts}, _from, %State{} = state) do
    unless state.updating_test_data? do
      raise "Wrote new data, but not updating test data"
    end

    remove_unused = Keyword.get(opts, :remove_unused, false)

    {touched, untouched} =
      state.data
      |> Map.split_with(fn {_req, %Response{touched: touched}} -> touched end)

    if remove_unused do
      untouched
      |> Enum.each(fn {req, resp} ->
        Logger.info("Deleting unused #{req}")
        File.rm!(response_path(resp))
      end)
    end

    touched
    |> Enum.filter(fn {_req, %Response{new_data: new_data}} -> not is_nil(new_data) end)
    |> Enum.each(fn {_req, resp} ->
      File.write!(response_path(resp), Jason.encode_to_iodata!(resp.new_data, pretty: true))
    end)

    state =
      if remove_unused do
        %State{state | data: touched}
      else
        state
      end

    meta = dehydrate_state(state.data)
    File.write!(test_data_path("meta.json"), Jason.encode_to_iodata!(meta, pretty: true))

    {:reply, :ok, state}
  end

  def handle_call(:warn_untouched, _from, %State{} = state) do
    unless state.updating_test_data? do
      for {req, resp} <- state.data do
        unless resp.touched do
          Logger.warning("Unused test data for #{req}")
        end
      end
    end

    {:reply, :ok, state}
  end

  def handle_call(:updating_test_data?, _from, %State{} = state) do
    {:reply, state.updating_test_data?, state}
  end

  defp hydrate_state(meta_json) do
    meta_json
    |> flatten_map_entries()
    |> Map.new(fn {host, path, body, id} ->
      {%Request{host: host, path: path, body: body}, %Response{id: id}}
    end)
  end

  defp flatten_map_entries(%{} = map) do
    Stream.flat_map(map, fn
      {key, val} when is_map(val) ->
        flatten_map_entries(val) |> Stream.map(&Tuple.insert_at(&1, 0, key))

      {key, val} ->
        [{key, val}]
    end)
  end

  defp dehydrate_state(state) do
    for {%Request{host: host, path: path, body: body}, %Response{id: id}} <- state,
        reduce: %{} do
      data ->
        data
        |> Map.put_new(host, %{})
        |> update_in([host], &Map.put_new(&1, path, %{}))
        |> put_in([host, path, body], id)
    end
  end

  defp test_data_path(file) do
    Application.app_dir(:mobile_app_backend, ["priv", "test_data", file])
  end

  defp response_path(%Response{id: id}) do
    test_data_path("#{id}.json")
  end

  @spec update_response(Plug.Conn.t(), Response.t() | nil, GenServer.server()) :: binary()
  defp update_response(conn, stored_response, server) do
    request = Request.from_conn(conn)

    {expected_response, response_id} =
      with %Response{id: response_id} <- stored_response,
           {:ok, old_data} <- File.read(response_path(stored_response)),
           {:ok, old_data} <- Jason.decode(old_data) do
        {old_data, response_id}
      else
        _ -> {nil, nil}
      end

    body =
      case conn.method do
        "GET" -> nil
        "POST" -> request.body
      end

    %Req.Response{status: 200, body: actual_response} =
      Req.new(
        url: Plug.Conn.request_url(conn),
        method: conn.method,
        headers: conn.req_headers,
        body: body
      )
      |> Req.request!()

    cond do
      is_nil(expected_response) ->
        Logger.info("Creating #{request}")
        GenServer.call(server, {:put, request, actual_response})

      expected_response == actual_response ->
        :ok

      true ->
        Logger.warning("Response #{response_id} for #{request} changed")

        GenServer.call(server, {:put, request, actual_response})
    end

    actual_response
  end
end
