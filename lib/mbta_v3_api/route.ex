defmodule MBTAV3API.Route do
  alias MBTAV3API.JsonApi

  @behaviour JsonApi.Object

  @type t :: %__MODULE__{
          id: String.t(),
          type: route_type(),
          color: String.t(),
          direction_names: [String.t()],
          direction_destinations: [String.t()],
          long_name: String.t(),
          short_name: String.t(),
          sort_order: String.t(),
          text_color: String.t()
        }
  @type route_type ::
          :tram | :subway | :rail | :bus | :ferry

  @derive Jason.Encoder
  defstruct [
    :id,
    :type,
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
      :type,
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
      type: parse_route_type(item.attributes["type"]),
      color: item.attributes["color"],
      direction_names: item.attributes["direction_names"],
      direction_destinations: item.attributes["direction_destinations"],
      long_name: item.attributes["long_name"],
      short_name: item.attributes["short_name"],
      sort_order: item.attributes["sort_order"],
      text_color: item.attributes["text_color"]
    }
  end

  @spec parse_route_type(integer() | nil) :: route_type() | nil
  defp parse_route_type(0), do: :tram
  defp parse_route_type(1), do: :subway
  defp parse_route_type(2), do: :rail
  defp parse_route_type(3), do: :bus
  defp parse_route_type(4), do: :ferry
  defp parse_route_type(nil), do: nil
end
