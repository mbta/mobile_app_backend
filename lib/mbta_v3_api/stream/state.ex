defmodule MBTAV3API.Stream.State do
  @moduledoc """
  Tracks the state of the world as remembered by a `MBTAV3API.Stream.Consumer`.

  Objects are stored in a `t:MBTAV3API.JsonApi.Object.full_map/0`.
  """

  alias MBTAV3API.JsonApi

  @type t :: JsonApi.Object.full_map()

  @spec new :: t()
  def new, do: JsonApi.Object.to_full_map([])

  @spec apply_events(t(), [ServerSentEventStage.Event.t()]) :: t()
  def apply_events(state, events) do
    for %ServerSentEventStage.Event{event: event, data: data} <- events, reduce: state do
      state ->
        %JsonApi{data: raw_data} = JsonApi.parse(data)
        data = Enum.map(raw_data, &JsonApi.Object.parse/1)

        case event do
          "reset" ->
            JsonApi.Object.to_full_map(data)

          "add" ->
            merge(state, JsonApi.Object.to_full_map(data))

          "update" ->
            merge(state, JsonApi.Object.to_full_map(data))

          "remove" ->
            [%JsonApi.Reference{type: type, id: id}] = raw_data
            type_key = JsonApi.Object.plural_type(String.to_existing_atom(type))
            {_, state} = pop_in(state[type_key][id])
            state
        end
    end
  end

  @spec merge(t(), t()) :: t()
  defp merge(old_data, new_data) do
    Map.merge(old_data, new_data, fn _type, old_items, new_items ->
      Map.merge(old_items, new_items)
    end)
  end
end
