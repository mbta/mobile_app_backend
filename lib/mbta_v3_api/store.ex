defmodule MBTAV3API.Store do
  @moduledoc """
  Behaviour defining a store of data that contains the state of the world
  based a the series of events streamed from a `MBTAV3Api.Stream.Consumer`.
  """
  alias MBTAV3API.JsonApi

  @type upsert_event :: :add | :update
  @type fetch_keys :: keyword() | [keyword()]

  @doc """
  Add or update existing data in the data store
  """
  @callback process_upsert(upsert_event(), [JsonApi.Object.t()]) :: :ok | :error

  @doc """
  Reset the data for the given scope to contain only the given objects.
  For example, given the scope [route_id: "66"], only existing records for the route "66" would be cleared, and the given new records added.
  """
  @callback process_reset([JsonApi.Object.t()], keyword()) :: :ok | :error

  @doc """
  Remove records for the given id
  """
  @callback process_remove([JsonApi.Reference.t()]) :: :ok | :error

  @doc """
  Retrieve all records that match the given filter keys.
  When given a single keyword list, all keys in the list must match.
  When given a list of keyword lists, must match any of the keyword lists.

  Does not include any associated records
  """
  @callback fetch(fetch_keys()) :: [JsonApi.Object.t()]

  @doc """
  Retrieve all records that match the given filter keys, and the relevant associated records
  based on the included record types for the  `MBTAV3API.Stream.StaticInstance.` that is populating the store.

  When given a single keyword list, all keys in the list must match.
  When given a list of keyword lists, must match any of the keyword lists
  """
  @callback fetch_with_associations(fetch_keys()) :: JsonApi.Object.full_map()

  defmacro __using__(opts) do
    quote location: :keep, bind_quoted: [opts: opts] do
      @behaviour MBTAV3API.Store

      implementation_module = Keyword.fetch!(opts, :implementation_module)

      def start_link(opts) do
        Application.get_env(:mobile_app_backend, __MODULE__, unquote(implementation_module)).start_link(
          opts
        )
      end

      @impl true
      def init(opts) do
        Application.get_env(:mobile_app_backend, __MODULE__, unquote(implementation_module)).init(opts)
      end

      @impl true
      def fetch(fetch_keys) do
        Application.get_env(:mobile_app_backend, __MODULE__, unquote(implementation_module)).fetch(
          fetch_keys
        )
      end

      @impl true
      def fetch_with_associations(fetch_keys) do
        Application.get_env(:mobile_app_backend, __MODULE__, unquote(implementation_module)).fetch_with_associations(
          fetch_keys
        )
      end

      @impl true
      def process_upsert(event, data) do
        Application.get_env(:mobile_app_backend, __MODULE__, unquote(implementation_module)).process_upsert(
          event,
          data
        )
      end

      @impl true
      def process_reset(data, scope) do
        Application.get_env(:mobile_app_backend, __MODULE__, unquote(implementation_module)).process_reset(
          data,
          scope
        )
      end

      @impl true
      def process_remove(references) do
        Application.get_env(:mobile_app_backend, __MODULE__, unquote(implementation_module)).process_remove(
          references
        )
      end
    end
  end
end
