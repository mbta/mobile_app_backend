defmodule MBTAV3API.Store do
  @moduledoc """
  Behaviour defining a store of data that contains the state of the world
  based a the series of events streamed from a `MBTAV3Api.Stream.Consumer`.
  """
  alias MBTAV3API.JsonApi

  @type upsert_event :: :add | :update

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
  """
  @callback fetch(keyword()) :: [JsonApi.Object.t()]
end
