defmodule MBTAV3API.Shape do
  use MBTAV3API.JsonApi.Object

  @type t :: %__MODULE__{
          id: String.t(),
          polyline: String.t()
        }

  @derive Jason.Encoder
  defstruct [:id, :polyline]

  def fields, do: [:polyline]

  def includes, do: %{}

  @spec parse!(JsonApi.Item.t()) :: t()
  def parse!(%JsonApi.Item{} = item) do
    %__MODULE__{
      id: item.id,
      polyline: item.attributes["polyline"]
    }
  end
end
