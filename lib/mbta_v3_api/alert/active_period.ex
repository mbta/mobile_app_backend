defmodule MBTAV3API.Alert.ActivePeriod do
  @type t :: %__MODULE__{start: DateTime.t(), end: DateTime.t() | nil}

  @derive Jason.Encoder
  defstruct [:start, :end]

  @spec parse!(map()) :: t()
  def parse!(data) when is_map(data) do
    %__MODULE__{
      start: Util.parse_datetime!(data["start"]),
      end: Util.parse_optional_datetime!(data["end"])
    }
  end
end
