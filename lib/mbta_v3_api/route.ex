defmodule MBTAV3API.Route do
  use MBTAV3API.JsonApi.Object
  require Util

  @type t :: %__MODULE__{
          id: String.t(),
          type: type(),
          color: String.t(),
          direction_names: [String.t()],
          direction_destinations: [String.t()],
          listed_route: boolean(),
          long_name: String.t(),
          short_name: String.t(),
          sort_order: integer(),
          text_color: String.t(),
          line_id: String.t() | nil,
          route_pattern_ids: [String.t()]
        }

  Util.declare_enum(
    :type,
    Util.enum_values(:index, [:light_rail, :heavy_rail, :commuter_rail, :bus, :ferry]),
    Util.FailOnUnknown
  )

  @derive Jason.Encoder
  defstruct [
    :id,
    :type,
    :color,
    :direction_names,
    :direction_destinations,
    :listed_route,
    :long_name,
    :short_name,
    :sort_order,
    :text_color,
    :line_id,
    :route_pattern_ids
  ]

  @impl JsonApi.Object
  def fields,
    do: [
      :type,
      :color,
      :direction_names,
      :direction_destinations,
      :listed_route,
      :long_name,
      :short_name,
      :sort_order,
      :text_color
    ]

  @impl JsonApi.Object
  def includes, do: %{line: MBTAV3API.Line, route_patterns: MBTAV3API.RoutePattern}

  @impl JsonApi.Object
  def serialize_filter_value(:type, type), do: serialize_type!(type)
  def serialize_filter_value(_field, value), do: value

  @spec parse!(JsonApi.Item.t(), [JsonApi.Object.t()]) :: t()
  def parse!(%JsonApi.Item{} = item, included_items \\ []) do
    line_id = JsonApi.Object.get_one_id(item.relationships["line"])

    line = Enum.find(included_items, fn item -> item.type == "line" && item.id == line_id end)

    # Override colors with line color when available. This way, OL Shuttle colors
    # match the OL rather than matching other buses.
    {color, text_color} =
      case line do
        %{attributes: %{"color" => color, "text_color" => text_color}} -> {color, text_color}
        nil -> {item.attributes["color"], item.attributes["text_color"]}
      end

    %__MODULE__{
      id: item.id,
      type: parse_type!(item.attributes["type"]),
      color: color,
      direction_names: item.attributes["direction_names"],
      direction_destinations: item.attributes["direction_destinations"],
      listed_route: item.attributes["listed_route"],
      long_name: item.attributes["long_name"],
      short_name: item.attributes["short_name"],
      sort_order: item.attributes["sort_order"],
      text_color: text_color,
      line_id: line_id,
      route_pattern_ids: JsonApi.Object.get_many_ids(item.relationships["route_patterns"])
    }
  end
end
