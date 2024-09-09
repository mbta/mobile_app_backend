defmodule MBTAV3API.Store.Predictions do
  @moduledoc """
  Store of predictions. Store is written to by any number of `MBTAV3API.Stream.ConsumerToStore`
  and can be read in parallel by other processes.

  Based on https://github.com/mbta/dotcom/blob/main/lib/predictions/store.ex
  """
  @behaviour MBTAV3API.Store

  @impl true
  def process_upsert(_event, _objects) do
    # TODO
    :ok
  end

  @impl true
  def process_reset(_objects, _scope) do
    # TODO
    :ok
  end

  @impl true
  def process_remove(_references) do
    # TODO
    :ok
  end

  @impl true
  def fetch(_scope) do
    []
  end
end
