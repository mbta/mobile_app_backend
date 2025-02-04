defmodule MBTAV3API.Stream.State do
  @moduledoc """
  Tracks the state of the world as remembered by a `MBTAV3API.Stream.Consumer`.

  Objects are stored in a `t:MBTAV3API.JsonApi.Object.full_map/0`.
  """

  alias MBTAV3API.JsonApi

  @type t :: JsonApi.Object.full_map()

  @type event_type :: :reset | :add | :update | :remove

  @spec new :: t()
  def new, do: JsonApi.Object.to_full_map([])

  @spec parse_event(ServerSentEventStage.Event.t()) ::
          {event_type(), [JsonApi.Object.t() | JsonApi.Reference.t()]}
  @doc """
  Parse a ServetSentEvent into the event type and list of parsed objects
  """
  def parse_event(event) do
    %ServerSentEventStage.Event{event: event, data: data} = event

    %JsonApi{data: raw_data} = JsonApi.parse(data)
    parsed_data = JsonApi.Object.parse_all_discarding_failures(raw_data)

    {event_type(event), parsed_data}
  end

  @spec event_type(String.t()) :: event_type()
  defp event_type(event_string) do
    case event_string do
      "reset" -> :reset
      "add" -> :add
      "update" -> :update
      "remove" -> :remove
    end
  end

  @spec apply_events(t(), [ServerSentEventStage.Event.t()]) :: t()
  def apply_events(state, events) do
    for event <- events, reduce: state do
      state ->
        {event_type, data} = parse_event(event)

        case event_type do
          :reset ->
            JsonApi.Object.to_full_map(data)

          :add ->
            JsonApi.Object.merge_full_map(state, JsonApi.Object.to_full_map(data))

          :update ->
            JsonApi.Object.merge_full_map(state, JsonApi.Object.to_full_map(data))

          :remove ->
            [%JsonApi.Reference{type: type, id: id}] = data
            type_key = JsonApi.Object.plural_type(String.to_existing_atom(type))
            {_, state} = pop_in(state[type_key][id])
            state
        end
    end
  end
end
