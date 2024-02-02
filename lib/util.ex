defmodule Util do
  @doc """
  Parses an optional value as an `America/New_York` datetime.

  ## Examples

      iex> Util.parse_optional_datetime(nil)
      nil

      iex> Util.parse_optional_datetime("2024-02-02T10:45:52-05:00")
      #DateTime<2024-02-02 10:45:52-05:00 EST America/New_York>
  """
  @spec parse_optional_datetime(String.t() | nil) :: DateTime.t() | nil
  def parse_optional_datetime(data)
  def parse_optional_datetime(nil), do: nil

  def parse_optional_datetime(data) do
    {:ok, datetime, _} = DateTime.from_iso8601(data)
    DateTime.shift_zone!(datetime, "America/New_York")
  end
end
