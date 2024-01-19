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
    """
    defstruct [:host, :path, :query]

    def from_conn(%Plug.Conn{host: host, request_path: path, query_string: query}) do
      %URI{host: v3_host} = URI.parse(Application.get_env(:mobile_app_backend, :base_url))

      host =
        case host do
          ^v3_host -> "V3_API"
          _ -> raise "Unknown host reference #{host}"
        end

      %Request{
        host: host,
        path: path,
        query: query
      }
    end

    defimpl String.Chars do
      def to_string(%{host: host, path: path, query: query}) do
        %URI{
          host: host,
          path: path,
          query:
            case query do
              "" -> nil
              _ -> query
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
  end

  @doc "Starts the server."
  @spec start_link :: GenServer.on_start()
  def start_link do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  @doc """
  Sends a response to the given request.
  """
  @spec respond(Plug.Conn.t()) :: Plug.Conn.t()
  def respond(conn) do
    request = Request.from_conn(conn)

    stored_response = GenServer.call(__MODULE__, {:get, request})

    conn = conn |> Plug.Conn.put_resp_content_type("application/vnd.api+json")

    cond do
      updating_test_data?() ->
        data = update_response(conn, stored_response)

        Plug.Conn.send_resp(conn, :ok, Jason.encode_to_iodata!(data))

      is_nil(stored_response) ->
        Logger.warning("No test data for #{request}")

        Plug.Conn.send_resp(conn, :not_found, ~s({"errors":[{"code":"not_found"}]}))

      true ->
        Plug.Conn.send_file(conn, 200, response_path(stored_response))
    end
  end

  @doc """
  Creates new and deletes unused backend responses.

  Assumes that test data is being updated.
  """
  @spec write_new_data :: :ok
  def write_new_data do
    GenServer.call(__MODULE__, :write_new_data)
  end

  @doc """
  Issues warnings for recorded responses which were not used in this test session.
  """
  @spec warn_untouched :: :ok
  def warn_untouched do
    GenServer.call(__MODULE__, :warn_untouched)
  end

  @impl GenServer
  def init(_) do
    initial_state =
      with meta_path <- test_data_path("meta.json"),
           {:ok, meta} <- File.read(meta_path),
           {:ok, meta} <- Jason.decode(meta) do
        hydrate_state(meta)
      else
        _ -> %{}
      end

    {:ok, initial_state}
  end

  @impl GenServer
  def handle_call({:get, request}, _from, state) do
    # set touched: true if req in state, but do not put if req not in state

    case Map.get(state, request) do
      nil ->
        {:reply, nil, state}

      result ->
        result = %Response{result | touched: true}
        state = Map.put(state, request, result)
        {:reply, result, state}
    end
  end

  def handle_call({:put, request, data}, _from, state) do
    state =
      update_in(state[request], fn
        nil -> %Response{id: Uniq.UUID.uuid7(), new_data: data, touched: true}
        resp -> %Response{resp | new_data: data, touched: true}
      end)

    {:reply, :ok, state}
  end

  def handle_call(:write_new_data, _from, state) do
    {touched, untouched} =
      state
      |> Map.split_with(fn {_req, %Response{touched: touched}} -> touched end)

    untouched
    |> Enum.each(fn {req, resp} ->
      Logger.info("Deleting unused #{req}")
      File.rm!(response_path(resp))
    end)

    touched
    |> Enum.filter(fn {_req, %Response{new_data: new_data}} -> not is_nil(new_data) end)
    |> Enum.each(fn {_req, resp} ->
      File.write!(response_path(resp), Jason.encode_to_iodata!(resp.new_data))
    end)

    state = touched
    meta = dehydrate_state(state)
    File.write!(test_data_path("meta.json"), Jason.encode_to_iodata!(meta, pretty: true))

    {:reply, :ok, state}
  end

  def handle_call(:warn_untouched, _from, state) do
    unless updating_test_data?() do
      for {req, resp} <- state do
        unless resp.touched do
          Logger.warning("Unused test data for #{req}")
        end
      end
    end

    {:reply, :ok, state}
  end

  defp hydrate_state(meta_json) do
    meta_json
    |> flatten_map_entries()
    |> Map.new(fn {host, path, query, id} ->
      {%Request{host: host, path: path, query: query}, %Response{id: id}}
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
    for {%Request{host: host, path: path, query: query}, %Response{id: id}} <- state,
        reduce: %{} do
      data ->
        data
        |> Map.put_new(host, %{})
        |> update_in([host], &Map.put_new(&1, path, %{}))
        |> put_in([host, path, query], id)
    end
  end

  defp updating_test_data? do
    Application.get_env(:mobile_app_backend, :updating_test_data?, false)
  end

  defp test_data_path(file) do
    Application.app_dir(:mobile_app_backend, ["priv", "test_data", file])
  end

  defp response_path(%Response{id: id}) do
    test_data_path("#{id}.json")
  end

  defp update_response(conn, stored_response) do
    request = Request.from_conn(conn)

    expected_response =
      with %Response{} <- stored_response,
           {:ok, old_data} <- File.read(response_path(stored_response)),
           {:ok, old_data} <- Jason.decode(old_data) do
        old_data
      else
        _ -> nil
      end

    %Req.Response{status: 200, body: actual_response} =
      Req.get!(Plug.Conn.request_url(conn), headers: conn.req_headers)

    cond do
      is_nil(expected_response) ->
        Logger.info("Creating #{request}")
        GenServer.call(__MODULE__, {:put, request, actual_response})

      expected_response == actual_response ->
        :ok

      true ->
        diff =
          ExUnit.Formatter.format_assertion_error(%ExUnit.AssertionError{
            left: expected_response,
            right: actual_response,
            context: nil
          })

        Logger.warning("Response for #{request} changed: #{diff}")
    end

    actual_response
  end
end
