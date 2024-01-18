defmodule MBTAV3API.Route do
  alias MBTAV3API.JsonApi

  @behaviour JsonApi.Object

  @type t :: %__MODULE__{
          id: String.t(),
          color: String.t(),
          direction_names: [String.t()],
          direction_destinations: [String.t()],
          long_name: String.t(),
          short_name: String.t(),
          sort_order: String.t(),
          text_color: String.t()
        }

  @derive Jason.Encoder
  defstruct [
    :id,
    :color,
    :direction_names,
    :direction_destinations,
    :long_name,
    :short_name,
    :sort_order,
    :text_color
  ]

  @impl JsonApi.Object
  def fields,
    do: [
      :color,
      :direction_names,
      :direction_destinations,
      :long_name,
      :short_name,
      :sort_order,
      :text_color
    ]

  @impl JsonApi.Object
  def includes, do: %{}

  @spec parse(JsonApi.Item.t()) :: t()
  def parse(%JsonApi.Item{} = item) do
    %__MODULE__{
      id: item.id,
      color: item.attributes["color"],
      direction_names: item.attributes["direction_names"],
      direction_destinations: item.attributes["direction_destinations"],
      long_name: item.attributes["long_name"],
      short_name: item.attributes["short_name"],
      sort_order: item.attributes["sort_order"],
      text_color: item.attributes["text_color"]
    }
  end
end
