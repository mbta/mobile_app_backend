defmodule MBTAV3API.Stream.Event do
  alias MBTAV3API.JsonApi

  defmodule Reset do
    @type t :: %__MODULE__{data: [JsonApi.Object.t()]}
    defstruct [:data]

    defimpl Jason.Encoder do
      def encode(value, opts) do
        Jason.Encode.map(%{event: "reset", data: value.data}, opts)
      end
    end
  end

  defmodule Add do
    @type t :: %__MODULE__{data: JsonApi.Object.t()}
    defstruct [:data]

    defimpl Jason.Encoder do
      def encode(value, opts) do
        Jason.Encode.map(%{event: "add", data: value.data}, opts)
      end
    end
  end

  defmodule Update do
    @type t :: %__MODULE__{data: JsonApi.Object.t()}
    defstruct [:data]

    defimpl Jason.Encoder do
      def encode(value, opts) do
        Jason.Encode.map(%{event: "update", data: value.data}, opts)
      end
    end
  end

  defmodule Remove do
    @type t :: %__MODULE__{data: JsonApi.Reference.t()}
    defstruct [:data]

    defimpl Jason.Encoder do
      def encode(value, opts) do
        Jason.Encode.map(%{event: "remove", data: value.data}, opts)
      end
    end
  end

  @type t :: Reset.t() | Add.t() | Update.t() | Remove.t()

  @spec parse(ServerSentEventStage.Event.t()) :: t()
  def parse(%ServerSentEventStage.Event{event: event, data: data}) do
    %JsonApi{data: data} = JsonApi.parse(data)
    data = Enum.map(data, &JsonApi.Object.parse/1)

    case {event, data} do
      {"reset", data} -> %Reset{data: data}
      {"add", [data]} -> %Add{data: data}
      {"update", [data]} -> %Update{data: data}
      {"remove", [data]} -> %Remove{data: data}
    end
  end
end
