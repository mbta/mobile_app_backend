defprotocol MBTAV3API.JsonApi.FilterValue do
  @doc """
  Converts this filter value into a string.
  If a serializer is given, it will be called on each value of a list, or on an individual value.
  """
  @spec filter_value_string(t(), (t() -> t()) | nil) :: String.t()
  def filter_value_string(data, serializer \\ nil)
end

defimpl MBTAV3API.JsonApi.FilterValue, for: BitString do
  def filter_value_string(data, nil), do: data

  def filter_value_string(data, serializer) do
    @protocol.filter_value_string(serializer.(data), nil)
  end
end

defimpl MBTAV3API.JsonApi.FilterValue, for: [Atom, Float, Integer] do
  def filter_value_string(data, nil), do: String.Chars.to_string(data)

  def filter_value_string(data, serializer) do
    @protocol.filter_value_string(serializer.(data), nil)
  end
end

defimpl MBTAV3API.JsonApi.FilterValue, for: List do
  def filter_value_string(data, serializer) do
    Enum.map_join(data, ",", &@protocol.filter_value_string(&1, serializer))
  end
end
