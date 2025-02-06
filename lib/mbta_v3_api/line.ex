defmodule MBTAV3API.Line do
  use MBTAV3API.JsonApi.Object

  @type t :: %__MODULE__{
          id: String.t(),
          color: String.t(),
          long_name: String.t(),
          short_name: String.t(),
          sort_order: String.t(),
          text_color: String.t()
        }

  @derive Jason.Encoder
  defstruct [
    :id,
    :color,
    :long_name,
    :short_name,
    :sort_order,
    :text_color
  ]

  @impl JsonApi.Object
  def fields do
    [
      :color,
      :long_name,
      :short_name,
      :sort_order,
      :text_color
    ]
  end

  @impl JsonApi.Object
  def includes, do: %{}

  @spec parse!(JsonApi.Item.t()) :: t()
  def parse!(%JsonApi.Item{} = item) do
    %__MODULE__{
      id: item.id,
      color: item.attributes["color"],
      long_name: item.attributes["long_name"],
      short_name: item.attributes["short_name"],
      sort_order: item.attributes["sort_order"],
      text_color: item.attributes["text_color"]
    }
  end
end
