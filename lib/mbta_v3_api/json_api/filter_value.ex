defprotocol MBTAV3API.JsonApi.FilterValue do
  @doc "Converts this filter value into a string"
  @spec filter_value_string(t()) :: String.t()
  def filter_value_string(data)
end

defimpl MBTAV3API.JsonApi.FilterValue, for: BitString do
  def filter_value_string(data), do: data
end

defimpl MBTAV3API.JsonApi.FilterValue, for: [Atom, Float, Integer] do
  def filter_value_string(data), do: String.Chars.to_string(data)
end

defimpl MBTAV3API.JsonApi.FilterValue, for: List do
  def filter_value_string(data) do
    Enum.map_join(data, ",", &MBTAV3API.JsonApi.FilterValue.filter_value_string/1)
  end
end
