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

  @spec collapse([t()]) :: [t()]
  def collapse(periods) when is_list(periods) do
    periods |> Enum.reduce([], &collapse_reduce/2) |> Enum.reverse()
  end

  defp collapse_reduce(this_period, list) do
    %__MODULE__{start: this_start, end: this_end} = this_period

    case List.first(list) do
      %__MODULE__{start: last_start, end: last_end} ->
        if not is_nil(last_end) and DateTime.diff(this_start, last_end, :minute) |> abs() <= 1 do
          [%__MODULE__{start: last_start, end: this_end} | tl(list)]
        else
          [this_period | list]
        end

      nil ->
        [this_period]
    end
  end

  def to_end_of_service?(%__MODULE__{end: %DateTime{hour: 3, minute: 0}}), do: true
  def to_end_of_service?(%__MODULE__{end: %DateTime{hour: 2, minute: 59}}), do: true
  def to_end_of_service?(%__MODULE__{}), do: false
end
